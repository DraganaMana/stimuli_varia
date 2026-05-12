% ======================================================================= %
% Script to record button presses during a resting state run 
% INPUTS:
%   subject -> subjectID
%   run -> run number (or identifier)
%   numTRs -> number of TRs for that run 
%   scan -> 0/1 depending on if testing/scanning 
% ======================================================================= %
% OUTPUT
%   starttime -> time of first trigger 
%   clicks -> button press timing 
%   keyvals -> which buttons were pressed 
%   trtimes -> times of TRs 
% ======================================================================= %
% EXAMPLE USAGE
% 25-minute runs:
% [starttime, clicks, keyvals, trtimes] = buttonPresses_smb_v3('ag175','01', 4096, 1)
%
% 3 minute runs: 
% [starttime, clicks, keyvals, trtimes] = buttonPresses_smb_v3('ag175','01', 477, 1)
% ======================================================================= %


function [starttime, clicks, keyvals, trtimes] = buttonPresses_smb_v3(subject, run, numTRs, scan)
TR = 0.6;
KbName('UnifyKeyNames')
[i, j] = GetKeyboardIndices;

if scan
    KB=i(find(strcmp(j,'Current Designs, Inc. 932'))); %% This is the name of the keyboard in our system. May be different in your system
else
    KB = i(find(strcmp(j, 'AT Translated Set 2 keyboard'))); % NATIVE KEYBOARD
end
KbName('UnifyKeyNames')

trval = KbName('+');
% trval=KbName('5%');29
quitval = KbName('9(');

KbQueueCreate(KB);
KbQueueStart(KB);

currTime = GetSecs;
totaltime = (numTRs/TR) + 5; % scantime + 10 seconds
disp('waiting for first trigger');
% Wait for trigger to start scan
triggered = 0;
while ~triggered
    pause(0.005);
    [pressed,firstpress]=KbQueueCheck(KB);
    if pressed && ismember(trval,find(firstpress))
        disp('got first trigger') ;
        triggered = 1;
        starttime = firstpress(trval);
    end
end

% Start KbQueue to check for quit
KB_native = i(find(strcmp(j, 'AT Translated Set 2 keyboard')));
KbQueueCreate(KB_native);
KbQueueStart(KB_native);

trtimes = zeros(numTRs, 1);
trCount = 1;
trtimes(1) = GetSecs;

clicks = nan(10000, 1);
keyvals = nan(10000, 1);
clickCount = 1;
while currTime - starttime < totaltime
    currTime = GetSecs;
    [pressed, firstpress] = KbQueueCheck(KB);
    [quit_pressed, quit_firstpress] = KbQueueCheck(KB_native);
    if pressed
        k = find(firstpress); % identify which button was clicked
        for j = 1:length(k)
            if (k(j) == trval) % if it is a trigger; save the trigger time
                trtimes(trCount) = firstpress(k(j));
                trCount = trCount+1;
            elseif (k(j) ~= trval)
                keyvals(clickCount) = k(j);
                clicks(clickCount) = firstpress(k(j));
                clickCount = clickCount+1;
            end
        end
    end % if pressed

    % If manual quit, then quit and save
    if quit_pressed
        k = find(quit_firstpress);
        for j = 1:length(k)
            if k(j) == quitval
                clicks = clicks(~isnan(clicks));
                keyvals = keyvals(~isnan(keyvals));
                save(['/home/lewislab/Documents/stimuli/NIGHT/Data/', subject, '_', run, '_behav'], 'starttime', 'clicks', 'keyvals', 'trtimes')
                totaltime = 0;
            end
        end
    end

end % while currTime

clicks = clicks(~isnan(clicks));
keyvals = keyvals(~isnan(keyvals));
save(['/home/lewislab/Documents/stimuli/NIGHT/Data/', subject, '_', run, '_behav'], 'starttime', 'clicks', 'keyvals', 'trtimes')
disp('Stoped recording button presses')
KbQueueRelease(KB);
KbQueueRelease(KB_native);


end