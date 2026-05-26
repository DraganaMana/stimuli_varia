function [acc, data] = emot_face_stim_26(day, run, opts)
% Emotion matching task (cleaned from EyeEmotMatchV5)
% Alternating blocks:
%   - Match Faces  (blocks 1, 3, 5, 7)
%   - Match Shapes (blocks 2, 4, 6, 8)
% Each trial shows 1 top image + 2 bottom choice images for 4 s.
% Participant selects left/right match with button box keys.
%
% Required inputs:
%   day : day number (integer, 1–30)
%   run : run number (integer, 1 or 2)
%
% Optional input (opts struct fields):
%   .csv_path      : path to trial_list.csv
%                    (default: trial_list_local.csv in same folder as this script)
%   .data_path     : directory where output .csv files are saved
%                    (default: <script folder>/data/)
%   .skipSyncTests : 1 to skip PTB sync test (default 2)
%   .mode          : 'mri' (default) or 'laptop'
%   .waitForTrigger: wait for trigger before task start (default: false for laptop, true for mri)
%   .triggerKey    : trigger key name for KbName (default '+')
%   .responseKeys  : cell array with left/right key names (default {'1!','2@'})
%   .keyboardName  : device name to match in GetKeyboardIndices (default: Current Designs device in mri mode)
%   .whichScreen   : PTB screen index (default: max(Screen('Screens')))
%
% Outputs:
%   acc  : fraction correct over all task trials
%   data : struct with saved trial timing and response info

% Set to 1 when testing outside the MRI (skips trigger wait, uses all keyboards).
% Set to 0 for real scanning sessions (waits for the scanner trigger, default key: '+').
outside_of_mri_test = 0;

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
    if outside_of_mri_test
        opts.mode = 'laptop';
    else
        opts.mode = 'mri';
    end
end
if ~isfield(opts, 'triggerKey')
    opts.triggerKey = '+';
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

    keylist = ones(1, 256);    % accept any key from the response box
    keylist(trigger) = 0;     % except the scanner trigger (fires at every TR)

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

    % Hardcode 0-255 colors — do not use WhiteIndex/BlackIndex, which return
    % 1.0 if a previous script in the session enabled PTB normalized color mode.
    gray  = 128;   % medium gray — Hariri-task convention
    black = 0;

    [window, windowRect] = Screen('OpenWindow', whichScreen, gray);

    % Alpha blending lets transparent shape PNG areas show the gray bg.
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

    % Large text — legible at MRI viewing distance.
    Screen('TextSize', window, 160);

    % Flip the loading screen BEFORE GetFlipInterval so the window is never
    % blank during the measurement (that blank was the mysterious flash).
    Screen('FillRect', window, gray);
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
    numTrials = 5;
    numBlocks = 8;   % 4 face + 4 shape per run, interleaved
    totalTrials = numTrials * numBlocks;

    display_duration = 4.0;

    % Jittered ITIs (s) for face blocks; fixed ITI for shape blocks.
    % 5 values per block, randomised within each face block at runtime.
    % Face blocks are at odd positions (1,3,5,7); shape blocks at even (2,4,6,8).
    isiF = [2 2 4 6 6];
    isiS = [2 2 2 2 2];

    isiL = [];
    for bl = 1:numBlocks
        if ismember(bl, [1 3 5 7])
            isiL = [isiL, isiF(randperm(numel(isiF)))]; %#ok<AGROW>
        else
            isiL = [isiL, isiS]; %#ok<AGROW>
        end
    end

    isiTimeFrames  = ceil(isiL / ifi);
    cueFrames      = ceil(3 / ifi);
    trialdurFrames = ceil(display_duration / ifi);

    %% Instructions
    show_instructions(window, windowRect, char(mode), opts.responseKeys, black, gray, KB);

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

    %% Blank gray screen — pre-task baseline (dummy volumes reach steady state before trigger fires)
    EQUIL_SECS = 10;
    Screen('FillRect', window, gray);
    Screen('Flip', window);
    WaitSecs('UntilTime', ts + EQUIL_SECS);

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

    trialkey     = zeros(1, totalTrials);  % key code pressed per trial (0 = no response)
    trialcounter = 0;
    consecutive_no_response = 0;   % alertness monitor (MRI-only)

    %% Main task loop
    for bl = 1:numBlocks
        is_face_block = ismember(bl, [1 3 5 7]);
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
                    Screen('FillRect', window, gray);
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
            KbQueueFlush(KB);   % discard any presses from the cue / ITI period
            for frame = 1:(trialdurFrames - 1)
                Screen('FillRect', window, gray);
                Screen('DrawTexture', window, top_textures{trialcounter},   [], top_dstRects(:,   trialcounter));
                Screen('DrawTexture', window, left_textures{trialcounter},  [], left_dstRects(:,  trialcounter));
                Screen('DrawTexture', window, right_textures{trialcounter}, [], right_dstRects(:, trialcounter));
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
                        if respsec(trialcounter) == 0
                            if keyvalcorr == keys(j)
                                responsecorr(trialcounter) = 1;
                            else
                                responsecorr(trialcounter) = 0;
                            end
                            respsec(trialcounter)  = firstpress(keys(j)) - stimonset(trialcounter);
                            trialkey(trialcounter) = keys(j);
                        end
                    end
                end
            end

            % ITI fixation period
            for frame = 1:(isiTimeFrames(trialcounter) - 1)
                Screen('FillRect', window, gray);
                DrawFormattedText(window, '+', 'center', 'center', black);
                [ts, ~] = Screen('Flip', window, ts + (waitframes - 0.5) * ifi);

                framecounter = framecounter + 1;
                allt(framecounter)      = ts;
                frametype(framecounter) = 2;
            end

            % MRI alertness check: warn after 2 consecutive trials with no response.
            if ~outside_of_mri_test
                if respsec(trialcounter) == 0
                    consecutive_no_response = consecutive_no_response + 1;
                else
                    consecutive_no_response = 0;
                end
                if consecutive_no_response >= 2
                    Screen('FillRect', window, gray);
                    DrawFormattedText(window, ...
                        'Please stay focused!\n\nRemember to press a button\nfor each image pair.\n\nPress any button\nto continue.', ...
                        'center', 'center', black);
                    Screen('Flip', window);
                    KbQueueFlush(KB);
                    alert_pressed = false;
                    while ~alert_pressed
                        pause(0.005);
                        [alert_pressed, ~] = KbQueueCheck(KB);
                    end
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
    data.output_files = write_run_csv(output_base, T, day, run, acc, stimonset, respsec, responsecorr, trialkey, isiL, blockonset, allt, frametype, framecounter, data.screenX, data.screenY, opts.csv_path);

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

    fprintf('\n!!! TASK ERROR: %s\n', ME.message);
    for si = 1:numel(ME.stack)
        fprintf('    at %s (line %d)\n', ME.stack(si).name, ME.stack(si).line);
    end

    try
        err_base = fullfile(opts.data_path, sprintf('ERROREDOUT_EmotMatch_day%d_run%d_%s', day, run, datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
        write_error_csv(err_base, day, run, acc, opts.csv_path, ME);
        fprintf('Error log written to: %s\n', [err_base '.csv']);
    catch err2
        fprintf('Could not write error log: %s\n', err2.message);
    end

    rethrow(ME);
end
end

function files = write_run_csv(output_base, T, day, run, acc, stimonset, respsec, responsecorr, trialkey, isiL, blockonset, allt, frametype, framecounter, screenX, screenY, source_csv_path)

n = height(T);
trial_index    = (1:n)';
block_number   = T.block;
trial_in_block = T.trial;
is_face_block  = double(ismember(block_number, [1 3 5 7]));

trigger_ts = allt(1);

has_resp        = respsec(:) > 0;
key_code_col    = double(trialkey(:));
key_code_col(~has_resp) = NaN;
keypress_ts_col = NaN(n, 1);
keypress_ts_col(has_resp) = stimonset(has_resp) + respsec(has_resp);

rc_col = double(responsecorr(:));
rc_col(~has_resp) = NaN;

% Build table column by column starting from T (avoids table() constructor
% shape strictness — MATLAB auto-transposes row vectors on column assignment).
behavioral_tbl = T;
behavioral_tbl.trial_index        = trial_index;
behavioral_tbl.block_number       = block_number;
behavioral_tbl.trial_in_block     = trial_in_block;
behavioral_tbl.is_face_block      = is_face_block;
behavioral_tbl.block_onset        = blockonset(block_number)';
behavioral_tbl.stimonset          = stimonset(:);
behavioral_tbl.respsec            = respsec(:);
behavioral_tbl.responsecorr       = rc_col;
behavioral_tbl.key_code           = key_code_col;
behavioral_tbl.keypress_timestamp = keypress_ts_col;
behavioral_tbl.isi_seconds        = isiL(:);
behavioral_tbl.trigger_timestamp  = repmat(trigger_ts, n, 1);
behavioral_tbl.accuracy           = repmat(acc, n, 1);
behavioral_tbl.screenX            = repmat(screenX, n, 1);
behavioral_tbl.screenY            = repmat(screenY, n, 1);
behavioral_tbl.source_csv_path    = repmat({source_csv_path}, n, 1);

files.behavioral_file = [output_base '_behavioral.csv'];
writetable(behavioral_tbl, files.behavioral_file);
fprintf('Saved behavioral CSV: %s\n', files.behavioral_file);

% Frame log — one row per screen flip, minimal columns
frame_tbl = table( ...
    repmat(day, framecounter, 1), ...
    repmat(run, framecounter, 1), ...
    (1:framecounter)', ...
    allt(1:framecounter), ...
    frametype(1:framecounter), ...
    repmat(screenX, framecounter, 1), ...
    repmat(screenY, framecounter, 1), ...
    'VariableNames', {'day', 'run', 'frame_index', 'timestamp', 'frame_type', 'screenX', 'screenY'});

files.frames_file = [output_base '_frames.csv'];
writetable(frame_tbl, files.frames_file);
fprintf('Saved frames CSV:     %s\n', files.frames_file);
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

function show_instructions(window, windowRect, mode, responseKeys, black, gray, KB)
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
    'Image Matching Task\n\n'...
    'On each trial you will see three images:\n'...
    'one at the TOP  and  two at the BOTTOM.\n\n'...
    'Your task:\n'...
    'find which BOTTOM image matches the TOP image.\n'...
    '%s'], continue_msg);

% Start text at 15% from the top so the title sits mid-screen, not near the top edge.
sy = windowRect(4) * 0.15;

Screen('FillRect', window, gray);
DrawFormattedText(window, instr1, 'center', sy, black, 45, [], [], 1.4);
Screen('Flip', window);
KbStrokeWait();   % no device arg = any keyboard; avoids Linux device-index issues

% --- Screen 2: response mapping ---
instr2 = sprintf([...
    'How to respond:\n\n'...
    'LEFT image matches   -->   press %s\n'...
    'RIGHT image matches  -->   press %s\n\n'...
    'Respond as QUICKLY and ACCURATELY\n'...
    'as possible.\n\n'...
    '%s'], left_label, right_label, ready_msg);

Screen('FillRect', window, gray);
DrawFormattedText(window, instr2, 'center', sy, black, 45, [], [], 1.4);
Screen('Flip', window);
KbStrokeWait();   % no device arg = any keyboard

Screen('TextSize', window, 160);  % restore main task text size
end

function img = load_rgba(fpath)
% Read an image file and return an MxNx4 RGBA array.
% Files with a real alpha channel (shape PNGs) use it directly so the gray
% screen background shows through transparent areas.
% Face images (BMP, JPG) have no alpha channel and are loaded fully opaque,
% preserving their white background consistently across databases.
% (Synthesising transparency from near-white pixels does not work reliably
% for JPEG files because lossy compression blurs edge pixels.)
[rgb, ~, alpha] = imread(fpath);
if isempty(alpha)
    alpha_ch = uint8(255 * ones(size(rgb, 1), size(rgb, 2), 'uint8'));
    img = cat(3, rgb, alpha_ch);
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
