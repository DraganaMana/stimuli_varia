% =============================================================================
% BREATH-HOLD CEREBROVASCULAR REACTIVITY (CVR) PARADIGM
% =============================================================================
%
% PURPOSE:
%   This script runs a breath-hold CVR paradigm during MRI scanning.
%   It measures how brain blood vessels respond to CO2 changes by having
%   participants repeatedly hold their breath. CO2 is recorded continuously
%   via a CapStar-100 device throughout the task.
%
% TASK STRUCTURE:
%   Each block lasts 60 seconds and contains:
%     1. Breathe normally         (21 s)  - baseline breathing
%     2. Paced breathing out      ( 3 s)  |
%     3. Paced breathing in       ( 3 s)  | x3 cycles = 18 s
%     4. Prepare to hold          ( 3 s)  - cue to get ready
%     5. Hold your breath         (15 s)  - breath hold with countdown timer
%     6. Exhale through nose      ( 3 s)  - critical for CO2 capture
%
%   After all blocks, a 39-second recovery period (breathe normally) is appended.
%
%   Default: 8 blocks  x  60 s  +  39 s recovery  =  ~8.65 minutes total
%
% PARTICIPANT COACHING NOTES:
%   - Emphasise exhaling through the NOSE after the breath hold (not mouth),
%     as CO2 is sampled from the nasal cannula.
%   - Paced breathing cycles prime participants for a maximal hold.
%   - A countdown timer is displayed during the 15-second breath hold to
%     help participants stay on task.
%
% HARDWARE / SETUP:
%   - MRI-compatible button box : Current Designs, Inc. 932
%   - Scanner trigger key       : '+' (sent by MRI at volume onset)
%   - CO2 recorder              : CapStar-100 (start before script, stop
%                                 several seconds AFTER script finishes to
%                                 capture the delayed gas signal)
%   - Set the scanning protocol duration a few seconds LONGER than this
%     script to absorb any PsychToolbox overhead.
%
% ORIGINAL AUTHOR: Baarbod Ashenagar
% ADAPTED BY     : [your name]
% =============================================================================

% ---- Housekeeping -----------------------------------------------------------
close all;
clear;
Screen('Preference', 'SkipSyncTests', 1);

% ---- Keyboard / trigger setup -----------------------------------------------
% Retrieve all keyboard device indices and their product names.
[keyboardIndices, productNames] = GetKeyboardIndices;

% Select the MRI button box by name. Change this string if your system uses
% a different device name (check with GetKeyboardIndices on your machine).
KB = keyboardIndices(strcmp(productNames, 'Current Designs, Inc. 932'));

KbName('UnifyKeyNames');

% Scanner sends a '+' character as the trigger pulse at each volume onset.
triggerKey = KbName('+');

% ---- Condition durations (seconds) ------------------------------------------
% Index maps to condition number used in the block sequence below:
%   1 = Breathe normally (baseline)
%   2 = Breathe out      (paced)
%   3 = Breathe in       (paced)
%   4 = Prepare          (pre-hold cue)
%   5 = Hold breath      (15 s hold with countdown)
%   6 = Exhale nose      (post-hold exhalation)
%   7 = Breathe normally (post-task recovery)
conddur = [21, 3, 3, 3, 15, 3, 39];

% Fast version for testing — comment out conddur above and uncomment below:
% conddur = [0.5, 0.5, 0.5, 0.5, 3, 0.5, 5];

% ---- Block sequence ---------------------------------------------------------
% Condition indices played out within a single 60-second block:
%   [baseline | out-in x3 | prepare | hold | exhale]
block = [1, 2, 3, 2, 3, 2, 3, 4, 5, 6];

% Single post-task period appended once after all blocks end.
block_post = [7];

% Total number of task blocks.
nblock = 8;

% ---- Build stimulus timing vector -------------------------------------------
% Time step in seconds (one screen update every 250 ms).
dt = 0.25;

% Total task duration (blocks only) in seconds.
tmax = nblock * sum(conddur(block));

% Time axis covering full task + post-task recovery period.
X = (1 : round((tmax + conddur(7)) / dt)) * dt;

% Build condition label vector y for one block, then tile across all blocks.
y            = [];
current_time = 0;
for iperiod = 1:numel(block)
    tperiod  = conddur(block(iperiod));
    xperiod  = current_time + (1 : round(tperiod / dt)) * dt;
    yperiod  = block(iperiod) * ones(1, numel(xperiod));
    y        = [y, yperiod]; %#ok<AGROW>
    current_time = max(xperiod);
end
y = y(:);
Y = repmat(y, nblock, 1); % tile for all blocks

% Append the post-task recovery period.
post_task_time = 0;
y_post         = [];
for iperiod = 1:numel(block_post)
    tperiod        = conddur(block_post(iperiod));
    xperiod        = post_task_time + (1 : round(tperiod / dt)) * dt;
    yperiod        = block_post(iperiod) * ones(1, numel(xperiod));
    y_post         = [y_post, yperiod]; %#ok<AGROW>
    post_task_time = max(xperiod);
end
Y = [Y; y_post(:)];

% Plot the condition timeline as a quick sanity check (closes with screen).
figure;
plot(X, Y);
xlabel('Time (s)');
ylabel('Condition');
title('CVR breath-hold paradigm — condition timeline');
yticks(1:7);
yticklabels({'Breathe normally','Breathe out','Breathe in',...
             'Prepare','Hold breath','Exhale nose','Recovery'});

% ---- PsychToolbox screen setup ----------------------------------------------
PsychDefaultSetup(2);

% Use the highest-numbered screen (typically the projector in the MRI suite).
screens      = Screen('Screens');
screenNumber = max(screens);

% Off-white background (slightly below maximum to reduce glare).
white = 0.9 * WhiteIndex(screenNumber);

% Open full-screen window.
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, white);

% Monitor refresh interval (seconds per frame).
ifi = Screen('GetFlipInterval', window);

% Enable alpha blending for smooth text rendering.
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% Pixel coordinates of the screen centre.
[xCenter, yCenter] = RectCenter(windowRect);

% Large font for legibility at MRI viewing distance.
Screen('TextSize', window, 100);

% Number of monitor frames per timing step (dt).
waitframes = round(dt / ifi);

% ---- Waiting screen ---------------------------------------------------------
% Displayed while the experimenter prepares and waits for the scanner trigger.
DrawFormattedText(window, 'Breathing task will begin soon...', 'center', 'center', [0, 0, 0]);
vbl = Screen('Flip', window);

% Elevate process priority to minimise timing jitter during stimulus delivery.
Priority(MaxPriority(window));

% Halt here until the MRI scanner sends its trigger pulse.
KbTriggerWait(triggerKey, KB);

% ---- Main stimulus loop -----------------------------------------------------
for iblock = 1:nblock

    bh_case     = 0;  % flag: currently in breath-hold condition (0 = no, 1 = yes)
    global_time = 0;  % elapsed time within this block (seconds)
    bh_time     = 0;  % elapsed time within the current breath-hold (seconds)

    tic; % time each block so you can monitor overhead in the command window

    for iy = 1:numel(y)

        % Condition index at the current time step.
        icondition = y(iy);

        % Map condition index to the instruction string shown on screen.
        switch icondition
            case 1; str = 'Breathe normally';
            case 2; str = 'Breathe out';
            case 3; str = 'Breathe in';
            case 4; str = 'Prepare to hold your breath';
            case 5; str = 'Hold your breath';   % handled separately below
            case 6; str = 'Exhale through nose';
            case 7; str = 'Breathe normally';
        end

        if icondition == 5
            % ---- Breath-hold condition: show instruction + countdown timer --
            bh_case = 1;
        end

        if ~bh_case
            % Standard condition: reset breath-hold timer and show instruction.
            bh_time = 0;
            DrawFormattedText(window, str, 'center', 'center', [0, 0, 0]);

        else
            % Breath-hold condition: advance timer and render countdown.
            bh_time = bh_time + dt;

            % Seconds remaining in the 15-second hold (displayed as ceiling).
            countdown_time = conddur(5) - bh_time;

            % Instruction text above centre; countdown in dark red below centre.
            DrawFormattedText(window, str,                                       'center',      0.9 * yCenter, [0,    0, 0]);
            DrawFormattedText(window, ['Time remaining: ' num2str(floor(countdown_time) + 1)], ...
                                                                                 0.5 * xCenter, 1.2 * yCenter, [0.65, 0, 0]);

            % Reset flag for the next time step (re-raised by case 5 above).
            bh_case = 0;
        end

        % Push the drawn frame to the display, locked to the vertical retrace.
        vbl = Screen('Flip', window, vbl + waitframes * ifi);

        global_time = global_time + dt;

    end % time-step loop

    toc; % print elapsed block time to command window

end % block loop

% ---- Cleanup ----------------------------------------------------------------
WaitSecs(1);   % brief pause so the last frame is visible before closing
close all;     % close the timing figure
sca;           % close all PsychToolbox screens
