function [acc, data] = emot_face_stim_26(day, run, opts)
% Emotion matching task (cleaned from EyeEmotMatchV5)
% Alternating blocks:
%   - Match Faces  (blocks 1, 3, 5, 7)
%   - Match Shapes (blocks 2, 4, 6, 8)
% Each trial shows 1 top image + 2 bottom choice images for 4 s.
% Participant selects left/right match with button box keys.
%
% Required inputs:
%   day : day number (integer, currently 1)
%   run : run number (integer, 1 or 2)
%
% Optional input (opts struct fields):
%   .csv_path      : path to trial_list.csv
%                    (default: trial_list.csv in same folder as this script)
%   .data_path     : directory where output .csv files are saved
%                    (default: <script folder>/data/)
%   .skipSyncTests : 1 to skip PTB sync test (default 1)
%   .mode          : 'laptop' (default) or 'mri'
%   .waitForTrigger: wait for trigger before task start (default: false for laptop, true for mri)
%   .triggerKey    : trigger key name for KbName (default '5%')
%   .responseKeys  : cell array with left/right key names (default {'1!','2@'})
%   .keyboardName  : device name to match in GetKeyboardIndices (default: Current Designs device in mri mode)
%   .whichScreen   : PTB screen index (default: max(Screen('Screens')))
%
% Outputs:
%   acc  : fraction correct over all task trials
%   data : struct with saved trial timing and response info

% Set to 1 when testing outside the MRI (skips trigger wait, uses all keyboards).
% Set to 0 for real scanning sessions (waits for the '5' pulse from the MRI).
outside_of_mri_test = 1;

if nargin < 1
    day = 1;
end
if nargin < 2
    run = 1;
end
if nargin < 3
    opts = struct();
end

% Apply the test flag — forces laptop mode unless opts explicitly says otherwise.
if outside_of_mri_test
    if ~isfield(opts, 'mode');          opts.mode           = 'laptop'; end
    if ~isfield(opts, 'waitForTrigger'); opts.waitForTrigger = false;   end
    if ~isfield(opts, 'keyboardName');   opts.keyboardName   = '';      end
end

script_dir = fileparts(mfilename('fullpath'));

if ~isfield(opts, 'csv_path')
    opts.csv_path = fullfile(script_dir, 'trial_list_local.csv');
end
if ~isfield(opts, 'data_path')
    opts.data_path = fullfile(script_dir, 'data');
end
if ~isfield(opts, 'skipSyncTests')
    opts.skipSyncTests = 2;   % 2 = skip sync test entirely (no flash error screen)
end
if ~isfield(opts, 'mode')
    opts.mode = 'laptop';
end
if ~isfield(opts, 'triggerKey')
    opts.triggerKey = '5%';
end
if ~isfield(opts, 'responseKeys')
    opts.responseKeys = {'1!', '2@'};
end
if ~isfield(opts, 'whichScreen')
    opts.whichScreen = [];
end

mode = lower(string(opts.mode));
if ~ismember(mode, ["laptop", "mri"])
    error('opts.mode must be ''laptop'' or ''mri''.');
end

if ~isfield(opts, 'waitForTrigger')
    opts.waitForTrigger = mode == "mri";
end
if ~isfield(opts, 'keyboardName')
    if mode == "mri"
        opts.keyboardName = 'Current Designs, Inc. 932';
    else
        opts.keyboardName = '';
    end
end

Screen('Preference', 'SkipSyncTests', opts.skipSyncTests);
KbName('UnifyKeyNames');

acc = NaN;
data = struct();
window = [];
KB = [];

try
    %% Load trial table for this day and run
    if ~exist(opts.data_path, 'dir')
        mkdir(opts.data_path);
    end

    c = clock;
    run_stamp = sprintf('%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f', c(1), c(2), c(3), c(4), c(5), c(6));
    output_base = fullfile(opts.data_path, sprintf('EmotMatch_day%d_run%d_%s', day, run, run_stamp));

    T = readtable(opts.csv_path);
    T = T(T.day == day & T.run == run, :);

    if isempty(T)
        error('No trials found for day=%d run=%d in %s', day, run, opts.csv_path);
    end

    data.day      = day;
    data.run      = run;
    data.csv_path = opts.csv_path;

    %% Input device and task keys
    trigger = KbName(opts.triggerKey);
    if numel(opts.responseKeys) ~= 2
        error('opts.responseKeys must have exactly two key names: {leftKey rightKey}.');
    end
    buttonPresses = [KbName(opts.responseKeys{1}) KbName(opts.responseKeys{2})];

    keylist = zeros(1, 256);
    keylist(buttonPresses) = 1;

    triggerlist = zeros(1, 256);
    triggerlist(trigger) = 1;

    [kbd_idx, kbd_names] = GetKeyboardIndices;
    if ~isempty(opts.keyboardName)
        KBmatch = find(strcmp(kbd_names, opts.keyboardName), 1, 'first');
    else
        KBmatch = [];
    end

    if ~isempty(KBmatch)
        KB = kbd_idx(KBmatch);
    else
        KB = -1;
    end

    %% Terminal-only preflight printout
    fprintf('\n=== EmotMatch Preflight ===\n');
    fprintf('Mode: %s\n', char(mode));
    fprintf('Wait for trigger: %d\n', opts.waitForTrigger);
    fprintf('Trigger key: %s (code %d)\n', opts.triggerKey, trigger);
    fprintf('Response keys: left=%s (code %d), right=%s (code %d)\n', ...
        opts.responseKeys{1}, buttonPresses(1), opts.responseKeys{2}, buttonPresses(2));
    if ~isempty(KBmatch)
        fprintf('Keyboard device: %s (index %d)\n', kbd_names{KBmatch}, KB);
    else
        fprintf('Keyboard device: ALL keyboards (KB = -1)\n');
        if ~isempty(opts.keyboardName)
            fprintf('Requested device not found: %s\n', opts.keyboardName);
        end
    end
    fprintf('==========================\n\n');

    %% Screen setup
    screens = Screen('Screens');
    if isempty(opts.whichScreen)
        whichScreen = max(screens);
    else
        whichScreen = opts.whichScreen;
    end

    % White background so RADIATE face images (white bg) blend seamlessly,
    % and transparent shape PNGs render with white rather than black.
    white = WhiteIndex(whichScreen);   % 255 on 8-bit display
    black = BlackIndex(whichScreen);   % 0

    [window, windowRect] = Screen(whichScreen, 'OpenWindow', white);

    % Alpha blending lets transparent shape PNG areas show the white bg.
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

    % Large text — legible at MRI viewing distance.
    Screen('TextSize', window, 160);

    % Flip the loading screen BEFORE GetFlipInterval so the window is never
    % blank during the measurement (that blank was the mysterious flash).
    DrawFormattedText(window, 'Loading experiment,\nplease be patient...', 'center', 'center', black);
    Screen('Flip', window);

    topPriorityLevel = MaxPriority(window);
    Priority(topPriorityLevel);
    ifi = Screen('GetFlipInterval', window);

    dual = get(0, 'MonitorPositions');
    resolution = [0, 0, dual(1, 3), dual(1, 4)];
    data.screenX = resolution(3);
    data.screenY = resolution(4);

    %% Preload image textures and compute per-image destination rects
    nRows = height(T);
    top_textures   = cell(nRows, 1);
    left_textures  = cell(nRows, 1);
    right_textures = cell(nRows, 1);
    top_dstRects   = zeros(4, nRows);
    left_dstRects  = zeros(4, nRows);
    right_dstRects = zeros(4, nRows);

    % Each image is scaled to fit within max_w x max_h preserving aspect ratio.
    % Transparent PNG backgrounds (shapes) are handled via load_rgba below.
    max_w  = 340;   % max display width (px)
    max_h  = 380;   % max display height (px)
    Nshift = 240;   % vertical distance from screen centre to each image centre
    Hshift = 270;   % horizontal distance from screen centre to bottom image centres

    cx_top   = windowRect(3) / 2;
    cy_top   = windowRect(4) / 2 - Nshift;
    cx_left  = windowRect(3) / 2 - Hshift;
    cy_bot   = windowRect(4) / 2 + Nshift;
    cx_right = windowRect(3) / 2 + Hshift;

    for i = 1:nRows
        top_path   = resolve_img_path(T.base_path{i}, T.top_correct{i}, script_dir);
        left_path  = resolve_img_path(T.base_path{i}, T.bottom_left{i}, script_dir);
        right_path = resolve_img_path(T.base_path{i}, T.bottom_right{i}, script_dir);

        top_img   = load_rgba(top_path);
        left_img  = load_rgba(left_path);
        right_img = load_rgba(right_path);

        top_textures{i}   = Screen('MakeTexture', window, top_img);
        left_textures{i}  = Screen('MakeTexture', window, left_img);
        right_textures{i} = Screen('MakeTexture', window, right_img);

        top_dstRects(:, i)   = fit_rect(size(top_img,   2), size(top_img,   1), max_w, max_h, cx_top,   cy_top);
        left_dstRects(:, i)  = fit_rect(size(left_img,  2), size(left_img,  1), max_w, max_h, cx_left,  cy_bot);
        right_dstRects(:, i) = fit_rect(size(right_img, 2), size(right_img, 1), max_w, max_h, cx_right, cy_bot);
    end

    %% Timing plan
    numTrials = 9;
    numBlocks = 4;   % 2 face + 2 shape per run
    totalTrials = numTrials * numBlocks;

    display_duration = 4.0;

    % Jittered ITIs (s) for face blocks; fixed ITI for shape blocks.
    % 9 values per block, randomised within each face block at runtime.
    % Face blocks are at positions 1 and 3 within every run.
    isiF = [2 2 6 6 4 4 2 4 6];
    isiS = [2 2 2 2 2 2 2 2 2];

    isiL = [];
    for bl = 1:numBlocks
        if ismember(bl, [1 3])
            isiL = [isiL, isiF(randperm(numel(isiF)))]; %#ok<AGROW>
        else
            isiL = [isiL, isiS]; %#ok<AGROW>
        end
    end

    isiTimeFrames  = ceil(isiL / ifi);
    cueFrames      = ceil(3 / ifi);
    trialdurFrames = ceil(display_duration / ifi);

    %% Instructions
    show_instructions(window, char(mode), opts.responseKeys, black, white, KB);

    %% Task start
    if opts.waitForTrigger
        DrawFormattedText(window, 'Get Ready!\n\nWaiting for\nscanner trigger...', 'center', 'center', black);
        Screen('Flip', window);

        KbQueueCreate(KB, triggerlist);
        KbQueueStart(KB);

        pressed = 0;
        while ~pressed
            pause(0.005);
            [pressed, firstpress] = KbQueueCheck(KB);
        end

        ts = firstpress(trigger);
        KbQueueRelease(KB);
    else
        DrawFormattedText(window, 'Get Ready!\n\nPress any key\nto start.', 'center', 'center', black);
        Screen('Flip', window);
        KbStrokeWait(KB);
        ts = GetSecs;
    end

    %% Response queue for participant button presses
    KbQueueCreate(KB, keylist);
    KbQueueStart(KB);

    waitframes  = 1;
    framecounter = 1;

    allt      = zeros(30000, 1);
    frametype = zeros(30000, 1);
    allt(1)   = ts;

    responsecorr = zeros(1, totalTrials);
    respsec      = zeros(1, totalTrials);
    blockonset   = zeros(1, numBlocks);
    stimonset    = zeros(1, totalTrials);

    resptimes = zeros(1, 1000);
    keyval    = zeros(1, 1000);
    key_idx   = 1;
    trialcounter = 0;
    consecutive_no_response = 0;   % alertness monitor (MRI-only)

    %% Main task loop
    for bl = 1:numBlocks
        is_face_block = ismember(bl, [1 3]);
        if is_face_block
            msg = 'Match Faces';
        else
            msg = 'Match Shapes';
        end

        for tr = 1:numTrials
            trialcounter = trialcounter + 1;

            if strcmp(T.bottom_correct_match{trialcounter}, 'left')
                keyvalcorr = buttonPresses(1);
            else
                keyvalcorr = buttonPresses(2);
            end

            % 3-second block cue shown once at block start
            if tr == 1
                for frame = 1:(cueFrames - 1)
                    Screen('FillRect', window, white);
                    DrawFormattedText(window, msg, 'center', 'center', black);
                    [ts, ~] = Screen(window, 'Flip', ts + ifi * waitframes - ifi * 0.5);

                    framecounter = framecounter + 1;
                    allt(framecounter)      = ts;
                    frametype(framecounter) = -1;

                    if frame == 1
                        blockonset(bl) = ts;
                    end
                end
            end

            % Stimulus display period
            for frame = 1:(trialdurFrames - 1)
                Screen('FillRect', window, white);
                Screen('DrawTexture', window, top_textures{trialcounter},   [], top_dstRects(:,   trialcounter));
                Screen('DrawTexture', window, left_textures{trialcounter},  [], left_dstRects(:,  trialcounter));
                Screen('DrawTexture', window, right_textures{trialcounter}, [], right_dstRects(:, trialcounter));
                DrawFormattedText(window, '+', 'center', 'center', black);
                [ts, ~] = Screen(window, 'Flip', ts + ifi * waitframes - ifi * 0.5);

                framecounter = framecounter + 1;
                allt(framecounter)      = ts;
                frametype(framecounter) = 1;

                if frame == 1
                    stimonset(trialcounter) = ts;
                end

                [pressed, firstpress] = KbQueueCheck(KB);
                if pressed
                    keys = find(firstpress);
                    for j = 1:numel(keys)
                        keyval(key_idx) = keys(j);

                        if keyvalcorr == keys(j)
                            responsecorr(trialcounter) = 1;
                        else
                            responsecorr(trialcounter) = 0;
                        end

                        if respsec(trialcounter) == 0
                            resptimes(key_idx)       = firstpress(keys(j));
                            respsec(trialcounter)    = firstpress(keys(j)) - stimonset(trialcounter);
                        end
                        key_idx = key_idx + 1;
                    end
                end
            end

            % ITI fixation period
            for frame = 1:(isiTimeFrames(trialcounter) - 1)
                Screen('FillRect', window, white);
                DrawFormattedText(window, '+', 'center', 'center', black);
                [ts, ~] = Screen('Flip', window, ts + (waitframes - 0.5) * ifi);

                framecounter = framecounter + 1;
                allt(framecounter)      = ts;
                frametype(framecounter) = 2;

                [pressed, firstpress] = KbQueueCheck(KB);
                if pressed
                    keys = find(firstpress);
                    for j = 1:numel(keys)
                        keyval(key_idx)    = keys(j);
                        resptimes(key_idx) = firstpress(keys(j));
                        key_idx = key_idx + 1;
                    end
                end
            end

            % MRI alertness check: warn after 2 consecutive trials with no response.
            if ~outside_of_mri_test
                if respsec(trialcounter) == 0
                    consecutive_no_response = consecutive_no_response + 1;
                else
                    consecutive_no_response = 0;
                end
                if consecutive_no_response >= 2
                    Screen('FillRect', window, white);
                    DrawFormattedText(window, ...
                        'Please stay focused!\n\nRemember to press a button\nfor each image pair.\n\nPress any button\nto continue.', ...
                        'center', 'center', black);
                    Screen('Flip', window);
                    KbStrokeWait(KB);
                    KbQueueFlush(KB);   % discard the dismissal key press
                    consecutive_no_response = 0;
                end
            end
        end
    end

    acc = sum(responsecorr) / totalTrials;

    %% Save outputs
    data.allt        = allt;
    data.frametype   = frametype;
    data.stimonset   = stimonset;
    data.respsec     = respsec;
    data.blockonset  = blockonset;
    data.isiL        = isiL;
    data.trialTable  = T;
    data.mode        = char(mode);
    data.waitForTrigger = opts.waitForTrigger;
    data.keyboardName = opts.keyboardName;
    data.triggerKey  = opts.triggerKey;
    data.responseKeys = opts.responseKeys;
    data.output_file = write_run_csv(output_base, T, day, run, acc, stimonset, respsec, responsecorr, isiL, blockonset, allt, frametype, framecounter, keyval, resptimes, key_idx - 1, data.screenX, data.screenY, opts.csv_path);

    %% Cleanup
    ShowCursor;
    Priority(0);
    KbQueueRelease(KB);
    Screen('CloseAll');

catch ME
    try
        ShowCursor;
        Priority(0);
        Screen('CloseAll');
    catch
    end

    try
        if ~isempty(KB)
            KbQueueRelease(KB);
        end
    catch
    end

    try
        err_base = fullfile(opts.data_path, sprintf('ERROREDOUT_EmotMatch_day%d_run%d_%s', day, run, datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
        write_error_csv(err_base, day, run, acc, opts.csv_path, ME);
    catch
    end

    rethrow(ME);
end
end

function output_file = write_run_csv(output_base, T, day, run, acc, stimonset, respsec, responsecorr, isiL, blockonset, allt, frametype, framecounter, keyval, resptimes, nKeypresses, screenX, screenY, source_csv_path)
trial_index = (1:height(T))';
block_number = ceil(trial_index / 9);
trial_in_block = mod(trial_index - 1, 9) + 1;
is_face_block = ismember(block_number, [1 3 5 7]);

trial_table = T;
trial_table.record_type = repmat({'trial'}, height(T), 1);
trial_table.day = repmat(day, height(T), 1);
trial_table.run = repmat(run, height(T), 1);
trial_table.trial_index = trial_index;
trial_table.block_number = block_number;
trial_table.trial_in_block = trial_in_block;
trial_table.is_face_block = is_face_block;
trial_table.stimonset = stimonset(:);
trial_table.respsec = respsec(:);
trial_table.responsecorr = responsecorr(:);
trial_table.isi_seconds = isiL(:);
trial_table.block_onset = blockonset(block_number(:))';
trial_table.frame_index = nan(height(T), 1);
trial_table.timestamp = nan(height(T), 1);
trial_table.frame_type = nan(height(T), 1);
trial_table.keypress_index = nan(height(T), 1);
trial_table.key_code = nan(height(T), 1);
trial_table.accuracy = nan(height(T), 1);
trial_table.trigger_timestamp = nan(height(T), 1);
trial_table.screenX = repmat(screenX, height(T), 1);
trial_table.screenY = repmat(screenY, height(T), 1);
trial_table.source_csv_path = repmat({source_csv_path}, height(T), 1);

block_table = table(repmat({'block'}, numel(blockonset), 1), repmat(day, numel(blockonset), 1), repmat(run, numel(blockonset), 1), ...
    nan(numel(blockonset), 1), (1:numel(blockonset))', nan(numel(blockonset), 1), nan(numel(blockonset), 1), ...
    blockonset(:), nan(numel(blockonset), 1), nan(numel(blockonset), 1), nan(numel(blockonset), 1), nan(numel(blockonset), 1), ...
    nan(numel(blockonset), 1), nan(numel(blockonset), 1), nan(numel(blockonset), 1), nan(numel(blockonset), 1), nan(numel(blockonset), 1), nan(numel(blockonset), 1), nan(numel(blockonset), 1), repmat(screenX, numel(blockonset), 1), repmat(screenY, numel(blockonset), 1), repmat({source_csv_path}, numel(blockonset), 1), ...
    'VariableNames', {'record_type', 'day', 'run', 'trial_index', 'block_number', 'trial_in_block', 'is_face_block', 'block_onset', 'stimonset', 'respsec', 'responsecorr', 'isi_seconds', 'frame_index', 'timestamp', 'frame_type', 'keypress_index', 'key_code', 'accuracy', 'trigger_timestamp', 'screenX', 'screenY', 'source_csv_path'});

frame_table = table(repmat({'frame'}, framecounter, 1), repmat(day, framecounter, 1), repmat(run, framecounter, 1), ...
    nan(framecounter, 1), nan(framecounter, 1), nan(framecounter, 1), nan(framecounter, 1), ...
    nan(framecounter, 1), nan(framecounter, 1), nan(framecounter, 1), nan(framecounter, 1), ...
    nan(framecounter, 1), (1:framecounter)', allt(1:framecounter), frametype(1:framecounter), nan(framecounter, 1), nan(framecounter, 1), ...
    nan(framecounter, 1), nan(framecounter, 1), repmat(screenX, framecounter, 1), repmat(screenY, framecounter, 1), repmat({source_csv_path}, framecounter, 1), ...
    'VariableNames', {'record_type', 'day', 'run', 'trial_index', 'block_number', 'trial_in_block', 'is_face_block', 'block_onset', 'stimonset', 'respsec', 'responsecorr', 'isi_seconds', 'frame_index', 'timestamp', 'frame_type', 'keypress_index', 'key_code', 'accuracy', 'trigger_timestamp', 'screenX', 'screenY', 'source_csv_path'});

keypress_table = table(repmat({'keypress'}, nKeypresses, 1), repmat(day, nKeypresses, 1), repmat(run, nKeypresses, 1), ...
    nan(nKeypresses, 1), nan(nKeypresses, 1), nan(nKeypresses, 1), nan(nKeypresses, 1), ...
    nan(nKeypresses, 1), nan(nKeypresses, 1), nan(nKeypresses, 1), nan(nKeypresses, 1), ...
    nan(nKeypresses, 1), nan(nKeypresses, 1), resptimes(1:nKeypresses)', nan(nKeypresses, 1), (1:nKeypresses)', keyval(1:nKeypresses)', ...
    nan(nKeypresses, 1), nan(nKeypresses, 1), repmat(screenX, nKeypresses, 1), repmat(screenY, nKeypresses, 1), repmat({source_csv_path}, nKeypresses, 1), ...
    'VariableNames', {'record_type', 'day', 'run', 'trial_index', 'block_number', 'trial_in_block', 'is_face_block', 'block_onset', 'stimonset', 'respsec', 'responsecorr', 'isi_seconds', 'frame_index', 'timestamp', 'frame_type', 'keypress_index', 'key_code', 'accuracy', 'trigger_timestamp', 'screenX', 'screenY', 'source_csv_path'});

summary_table = table({'summary'}, day, run, nan, nan, nan, nan, nan, nan, nan, nan, nan, nan, nan, nan, nan, nan, acc, allt(1), screenX, screenY, {source_csv_path}, ...
    'VariableNames', {'record_type', 'day', 'run', 'trial_index', 'block_number', 'trial_in_block', 'is_face_block', 'block_onset', 'stimonset', 'respsec', 'responsecorr', 'isi_seconds', 'frame_index', 'timestamp', 'frame_type', 'keypress_index', 'key_code', 'accuracy', 'trigger_timestamp', 'screenX', 'screenY', 'source_csv_path'});

block_table = add_missing_variables(block_table, trial_table);
frame_table = add_missing_variables(frame_table, trial_table);
keypress_table = add_missing_variables(keypress_table, trial_table);
summary_table = add_missing_variables(summary_table, trial_table);

output_table = [trial_table; block_table; frame_table; keypress_table; summary_table];
output_file = [output_base '.csv'];
writetable(output_table, output_file);
end

function tbl = add_missing_variables(tbl, exemplar_tbl)
exemplar_names = exemplar_tbl.Properties.VariableNames;
for idx = 1:numel(exemplar_names)
    name = exemplar_names{idx};
    if ~ismember(name, tbl.Properties.VariableNames)
        tbl.(name) = make_empty_column_like(exemplar_tbl.(name), height(tbl));
    end
end
tbl = tbl(:, exemplar_names);
end


function p = resolve_img_path(base_path, relative_path, script_dir)
% Build a full image path from base_path + relative_path.
% Normalises backslashes to the OS file separator so CSV files generated
% on Windows work correctly on Linux/Mac as well.
% If base_path is absolute (drive letter on Windows, or / on Unix) it is
% used directly; otherwise it is resolved relative to script_dir so that
% trial_list_local.csv works on any machine.
base_path     = strrep(base_path,     '\', filesep);
relative_path = strrep(relative_path, '\', filesep);
if ~isempty(regexp(base_path, '^([A-Za-z]:[/\\]|/)', 'once'))
    p = fullfile(base_path, relative_path);
else
    p = fullfile(script_dir, base_path, relative_path);
end
end

function empty_col = make_empty_column_like(sample_col, nRows)
if isnumeric(sample_col)
    empty_col = nan(nRows, 1);
elseif islogical(sample_col)
    empty_col = false(nRows, 1);
elseif iscell(sample_col)
    empty_col = repmat({''}, nRows, 1);
elseif isstring(sample_col)
    empty_col = repmat("", nRows, 1);
elseif ischar(sample_col)
    empty_col = repmat({''}, nRows, 1);
else
    error('Unsupported table column class for CSV export: %s', class(sample_col));
end
end
function show_instructions(window, mode, responseKeys, black, white, KB)
% Display task instructions across two screens (80 pt text), then restore
% the main task text size (160 pt).
left_key  = responseKeys{1}(1);   % '1!' -> '1',  '2@' -> '2'
right_key = responseKeys{2}(1);

if strcmp(mode, 'mri')
    left_label  = 'INDEX finger';
    right_label = 'MIDDLE finger';
    continue_msg = 'Press any button to continue.';
    ready_msg   = 'Press any button when ready.';
else
    left_label  = sprintf('key  %s', left_key);
    right_label = sprintf('key  %s', right_key);
    continue_msg = 'Press any key to continue.';
    ready_msg   = 'Press any key when ready.';
end

Screen('TextSize', window, 80);

% --- Screen 1: task description ---
instr1 = sprintf([...
    'Image Matching Task\n\n\n'...
    'On each trial you will see three images:\n'...
    'one at the TOP  and  two at the BOTTOM.\n\n'...
    'Your task:\n'...
    'find which BOTTOM image matches the TOP image.\n\n'...
    '%s'], continue_msg);

Screen('FillRect', window, white);
DrawFormattedText(window, instr1, 'center', 'center', black, 45, [], [], 1.4);
Screen('Flip', window);
KbStrokeWait(KB);

% --- Screen 2: response mapping ---
instr2 = sprintf([...
    'How to respond:\n\n\n'...
    'LEFT image matches   -->   press %s\n\n'...
    'RIGHT image matches  -->   press %s\n\n\n'...
    'Respond as QUICKLY and ACCURATELY\n'...
    'as possible.\n\n\n'...
    '%s'], left_label, right_label, ready_msg);

Screen('FillRect', window, white);
DrawFormattedText(window, instr2, 'center', 'center', black, 45, [], [], 1.4);
Screen('Flip', window);
KbStrokeWait(KB);

Screen('TextSize', window, 160);  % restore main task text size
end

function img = load_rgba(fpath)
% Read an image file. If it is a PNG with a separate alpha channel (e.g.
% transparent shapes), append alpha as channel 4 so PsychToolbox renders
% transparent areas as the window background rather than black.
[rgb, ~, alpha] = imread(fpath);
if isempty(alpha)
    img = rgb;
else
    img = cat(3, rgb, alpha);
end
end

function dst = fit_rect(img_w, img_h, max_w, max_h, cx, cy)
% Return [left top right bottom] that places an img_w x img_h image
% centred at (cx, cy), scaled to fill max_w x max_h preserving aspect ratio.
scale = min(max_w / img_w, max_h / img_h);
hw = img_w * scale / 2;
hh = img_h * scale / 2;
dst = [cx - hw, cy - hh, cx + hw, cy + hh];
end

function write_error_csv(err_base, day, run, acc, source_csv_path, ME)
stack_locations = cell(numel(ME.stack), 1);
for idx = 1:numel(ME.stack)
    stack_locations{idx} = sprintf('%s:%d', ME.stack(idx).name, ME.stack(idx).line);
end

error_table = table(day, run, acc, {source_csv_path}, {ME.identifier}, {ME.message}, {strjoin(stack_locations, ' | ')}, ...
    'VariableNames', {'day', 'run', 'accuracy', 'source_csv_path', 'error_identifier', 'error_message', 'error_stack'});

writetable(error_table, [err_base '.csv']);
end
