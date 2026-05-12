
% +Breathhold task script by Baarbod Ashenagar

% To use, make sure the deviceString is set to the correct keyboard to be
% used during the experiment, as well as +the correct trigger key.

% This task consists of normal breathing, three cycles of paced breath 
% in/out, preparation for a breathhold, breathhold, and then exhale.
% Set the scanning protocal time to be a few seconds longer than the
% stimulus script in order to account for overhead time. Also, make sure 
% to continue recording CO2 from the capstar-100 several seconds after the 
% task is complete in order to+ account for the delayed gas data.

% clear the workspace and the screen
close all;
clear;

Screen('Preference', 'SkipSyncTests', 0)


% get system info that is needed for the triggers to work
%[keyboardIndices, productName[i j] = GetKeyboardIndices()5+s] = GetKeyboardIndices;

[i j]=GetKeyboardIndices;
KB=i(find(strcmp(j,'Current Designs, Inc. 932'))); %% This is the name of the keyboard in our system. May be different in your system
%KB=i(find(strcmp(j, 'AT Translated Set 2 keyboard')));
KbName('UnifyKeyNames')


% define these based on where the experiment is taking place
%deviceString = 'Keyboard'; % baarbod's 9th floor BU computer
triggerKey = KbName('+'); % trigger key at BU

% for i=1:length(productmes)               % for each possible device
%   if strcmp(productNames{i},deviceString)  % compare the name to the name you want
%     deviceNumber=keyboardIndices(i);       % grab the correct id, and exit loop
%     break;
%   end5
% end

% durations of each condition during the stimulus block
conddur = [21, 3, 3, 3, 15, 3]; % for ++experiment 
% conddur = [0.5, 0.5, 0.5, 0.5, 3, 0.5]; % faster stim for


% ordering o++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++f conditions within a single block
block = [1, 2, 3, 2, 3, 2, 3, 4, 5, 6];

% total++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
% blocks
% nblock=1;
nblock=9;
% total time (actual+ time will be slightly higher due to overhead)
tmax = nblock*sum(conddur(block));

% stimulus timing vectors
dt = 0.25;
X = (1:round(tmax/dt))*dt;
y = [];
current_time = 0;
for iperiod = 1:numel(block)
   tperiod = conddur(block(iperiod)); 
   xperiod = current_time + (1:round(tperiod/dt))*dt;
   yperiod = block(iperiod) * ones(1, numel(xperiod));
   y = [y, yperiod];
   current_time = max(xperiod);
end
y = y(:);
Y = repmat(y,nblock, 1);
figure, plot(X, Y)

% default settings for setting up Psychtoolbox
PsychDefaultSetup(2);

% get the screen numbers
screens = Screen('Screens');

% Select the external screen
screenNumber = max(screens);


% define white background color
white = 0.9*WhiteIndex(screenNumber);

% open an on screen window and color it white
rect = [200,200,1000,600];
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, white);

% get the vertical refresh rate of the monitor
ifi = Screen('GetFlipInterval', window);

% set the blend function for the screen
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

% find center coordinates in pixels
[xCenter, yCenter] = RectCenter(windowRect);

% set text size
Screen('TextSize', window, 140);

% define frames for inter-image interval based on screen refresh rate
waitframes = round(dt / ifi);

str = 'Breathing task \n begins soon...';
DrawFormattedText(window, str, 'center', 'center', [0, 0, 0]);

% Flip to the vertical retrace rate
vbl = Screen('Flip', window);
    
% Maximum priority level
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

% wait for trigger to start stimulus presenation
KbTriggerWait(triggerKey, KB)

% repeat loop for each stimulus block
for iblock = 1:nblock
    bh_case = 0; % default to non BH case
    global_time = 0; % counter for global time
    bh_time = 0; % counter for each breathhold
    bh_flag = 0; % flag if in a breathhold

    tic % track time of each stimulus block to ensure accurate duration
    for iy = 1:numel(y)
        
        % stimulus condition ID at current time
        icondition = y(iy);
        
        % define case based on current condition
        switch(icondition)
            case 1; str = 'Breathe \n normally';
            case 2; str = 'Breathe out';
            case 3; str = 'Breathe in';
            case 4; str = ['Breathe out- \n Prepare to hold \n your breath'];
            case 5
                str = 'Hold your breath';
                % breath hold flag
                bh_case = 1;
            case 6; str = 'Exhale \n through nose';
        end
        
        % if not a breathhold, just draw a static image
        if ~bh_case
            
            % make breath hold timer zero
            bh_time = 0;
            
            % draw text onto screen based on string from case
            DrawFormattedText(window, str, 'center', 'center', [0, 0, 0]);
            
        % if breathhold, the image has a countdown timer
        elseif bh_case
            
            % advance breath hold time
            bh_time = bh_time + dt;
            
            % breath hold countdown timer
            countdown_time = conddur(5) - bh_time;
            
            % define strings to display
            str1 = str;
            str2 = ['Time Remaining: ' num2str(floor(countdown_time)+1)];
            
            % draw text onto screen
            DrawFormattedText(window, str1, 'center', 0.9*yCenter, [0, 0, 0]);
            DrawFormattedText(window, str2, 0.5*xCenter, 1.2*yCenter, [0.65, 0, 0]);
            
            % set breath hold flag back to normal
            bh_case = 0;
        end
        
        % update screen
        vbl = Screen('Flip', window, vbl + (waitframes) * ifi);
        
        % advance global time
        global_time = global_time + dt;
        
    end
    toc
    
end
% toc 

% Wait a second before closing the screen
WaitSecs(1);

% Clear the screen
close all;
sca

