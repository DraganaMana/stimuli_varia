function [acc, data] = emot_face_stim_eyetracking(day, run, opts)
% Emotion matching task with optional EyeLink eye tracking.
% Identical to emot_face_stim_26 but adds EyeLink integration.
% Set opts.use_eyelink = true to enable the eye tracker.
%
% Required inputs:
%   day : day number (integer, 1–30)
%   run : run number (integer, 1 or 2)
%
% Optional input (opts struct fields):
%   .csv_path      : path to trial_list.csv
%                    (default: trial_list_local.csv in same folder as this script)
%   .data_path     : directory where output files are saved
%                    (default: <script folder>/data/)
%   .skipSyncTests : 1 to skip PTB sync test (default 2)
%   .mode          : 'mri' (default) or 'laptop'
%   .waitForTrigger: wait for trigger before task start (default: false for laptop, true for mri)
%   .triggerKey    : trigger key name for KbName (default '+')
%   .responseKeys  : cell array with left/right key names (default {'1!','2@'})
%   .keyboardName  : device name to match in GetKeyboardIndices
%   .whichScreen   : PTB screen index (default: max(Screen('Screens')))
%   .use_eyelink   : true to enable EyeLink eye tracking (default false)
%   .edf_filename  : EDF filename on tracker host PC — base name must be <=8 chars
%                    (default: EMd<day>r<run>.edf, e.g. EMd1r1.edf)
%   .v_dist        : viewing distance in cm (default 99, MRI bore)
%   .mon_width     : monitor horizontal width in cm (default 42.7)
%
% Outputs:
%   acc  : fraction correct over all task trials
%   data : struct with saved trial timing and response info
%
% -------------------------------------------------------------------------
% USAGE EXAMPLES
% -------------------------------------------------------------------------
%
% --- Laptop (behavioural testing, no scanner, no eye tracker) ---
%
%   opts.mode        = 'laptop';
%   opts.use_eyelink = false;
%   [acc, data] = emot_face_stim_eyetracking(1, 1, opts);
%
% --- MRI, no eye tracker ---
%
%   opts.mode        = 'mri';
%   opts.use_eyelink = false;
%   [acc, data] = emot_face_stim_eyetracking(1, 1, opts);
%
%   The script will show "Waiting for scanner trigger..." and start on the
%   first '+' (5%) pulse from the Current Designs 932 button box.
%
% --- MRI with EyeLink eye tracker ---
%
%   opts.mode        = 'mri';
%   opts.use_eyelink = true;
%   [acc, data] = emot_face_stim_eyetracking(1, 1, opts);
%
%   The EDF filename is auto-generated from day and run (e.g. EMd1r1.edf).
%   Override with opts.edf_filename only if you need a custom name
%   (base name must be <=8 characters, e.g. opts.edf_filename = 'sub01r1.edf').
%
%   The script will run calibration before the instructions, then wait for
%   the scanner trigger as normal. The EDF file is transferred from the
%   tracker host PC to the data/ folder automatically after the run.
% -------------------------------------------------------------------------

% Set to 1 when testing outside the MRI (skips trigger wait, uses all keyboards).
outside_of_mri_test = 0;

if nargin < 1; day  = 1;        end
if nargin < 2; run  = 1;        end
if nargin < 3; opts = struct(); end

% Apply test flag
if outside_of_mri_test
    if ~isfield(opts, 'mode');           opts.mode           = 'laptop'; end
    if ~isfield(opts, 'waitForTrigger'); opts.waitForTrigger = false;    end
    if ~isfield(opts, 'keyboardName');   opts.keyboardName   = '';       end
end

script_dir = fileparts(mfilename('fullpath'));

if ~isfield(opts, 'csv_path')
    opts.csv_path = fullfile(script_dir, 'trial_list_local.csv');
end
if ~isfield(opts, 'data_path')
    opts.data_path = fullfile(script_dir, 'data');
end
if ~isfield(opts, 'skipSyncTests')
    opts.skipSyncTests = 2;
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
if ~isfield(opts, 'use_eyelink')
    opts.use_eyelink = false;
end
if ~isfield(opts, 'edf_filename')
    opts.edf_filename = sprintf('EMd%dr%d.edf', day, run);
end
if ~isfield(opts, 'v_dist')
    opts.v_dist = 99;    % viewing distance in cm (MRI bore)
end
if ~isfield(opts, 'mon_width')
    opts.mon_width = 42.7;   % monitor horizontal width in cm
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

acc      = NaN;
data     = struct();
window   = [];
KB       = [];
eyerect  = [];   % defined after screen opens if use_eyelink is true

try
    %% Load trial table for this day and run
    if ~exist(opts.data_path, 'dir')
        mkdir(opts.data_path);
    end

    c           = clock;
    run_stamp   = sprintf('%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f', c(1), c(2), c(3), c(4), c(5), c(6));
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

    keylist              = ones(1, 256);
    keylist(trigger)     = 0;
    triggerlist          = zeros(1, 256);
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
    fprintf('EyeLink: %d\n', opts.use_eyelink);
    if opts.use_eyelink
        fprintf('EDF file: %s\n', opts.edf_filename);
        fprintf('Viewing distance: %.1f cm | Monitor width: %.1f cm\n', opts.v_dist, opts.mon_width);
    end
    fprintf('==========================\n\n');

    %% Screen setup
    screens = Screen('Screens');
    if isempty(opts.whichScreen)
        whichScreen = max(screens);
    else
        whichScreen = opts.whichScreen;
    end

    gray  = 128;
    black = 0;

    [window, windowRect] = Screen('OpenWindow', whichScreen, gray);
    Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');
    Screen('TextSize', window, 160);

    Screen('FillRect', window, gray);
    DrawFormattedText(window, 'Loading experiment,\nplease be patient...', 'center', 'center', black);
    Screen('Flip', window);

    topPriorityLevel = MaxPriority(window);
    Priority(topPriorityLevel);
    ifi = Screen('GetFlipInterval', window);

    dual         = get(0, 'MonitorPositions');
    resolution   = [0, 0, dual(1, 3), dual(1, 4)];
    data.screenX = resolution(3);
    data.screenY = resolution(4);

    %% Fixation interest area in pixels (for EyeLink Data Viewer)
    % Computed from viewing distance and monitor width so the box matches
    % 3.5 degrees of visual angle around the fixation cross.
    if opts.use_eyelink
        center      = [windowRect(3) windowRect(4)] / 2;
        pix_per_deg = pi * windowRect(3) / atan(opts.mon_width / opts.v_dist / 2) / 360;
        eyesize_px  = 3.5 * pix_per_deg;
        eyerect     = round([center - 0.5*eyesize_px, center + 0.5*eyesize_px]);
    end

    %% Preload image textures and compute per-image destination rects
    nRows          = height(T);
    top_textures   = cell(nRows, 1);
    left_textures  = cell(nRows, 1);
    right_textures = cell(nRows, 1);
    top_dstRects   = zeros(4, nRows);
    left_dstRects  = zeros(4, nRows);
    right_dstRects = zeros(4, nRows);

    max_w  = 340;
    max_h  = 380;
    Nshift = 240;
    Hshift = 270;

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

    %% EyeLink initialisation and calibration
    % This runs after images are loaded but before instructions, so the
    % calibration display uses the same PTB window as the task.
    if opts.use_eyelink
        el = EyelinkInitDefaults(window);

        if ~EyelinkInit(0)   % 0 = real hardware; use 1 for dummy/testing mode
            fprintf('EyeLink Init aborted.\n');
            Eyelink('Shutdown');
            Screen('CloseAll');
            return;
        end

        % Open EDF file on the tracker host PC.
        if Eyelink('Openfile', opts.edf_filename) ~= 0
            fprintf('Cannot create EDF file ''%s'' on tracker host.\n', opts.edf_filename);
            Eyelink('Shutdown');
            Screen('CloseAll');
            return;
        end

        % Tell the tracker the screen resolution.
        Eyelink('command', 'screen_pixel_coords = %ld %ld %ld %ld', 0, 0, windowRect(3)-1, windowRect(4)-1);
        Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld',        0, 0, windowRect(3)-1, windowRect(4)-1);

        % Calibration and saccade detection parameters.
        Eyelink('command', 'calibration_type = HV5');
        Eyelink('command', 'saccade_acceleration_threshold = 8000');
        Eyelink('command', 'saccade_velocity_threshold = 30');
        Eyelink('command', 'saccade_motion_threshold = 0.0');
        Eyelink('command', 'saccade_pursuit_fixup = 60');
        Eyelink('command', 'fixation_update_interval = 0');

        % What events and samples to write to the EDF file.
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');

        % What to stream in real time to MATLAB over the link.
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');

        if Eyelink('IsConnected') ~= 1
            Eyelink('Shutdown');
            Screen('CloseAll');
            return;
        end

        % Match calibration dot colours to the task background.
        el.backgroundcolour        = gray;
        el.calibrationtargetcolour = black;
        EyelinkUpdateDefaults(el);

        Eyelink('Message', 'TRIAL_VAR_LABELS trial block_type');
        Eyelink('Message', 'V_TRIAL_GROUPING trial block_type');

        % Draw a fixation box on the tracker host PC display, then calibrate.
        Eyelink('Command', 'set_idle_mode');
        Eyelink('Command', 'clear_screen 0');
        Eyelink('command', 'draw_box %d %d %d %d 15', eyerect(1), eyerect(2), eyerect(3), eyerect(4));
        WaitSecs(0.01);

        % This call takes over the screen and runs the full calibration routine.
        EyelinkDoTrackerSetup(el);

        if Eyelink('IsConnected') ~= 1
            Eyelink('Shutdown');
            Screen('CloseAll');
            return;
        end
    end

    %% Timing plan
    numTrials   = 5;
    numBlocks   = 8;   % 4 face + 4 shape per run, interleaved
    totalTrials = numTrials * numBlocks;

    display_duration = 4.0;

    % Face blocks at odd positions (1,3,5,7); shape blocks at even (2,4,6,8).
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

    %% Blank gray screen for MRI T1 equilibration (MRI mode only)
    if mode == "mri"
        EQUIL_SECS = 10;
        Screen('FillRect', window, gray);
        Screen('Flip', window);
        WaitSecs('UntilTime', ts + EQUIL_SECS);
    end

    %% Response queue for participant button presses
    KbQueueCreate(KB, keylist);
    KbQueueStart(KB);

    waitframes   = 1;
    framecounter = 1;

    allt      = zeros(30000, 1);
    frametype = zeros(30000, 1);
    allt(1)   = ts;

    responsecorr = zeros(1, totalTrials);
    respsec      = zeros(1, totalTrials);
    blockonset   = zeros(1, numBlocks);
    stimonset    = zeros(1, totalTrials);

    trialkey     = zeros(1, totalTrials);
    trialcounter = 0;
    consecutive_no_response = 0;

    %% Main task loop
    for bl = 1:numBlocks
        is_face_block = ismember(bl, [1 3 5 7]);
        if is_face_block
            msg        = 'Match Faces';
            block_type = 'face';
        else
            msg        = 'Match Shapes';
            block_type = 'shap';
        end

        % Start eye tracking recording for this block.
        if opts.use_eyelink
            Eyelink('Message', 'BLOCKID %d', bl);
            Eyelink('command', 'record_status_message "BLOCK %d"', bl);
            Eyelink('StartRecording');
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
                        % SYNCTIME marks the block epoch start in the EDF.
                        if opts.use_eyelink
                            Eyelink('Message', 'SYNCTIME');
                        end
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
                DrawFormattedText(window, '+', 'center', 'center', black);
                [ts, ~] = Screen(window, 'Flip', ts + ifi * waitframes - ifi * 0.5);

                framecounter = framecounter + 1;
                allt(framecounter)      = ts;
                frametype(framecounter) = 1;

                if frame == 1
                    stimonset(trialcounter) = ts;
                    if opts.use_eyelink
                        Eyelink('Message', 'Stim ON');
                        Eyelink('Message', 'Block %d Stim %d', bl, tr);
                        Eyelink('command', 'record_status_message "Block %d Stim %d"', bl, tr);
                    end
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

            if opts.use_eyelink
                Eyelink('Message', 'Stim OFF');
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
                    KbStrokeWait(KB);
                    KbQueueFlush(KB);
                    consecutive_no_response = 0;
                end
            end
        end   % end trial loop

        % Stop recording and write block-level metadata for EyeLink Data Viewer.
        if opts.use_eyelink
            Eyelink('StopRecording');
            Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 1, eyerect(1), eyerect(2), eyerect(3), eyerect(4), 'fix');
            Eyelink('Message', '!V TRIAL_VAR index %d', bl);
            Eyelink('Message', '!V TRIAL_VAR type %s', block_type);
            Eyelink('Message', 'TRIAL_RESULT 0');
        end
    end   % end block loop

    acc = sum(responsecorr) / totalTrials;

    %% Save behavioral outputs
    data.allt           = allt;
    data.frametype      = frametype;
    data.stimonset      = stimonset;
    data.respsec        = respsec;
    data.blockonset     = blockonset;
    data.isiL           = isiL;
    data.trialTable     = T;
    data.mode           = char(mode);
    data.waitForTrigger = opts.waitForTrigger;
    data.keyboardName   = opts.keyboardName;
    data.triggerKey     = opts.triggerKey;
    data.responseKeys   = opts.responseKeys;
    data.use_eyelink    = opts.use_eyelink;
    data.edf_filename   = opts.edf_filename;
    data.output_files   = write_run_csv(output_base, T, day, run, acc, stimonset, respsec, responsecorr, trialkey, isiL, blockonset, allt, frametype, framecounter, data.screenX, data.screenY, opts.csv_path);

    %% EyeLink: close recording, transfer EDF from tracker host to this PC
    if opts.use_eyelink
        Eyelink('Command', 'set_idle_mode');
        Eyelink('CloseFile');
        try
            fprintf('Receiving EDF file ''%s'' from tracker host...\n', opts.edf_filename);
            status = Eyelink('ReceiveFile');
            if status > 0
                fprintf('ReceiveFile status %d\n', status);
            end
            if exist(opts.edf_filename, 'file') == 2
                edf_dest = [output_base '.edf'];
                copyfile(opts.edf_filename, edf_dest);
                fprintf('EDF saved to: %s\n', edf_dest);
                data.edf_saved_path = edf_dest;
            end
        catch edf_err
            fprintf('Problem receiving EDF file: %s\n', edf_err.message);
        end
        Eyelink('ShutDown');
    end

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

    % EyeLink emergency shutdown: stop recording and salvage the EDF file.
    if opts.use_eyelink
        try
            if Eyelink('IsConnected') == 1
                Eyelink('StopRecording');
                Eyelink('Command', 'set_idle_mode');
                Eyelink('CloseFile');
                try
                    status = Eyelink('ReceiveFile');
                    if status > 0 && exist(opts.edf_filename, 'file') == 2
                        % output_base may not be defined if the error occurred
                        % very early; fall back to data_path with a timestamp.
                        if exist('output_base', 'var')
                            edf_dest = [output_base '.edf'];
                        else
                            edf_dest = fullfile(opts.data_path, ...
                                sprintf('ERROREDOUT_EMeye_%s.edf', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
                        end
                        copyfile(opts.edf_filename, edf_dest);
                    end
                catch
                end
            end
            Eyelink('ShutDown');
        catch
        end
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

% -------------------------------------------------------------------------

function files = write_run_csv(output_base, T, day, run, acc, stimonset, respsec, responsecorr, trialkey, isiL, blockonset, allt, frametype, framecounter, screenX, screenY, source_csv_path)

n              = height(T);
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

% -------------------------------------------------------------------------

function p = resolve_img_path(base_path, relative_path, script_dir)
base_path     = strrep(base_path,     '\', filesep);
relative_path = strrep(relative_path, '\', filesep);
if ~isempty(regexp(base_path, '^([A-Za-z]:[/\\]|/)', 'once'))
    p = fullfile(base_path, relative_path);
else
    p = fullfile(script_dir, base_path, relative_path);
end
end

% -------------------------------------------------------------------------

function show_instructions(window, windowRect, mode, responseKeys, black, gray, KB)
left_key  = responseKeys{1}(1);
right_key = responseKeys{2}(1);

if strcmp(mode, 'mri')
    left_label   = 'INDEX finger';
    right_label  = 'MIDDLE finger';
    continue_msg = 'Press any button to continue.';
    ready_msg    = 'Press any button when ready.';
else
    left_label   = sprintf('key  %s', left_key);
    right_label  = sprintf('key  %s', right_key);
    continue_msg = 'Press any key to continue.';
    ready_msg    = 'Press any key when ready.';
end

Screen('TextSize', window, 80);
sy = windowRect(4) * 0.15;

instr1 = sprintf([...
    'Image Matching Task\n\n'...
    'On each trial you will see three images:\n'...
    'one at the TOP  and  two at the BOTTOM.\n\n'...
    'Your task:\n'...
    'find which BOTTOM image matches the TOP image.\n'...
    '%s'], continue_msg);

Screen('FillRect', window, gray);
DrawFormattedText(window, instr1, 'center', sy, black, 45, [], [], 1.4);
Screen('Flip', window);
KbStrokeWait(KB);

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
KbStrokeWait(KB);

Screen('TextSize', window, 160);
end

% -------------------------------------------------------------------------

function img = load_rgba(fpath)
% Files with a real alpha channel (shape PNGs) use it directly.
% Face images (BMP, JPG) are loaded fully opaque — white background is
% preserved consistently across databases (JPEG compression makes
% near-white threshold masking unreliable for CFD images).
[rgb, ~, alpha] = imread(fpath);
if isempty(alpha)
    alpha_ch = uint8(255 * ones(size(rgb, 1), size(rgb, 2), 'uint8'));
    img = cat(3, rgb, alpha_ch);
else
    img = cat(3, rgb, alpha);
end
end

% -------------------------------------------------------------------------

function dst = fit_rect(img_w, img_h, max_w, max_h, cx, cy)
scale = min(max_w / img_w, max_h / img_h);
hw = img_w * scale / 2;
hh = img_h * scale / 2;
dst = [cx - hw, cy - hh, cx + hw, cy + hh];
end

% -------------------------------------------------------------------------

function write_error_csv(err_base, day, run, acc, source_csv_path, ME)
stack_locations = cell(numel(ME.stack), 1);
for idx = 1:numel(ME.stack)
    stack_locations{idx} = sprintf('%s:%d', ME.stack(idx).name, ME.stack(idx).line);
end

error_table = table(day, run, acc, {source_csv_path}, {ME.identifier}, {ME.message}, {strjoin(stack_locations, ' | ')}, ...
    'VariableNames', {'day', 'run', 'accuracy', 'source_csv_path', 'error_identifier', 'error_message', 'error_stack'});

writetable(error_table, [err_base '.csv']);
end
