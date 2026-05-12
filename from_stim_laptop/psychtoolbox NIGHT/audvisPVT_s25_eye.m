%% Experiment start 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                    %
%         PVT edited for MR scan                     %
%                                                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BEFORE START
% If connected to monitor, change the monitor to primary window in settings
% change tr line 
% Max experiment time is in seconds now

% Version control:
% 12/23/2020 - added dot PVT21
% 1/5/2021 - added shape PVT 
% 1/11/2021 - edit dot and auditory PVT
% 1/18/2021 - added eyetracking
% 1/21/2021 - change dot to cross, fixation plus
% 1/27/2021 - added UDP feature
% 3/2/2021 - current ISI: 5-10s
% 4/8/2021 - add EEG
% To use push button with audio & visual stimuli marker with EEG
% Set the "Digital port settings"
%%%%%%% Bits 0-7 High Active
%%%%%%% Bits 8-15 Low Active
%%%%%%% Enabe Bits 0,1,2,3,8,9,10
%%%%%%% Bit 0 - RENAME to Button
%%%%%%% Bit 1 - RENAME to Audio
%%%%%%% Bit 3 - RENAME to Visual 
%%%%%%% Others remained Response
% Set the Triggerbox
%%%%%%% Push button to In0; Audio device connect to In2;
%%%%%%% Only Pin 0 & 2 switch to In side
%%%%%%% disable all stretch

% 6/6/2021 - current ISI: expo 5-10s
% 7/22/2021 - only one square presented at the begining of aud task
% 8/29/2021 - add wakeup calls -> press '4$' key

% backup page: https://github.com/ziy027/PVT-multimodal/blob/main/

% Example:  
% DEBUG: 0 if no, 1 if yes < defaults to 1 >
% ntrial: number of trials, < defaults to 450, should be the maximum for 15 mins run >
% maxT: maximum time, < defaults to 720s, or 12 mins >
% If connected to monitor, change the monitor refresh rate in the join mode
% then switch to mirror mode
% audvisPVT_sp24_eye(1,'v')  % test run
% audvisPVT_sp24_eye(0,'v')  % real expud - visual
%   audvisPVT_sp21_eye(0,'a')  % real expud - auditory
% aud = sound_testformr;
% adjust the volume based on audio teston at line 454
% change the buttonbox setting to "NAR 12345", should be 4th one 

function audvisPVT_s25_eye(DEBUG, expType)

try
    %% Subjects info & Task version
    clearvars -except DEBUG expType ntrial
    
    addpath(genpath('/home/lewislab/Documents/stimuli/NIGHT/'))
    experiment_name='Psychomotor Vigilance Task - multimodal perception';
    experiment_code='audvisPVT';  % this should be a short (2-3 letter) code for the experiment
    experiment_notes= ''; % if any
    script_revision_date='2025'; %Revisions
    Accuracy = 0;
    PsychPortAudio('Close');
    
    % take in subject info
    prompt = {'\fontsize{15} subject ID = ','\fontsize{15} Do you want to use the button box?  ', ...
        '\fontsize{15} Do you want to do eyetracking? 1=yes; 0=no ', ...
        '\fontsize{15} How long do you want this experiment to be? (in mins) '};
    nometitle = (['Participant info']);
    dlg_title = nometitle; 
    size_wind = [1 50; 1 50; 1 50; 1 50]; % Windows size
    defaultans = {'testing','1','1','1'}; %default
    options.Resize = 'on';
    options.Interpreter = 'tex';
    %options.WindowStyle = 'normal';
    Matin = inputdlg(prompt,dlg_title,size_wind, defaultans,options);
    subject_code = char(Matin(1));
    button_box = str2double(char(Matin(2))); 
    eyeTrack = str2double(char(Matin(3))); 
    maxT = 60*str2double(char(Matin(4)));
    udpsend = 0;
    
%     subject_code=input('Enter subject code: ','s'); % the 's' tells input to take in a text string rather than a number
%     
%     button_box = input('Do you want to use the button box? [Enter 1 if yes, 0 if no]: ');
%     
%     udpsend = input('Do you want to send data thr UDP? [Enter 1 if yes, 0 if no]: ');
    
    if (strcmp(expType,'v'))
        experiment_type = 'dotPVT';
    elseif (strcmp(expType,'shapev'))
        experiment_type = 'shapePVT-Visual';
    elseif (strcmp(expType,'a'))
        hitaud = input('Which beep should be the target [Enter l if low, h if high]: ', 's');
        experiment_type = 'shapePVT-Auditory';
    end
    
    fprintf('This is a %s trial.\n',experiment_type); % print to the page
    fprintf('%s (revised %s)\n',experiment_name, script_revision_date); % print to the page
    
    % platform-independent responses
    KbName('UnifyKeyNames')

    [i j]=GetKeyboardIndices;
    KB=i(find(strcmp(j,'Current Designs, Inc. 932'))); %% This is the name of the keyboard in our system. May be different in your system


    % default to not fMRI
    if ~exist('DEBUG')
        DEBUG = 1;
    end
    
    % default to 900 s run time
    if ~exist('maxT')
        maxT = 720;
    end
    
    % # of trials set to maxT/5 = max # of trials
    ntrial = ceil(maxT/5);
    
    % default to not eyeTrack
    if ~exist('eyeTrack')
        eyeTrack = 0;
    end
    
    fpath='/home/lewislab/Documents/stimuli/NIGHT/Data';
    d=clock;+413
    output_fname=sprintf('%s%s_%s_%s_%02.0f-%02.0f-%02.0f-%02.0f.mat',fpath,experiment_type,subject_code,experiment_code,d(2),d(3),d(4),d(5));
    output_mname=sprintf('%s%s_%s_%s_%02.0f-%02.0f-%02.0f-%02.0f.m',fpath,experiment_type,subject_code,experiment_code,d(2),d(3),d(4),d(5));
    
    %% Run info
    % set up variables controlling trials and defaults
    number_of_trials = ntrial; % number of trials
    
    maxTime = maxT; % total experiment time, in seconds
    
    default_stimulus_duration= .5; % duration of each image/sound, in seconds
    
    default_wait = 1.5; % total time to respond, from image/sound onset
    
    default_wrap = 800; %in pixels
    
    nrchannels = 2; %default number of channels for sound playback is 1 = mono (if you have stereo sound, use nrchannels = 2)
    
    % set up variables to store data
    rt =zeros(1,number_of_trials); %vector to hold reaction times
    resp = cell(1,number_of_trials); %vector to hold responses made
    onset = zeros(1,number_of_trials); %vector to record the actual onset of each trial
    duration = zeros(1,number_of_trials); %another vector to hold RTs, in case rt fail
    tStart = zeros(1,number_of_trials); %another vector to hold actual onset time of each trial, in case onset fail
    tTrial = zeros(1,number_of_trials); % hold trial duration time
    imgpresent = zeros(1,number_of_trials);
    key_presses = struct('key',{},'time',{},'stimulus',{{}},'trial',[]); %matrix to hold key pressed, time of key press, and current stimulus (will increment up)
    wake_call = struct('time',{});
    
    % create a data structure with info about the run
    run_info.subject_code=subject_code;
    run_info.output_filename=output_fname;
    run_info.experiment_notes=experiment_notes;
    run_info.script_revision_date=script_revision_date;
    run_info.onsets=onset;
    run_info.durations=duration;
    run_info.responses=resp;
    run_info.rts=rt;
    run_info.type=experiment_type;
    run_info.tStarts = tStart;
    run_info.tTrials = tTrial;
    run_info.imgpresents = imgpresent;
    
    %% Screen setup
    
    Screen('Preference','SkipSyncTests', 1) % Necessary for MacOS High Sierra & higher, which fail the automatic sync tests Psychtoolbos does to ensure timing is exact to the millisecond-level (we don't need to be that exact here)
    
    commandwindow % so I don't accidentally type in the script
    
    screenNumber=max(Screen('Screens'));
    
    % Define black and white (white will be 1 and black 0)
    white = WhiteIndex(screenNumber);
    black = BlackIndex(screenNumber);
    grey = white / 2;
    red = [1 0 0] * white;
    
    % Open smaller screen for debugging
    if DEBUG
        rect = [200,200,1000,600];
        [window, windowRect] = Screen('OpenWindow', screenNumber, grey, rect);
    else
        [window, windowRect] = Screen('OpenWindow', screenNumber, grey,[]);
    end
    
    HideCursor;
    
    topPriorityLevel = MaxPriority(window);
    
    disp(topPriorityLevel)
    
    disp('PRIORITY')
    
    Priority(topPriorityLevel);
    
    measifi = Screen('GetFlipInterval', window);
    
    disp(measifi)
    
    Priority(0);
    
    % Fonts and text color
    theFont='Arial';
    
    Screen('TextFont',window,theFont);
    
    % Text size
    Screen('TextSize',window, 90);
    
    % Red
    Screen('TextColor',window, red);
    
    % Make the alpha blend so no harsh edges
    Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    % Get the screen parameters
    [screenXpixels, screenYpixels] = Screen('WindowSize', window); % check the window size, get x y
    center = [windowRect(3)  windowRect(4)]/2;
    
    % Draw the fixation plus according to the screen setup
    p.v_dist 		= 110;	%viewing distance behavioral: 60(cm)/99
    p.mon_width  	= 42.7;	%horizontal dimension of viewable Screen (cm)
    
    %set up pixesl per degree
    pix_per_deg = pi * windowRect(3) / atan(p.mon_width/p.v_dist/2) / 360;	% pixels per degree
    
    % Screen Y fractionfor fixation cross
    crossFrac = 1.2;% in degrees
    
    % Here we set the size of the arms of our fixation cross
    fixCrossDimPix = pix_per_deg * crossFrac;
    angles = 45;
    rotateCrossPix = fixCrossDimPix * cosd(angles);
    
    % Now we set the coordinates (these are all relative to zero we will let
    % the drawing routine center the cross in the center of our monitor for us)
    xCoords = [-fixCrossDimPix fixCrossDimPix 0 0];
    yCoords = [0 0 -fixCrossDimPix fixCrossDimPix];
    
    xCoordsrotate = [-rotateCrossPix rotateCrossPix -rotateCrossPix rotateCrossPix];
    yCoordsrotate = [rotateCrossPix -rotateCrossPix -rotateCrossPix rotateCrossPix];
    
    xCoordsSquare = [-fixCrossDimPix/2 fixCrossDimPix/2 fixCrossDimPix/2 fixCrossDimPix/2 fixCrossDimPix/2 -fixCrossDimPix/2 -fixCrossDimPix/2 -fixCrossDimPix/2];
    yCoordsSquare = [fixCrossDimPix/2 fixCrossDimPix/2 fixCrossDimPix/2 -fixCrossDimPix/2 -fixCrossDimPix/2 -fixCrossDimPix/2 -fixCrossDimPix/2 fixCrossDimPix/2];
    
    allCoords = [xCoords; yCoords];
    
    allCoordsrotate = [xCoordsrotate; yCoordsrotate];
    
    allCoordsSquare = [xCoordsSquare; yCoordsSquare];
    
    % Set the line width for our fixation cross
    lineWidthPix = 7; %8 is not in the ange (1.000000 to 7.375000) supported by your graphics hardware.
    
    % Get the center of screen
    xCenter=screenXpixels/2;
    yCenter=screenYpixels/2;
    
    % Dot size
    dotSizePix = 10;
    
    % Set default fix cross display
    default_display = sprintf('Screen(''DrawLines'', window, allCoords,lineWidthPix, red, [xCenter yCenter], 2);');
    rotate_cross = sprintf('Screen(''DrawLines'', window, allCoordsrotate,lineWidthPix, red, [xCenter yCenter], 2);');
    square = sprintf('Screen(''DrawLines'', window, allCoordsSquare,lineWidthPix, red, [xCenter yCenter], 2);');
    baseRect = [0 0 200 200];
    
    % Screen X positions of our three rectangles
    squareXpos = [screenXpixels * 0.25 screenXpixels * 0.5 screenXpixels * 0.75];
    numSqaures = length(squareXpos);
    
    % Set the colors to Red, Green and Blue
    allColors = [1 0 0];
    
    % Make our rectangle coordinates
    allRects = nan(4, 3);
    for i = 1:numSqaures
        allRects(:, i) = CenterRectOnPointd(baseRect, squareXpos(i), yCenter);
    end
    
    % Draw the rect to the screen
%     square = sprintf('Screen(''FillRect'', window, allColors, allRects);');
    
    % Rotate texture
    textureRect = ones(ceil((windowRect(4) - windowRect(2)) * 1 ),...
        ceil((windowRect(3) - windowRect(1)) * 1)) .* grey;
    textTexture = Screen('MakeTexture', window, textureRect);
    
    % Put up a cross while waiting for trigger
    eval(default_display); % fixation cross
    vbl = Screen('Flip', window);
    %% Eyelink setup
    
    get_eye = 0;
    
    if eyeTrack == 1
        get_eye = 1;
        edf_filename = 'avPVT.edf';
        
        % convert stim size to pixels
        % fixation circle
        fixsize=.5; % in degrees
        fixsize=fixsize*pix_per_deg;
        
        fixrect=[center-.5*fixsize, center+.5*fixsize];
        
        %%discrimination box
        eyesize=3.5;% in degrees
        eyesize=eyesize*pix_per_deg;
        
        eyerect=round([center-.5*eyesize, center+.5*eyesize]);
    end
    
    %% Design matrix
    % Set the scanner TR
    tr=0.378;
    
    ifi = measifi;
    initialfix = 3; % in sec
    offset = 2; % in sec
    expdur = maxTime - initialfix - offset; % experiement time = max time in scanner - initial fix - offset
    frt = ceil(expdur/ifi); % all possible flip frames
    
    waitframes = round(default_stimulus_duration / ifi); %stimulus duration in frames
    respframes = round(default_wait/ifi); % wait for response frames
    
    y=ones(1,frt);
    x=(1:length(y))*ifi; % precise timing of flip from 0 to total experiment time
    trtimes=zeros(ceil(expdur/tr)+200,1);
    allt=zeros(length(y),1); % all possible flip times
    
    % set up isi
    n = 1E+4;
    R = exprnd(3.5,1,n);
    upperT = 7;
    lowerT = 3;
    Rbounded = R((R>=lowerT)&(R<=upperT));
    isi = Rbounded(randperm(numel(Rbounded),number_of_trials)); % stimulus presentation stamp
    switches =[0 isi+default_stimulus_duration+default_wait];
    switchesframe=round(isi / ifi); % convert them to frames
    
    %% Scanner setup
    % Set the trigger key
    %     scantr = 53; %22 check this
    scantrigger = [KbName('5%')];
    keytrigger = [KbName('t')]; % if not in scanner, press T to start experiment
    call_button = [KbName('4$')];
    
    if ~button_box
        buttonPresses = [KbName('f') KbName('j') KbName('q') ] ;
    else
        buttonPresses = [KbName('1!') KbName('2@') KbName('q')] ; %11 12 KB
    end
    
    manuallist = zeros(1, 256);
    manuallist([keytrigger]) = 1;
    
    buttonlist = zeros(1, 256);
    buttonlist([buttonPresses call_button]) = 1;
    
    triggerlist = zeros(1,256);
    triggerlist([scantrigger]) = 1;
    
    %% Initialize Eyetracking
    if get_eye
        
        el=EyelinkInitDefaults(window);%%returns values
        
        % Initialization of the connection with the Eyelink Gazetracker.
        % exit program if this fails.
        if ~EyelinkInit(0)
            fprintf('Eyelink Init aborted.\n');
            % Shutdown Eyelink:
            Eyelink('Shutdown');
            sca;
            return;
        end
        
        connected=Eyelink('IsConnected');%%Just to verify connection
        
        [v vs]=Eyelink('GetTrackerVersion');
        
        % open file to record data to
        tempeye = Eyelink('Openfile', edf_filename); %% looks odd
        if tempeye~=0
            printf('Cannot create EDF file ''%s'' ', edf_filename);
            Eyelink( 'Shutdown');
            return;
        end
        
        % Setting the proper recording resolution, proper calibration type,
        % as well as the data file content;
        Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, (windowRect(3)-1), (windowRect(4)-1)); % scr_r(3) = width; scr_r(4) = height
        Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, (windowRect(3)-1), (windowRect(4)-1));
        
        % set calibration type.
        Eyelink('command', 'calibration_type = HV5');
        
        %Eyelink('command', 'recording_parse_type = GAZE');%what does?
        Eyelink('command', 'saccade_acceleration_threshold = 8000');
        
        Eyelink('command', 'saccade_velocity_threshold = 30');
        Eyelink('command', 'saccade_motion_threshold = 0.0');
        
        Eyelink('command', 'saccade_pursuit_fixup = 60');
        Eyelink('command', 'fixation_update_interval = 0');%what does?
        
        % set EDF file contents
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS');
        
        % set link data (used for gaze cursor)
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS');
        
        % make sure we're still connected.
        if Eyelink('IsConnected')~=1
            Eyelink( 'Shutdown');
            return;
        end
        
        el.backgroundcolour = grey;% Bkcolor; % should I use the screen color here?
        el.calibrationtargetcolour = red; % try this
        %         el.foregroundcolour = [255,0,0]; % what does this color do?
        
        % call this function for changes to the calibration structure to take
        % affect
        EyelinkUpdateDefaults(el);
        
        Eyelink('Message', 'TRIAL_VAR_LABELS trial'); %aud vis for other study
        Eyelink('Message', 'V_TRIAL_GROUPING trial'); %aud vis for other study
        
        % Before recording, we place reference graphics on the host display
        % Must be offline to draw to EyeLink screen
        Eyelink('Command', 'set_idle_mode');
        % clear tracker display and draw box at fix point
        Eyelink('Command', 'clear_screen 0')
        %             Eyelink('command', 'draw_box %d %d %d %d 15', width/2-50, height/2-50, width/2+50, height/2+50);
        Eyelink('command', 'draw_box %d %d %d %d 15',eyerect(1), eyerect(2), eyerect(3), eyerect(4));
        
        Eyelink('Command', 'set_idle_mode');
        WaitSecs(0.01);%.05
        
        % Hide the mouse cursor;
        Screen('HideCursorHelper', window);
        
        % Calibrate the eye tracker
        EyelinkDoTrackerSetup(el);
        eye_used = Eyelink('EyeAvailable');
        
        % make sure we're still connected.
        if Eyelink('IsConnected')~=1
            Eyelink( 'Shutdown');
            return;
        end
    end
    
    %% set up the sounds
    eval(default_display); % fixation cross
    vbl = Screen('Flip', window);
    
    InitializePsychSound(1); %inidializes sound driver...
    device = [];
    
    fprintf('Preping sound \n');
    pahandle = PsychPortAudio('Open', device, 1, 1, [], 2, [], []); % opens sound buffer...requests high-precision timing and stereo
    
    % Get the real sampling rate we are using
    s = PsychPortAudio('GetStatus', pahandle);
    freq = s.SampleRate;
    
    startcue = 0; % start immediately
    
    % Scale the volume
    PsychPortAudio('Volume', pahandle, 0.9);
    
    if (strcmp(expType,'a'))
        % Make two beeps
        mylow = MakeBeep(350, 0.5, freq); % low beep
        myhigh = MakeBeep(700, 0.5, freq); % high beep
        
        % Fill the audio playback buffer with the audio data, doubled for stereo
        % presentation
        BufferLow = sprintf('PsychPortAudio(''FillBuffer'', pahandle, [mylow;mylow]);');
        BufferHigh = sprintf('PsychPortAudio(''FillBuffer'', pahandle, [myhigh;myhigh]);');
        
        % design sound matrix
        BufferTr = cell(1,number_of_trials);
        %     trmat=repmat([ones(1,round(number_of_trials.*.2)) zeros(1,number_of_trials-round(number_of_trials.*.2))]',1); % 0-nontarget; 1-target
        %     mixtr=trmat(randperm(length(trmat)),:); %randomize order
        mixtr= [ones(1,number_of_trials)];% currently only do one sound
        for m = 1:number_of_trials
            if (strcmp(hitaud,'h'))
                if  mixtr(m) == 0
                    BufferTr(m) = cellstr(BufferLow);
                else
                    BufferTr(m) = cellstr(BufferHigh);
                end
            else
                if  mixtr(m) == 0
                    BufferTr(m) = cellstr(BufferHigh);
                else
                    BufferTr(m) = cellstr(BufferLow);
                end
            end
        end
    end
    
    % set up wake-up calls
    wavfilename = strcat('alarmtrim.wav');
    
    % Read WAV file from filesystem:
    [y, freq] = psychwavread(wavfilename);
    wavedata = y';
    nrchannels = size(wavedata,1); % Number of rows == number of channels.
    
    % Make sure we have always 2 channels stereo output.
    if nrchannels < 2
        wavedata = [wavedata ; wavedata];
        nrchannels = 2;
    end
    
    % Fill the audio playback buffer with the audio data 'wavedata':
    BufferWakeup = sprintf('PsychPortAudio(''FillBuffer'', pahandle, wavedata);');
    
    %% set up images
    texr = repmat([1 zeros(1,number_of_trials-1)]',1);
    imgpresent = texr; % store the imgs
    
    % save the data to the desired file
    save(output_fname,'run_info','key_presses','trtimes','allt');
      
    %% New - get trigger (NAR version)

    KbQueueCreate(KB);
    KbQueueStart(KB);

%     KbTriggerWait(scantrigger, KB)

triggered = 0;
while ~triggered
    pause(0.005);
    [pressed,firstpress]=KbQueueCheck(KB);
    if pressed && ismember(scantrigger,find(firstpress))
        disp('got first trigger') ;
        triggered = 1;
        experiment_start_time = firstpress(scantrigger);
    end
end
% 
%     FlushEvents
%     [pressed, secs, keyCode] = KbCheck(-1);
%     while ~pressed
%         pause(0.005);
%         [pressed, secs, keyCode] = KbCheck(-1);
%         if pressed  %key is pressed
%             if keyCode(scantrigger)==1 %trigger
% %                 disp('triggered', keyCode(scantrigger))
% %                 key_presses(length(key_presses)+1).key = KbName(keyCode);
% %                 disp(secs)
%                 save(output_fname,'run_info','key_presses','trtimes','allt','switches','Accuracy','wake_call');
%             else
%                 pressed=0;
%             end
%         end
%     end
%     experiment_start_time=secs;       
        
    % start a log of commands
    log_fname = ['fmri_' subject_code '_log.txt'];
    diary(fullfile(fpath,log_fname));
    diary on;
    
    % If connected to UDP, send msg to server
    if udpsend == 1
        host='155.41.26.65';
        port='8080';
        
        udpsend=pnet('udpsocket',1111);
        
        try, % Failsafe
            pnet(udpsend,'write','Experiment_Start');     % Write to write buffer
            pnet(udpsend,'writepacket',host,port);   % Send buffer as UDP packet
        end
        
    end
    
    %     KbQueueRelease(KB);
    
    %% Start stimulus presentation
    %     KbQueueCreate(KB, buttonlist);
    %     KbQueueStart(KB);
    %
    trtimes(1)=experiment_start_time;
    prepframes = 1;
    fcnt = 0;
    trial = 1;
    
    if (strcmp(expType,'v'))
        eval(default_display); % fixation cross
        vbl = Screen('Flip', window);
        
        % Initial fixation period
        while (GetSecs - experiment_start_time < initialfix)
            WaitSecs(.001)
        end
        
        while (GetSecs - experiment_start_time) < expdur % in secs
            if trial < number_of_trials +1
                sprintf('run trial %1.0f',trial) % display run
                
                if get_eye
                    Eyelink('Message', 'TRIALID %d', trial);
                    % This supplies the title at the bottom of the eyetracker display
                    Eyelink('command', 'record_status_message "TRIAL %d"', trial);
                    %%%actually start recording, but not critical yet
                    Eyelink('StartRecording');
                end
                
                % This is the dot loop
                respMade = 0;
                frame = 0;
                switchTimedout = false;
                dotTimedout = false;
                respTimedout = false;
                
                % First we wait for the switchframes before the dot
                while ~switchTimedout,
                    frame = frame +1;
                    eval(default_display); % fixation cross
                    
                    FlushEvents
                    % check if we need to play wakeup call
                    [pressed, tWake, keyCode] = KbCheck(-1);
                    if pressed  %key is pressed
                        if keyCode(call_button)==1
                            eval(BufferWakeup);
                            tWake = PsychPortAudio('Start', pahandle, 1, 0, 0);
                            wake_call(length(wake_call)+1).time = tWake;
                        else
                            pressed=0;
                        end
                    end
                    
                    if frame > switchesframe(trial)
                        switchTimedout = true;
                        frame = 0;
                    end
                    
                    Screen('DrawingFinished', window);
                    [vbl,~]=Screen(window,'Flip',vbl+ifi*prepframes-ifi*0.5);
                    
                    if frame == 1
                        t1 = vbl;
                        if get_eye
                            % mark zero-plot time in data file, provide message
                            % to create a custom timewindow for so can get just
                            % the critical time period
                            %%%%%%%%%%%%%%%%%%%%
                            Eyelink('Message', 'SYNCTIME');
                        end
                        % If connected to UDP, send msg to server
                        if udpsend
                            udp=pnet('udpsocket',1111);
                            try,
                                pnet(udp,'write','Trial_Start');     % Write to write buffer
                                pnet(udp,'writepacket',host,port);   % Send buffer as UDP packet
                                
                            end
                            pnet(udp,'close');
                        end
                    end
                    fcnt=fcnt+1;
                    allt(fcnt) = vbl;
                end
                
                % Draw the dot
                % Present the dot for 500ms OR until resp
                % Wait for another 1500ms for resp OR present cross if already resp
                while ~respTimedout
                    frame = frame +1;
                    FlushEvents
                    %                 check if we need to play wakeup call
                    [pressed, tWake, keyCode] = KbCheck(-1);
                    if pressed  %key is pressed
                        if keyCode(call_button)==1
                            eval(BufferWakeup);
                            tWake = PsychPortAudio('Start', pahandle, 1, 0, 0);
                            wake_call(length(wake_call)+1).time = tWake;
                            pressed=0;
                        else
                            pressed=0;
                        end
                    end
                    
                    if frame > waitframes %if we exceeded 500ms and they haven't responded
                        dotTimedout = true;
                    end
                    
                    if frame > (waitframes+respframes-1) %if the 1.5+.5 has passed (time for next trial)
                        eval(default_display); % fixation cross
                        [vbl,~]=Screen(window,'Flip',vbl+ifi*prepframes-ifi*0.5);
                        fcnt=fcnt+1;
                        allt(fcnt) = vbl;
                        last_flip = vbl;
                        respTimedout = true;
                        frame = 0;
                    end
                    
                    if ~respMade && ~dotTimedout %%happens as soon as enter loop, put stim up
                        %                     Screen('FillOval', window , red, [xCenter-dotSizePix yCenter-dotSizePix xCenter+dotSizePix yCenter+dotSizePix]);
                        eval(square);
                    else
                        eval(default_display); % fixation cross
                    end
                    
                    [vbl,~]=Screen(window,'Flip',vbl+ifi*prepframes-ifi*0.5); %%will flip every time through loop
                    if frame == 1
                        if get_eye
                            Eyelink('Message', 'Stim ON');
                        end
                        
                        if udpsend
                            udp=pnet('udpsocket',1111)
                            try,
                                pnet(udp,'write','Stim_On');     % Write to write buffer
                                pnet(udp,'writepacket',host,port);   % Send buffer as UDP packet
                            end
                            pnet(udp,'close');
                        end
                        
                        tStart(trial) = vbl;
                        onset(trial) = tStart(trial);
                    end
                    
                    fcnt=fcnt+1;
                    allt(fcnt) = vbl;
                    
                    FlushEvents
                    [pressed, secs, keyCode] = KbCheck(-1);
                    if pressed  %key is pressed
                        if keyCode(call_button)==1
                            eval(BufferWakeup);
                            tWake = PsychPortAudio('Start', pahandle, 1, 0, 1);
                            wake_call(length(wake_call)+1).time = tWake;
                        elseif keyCode(buttonPresses(1))==1 || keyCode(buttonPresses(2))==1
                            if keyCode(buttonPresses(1))==1 %&& empty(key_presses.key{trial})
                                key_presses(length(key_presses)+1).key = KbName(buttonPresses(1));
                                key_presses(length(key_presses)).time = secs - onset(trial); % compare results with rt
                            elseif keyCode(buttonPresses(2))==1 %&& empty(key_presses.key{trial})
                                key_presses(length(key_presses)+1).key = KbName(buttonPresses(2));
                                key_presses(length(key_presses)).time = secs - onset(trial); % compare results with rt
                            end
                            key_presses(length(key_presses)).stimulus = 'square';
                            key_presses(length(key_presses)).trial = trial;
                            rtidx = find(ismember([key_presses.trial],trial));
                            rt(trial) = min([key_presses(rtidx).time]);
%                             sprintf('time since start: %1.0f s',GetSecs - experiment_start_time) % display experiment time for debug
                            duration(trial) = rt(trial);
                            trtimes(trial+1) = secs;
%                             Accuracy = Accuracy+1;
                            respMade = true;
                            if get_eye
                                Eyelink('Message', 'response');
                            end
                            if udpsend
                                udp=pnet('udpsocket',1111);
                                try, % Failsafe
                                    pnet(udp,'write','Response');     % Write to write buffer
                                    pnet(udp,'writepacket',host,port);   % Send buffer as UDP packet
                                    
                                end
                                pnet(udp,'close');
                            end
                            firstpress = 1;
                        end
                    else
                        pressed=0;
                    end
                end %%end of trial
                tTrial(trial) = last_flip - t1;
                
                if get_eye
                    % stop the recording of eye-movements for the current trial
                    Eyelink('StopRecording');
                    %interest area specific to the trial
                    Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 1, eyerect(1), eyerect(2), eyerect(3), eyerect(4),'fix');
                    %usually a count of the trial
                    Eyelink('Message', '!V TRIAL_VAR index %d', trial);
                    %%give it info about what group belongs to
                    
                    Eyelink('Message', '!V TRIAL_VAR type %s', 'trial'); %aud vis
                    Eyelink('Message', '!V TRIAL_VAR_DATA %s', 'trial'); %aud vis
                    % Sending a 'TRIAL_RESULT' message to mark the end of a trial in
                    % Data Viewer. This is different than the end of recording message
                    % END that is logged when the trial recording ends. The viewer will
                    % not parse any messages, events, or samples that exist in the data
                    % file after this message. Can use as the end
                    % message for a custom time window in data viewer
                    Eyelink('Message', 'TRIAL_RESULT 0')
                end
                % Move on to the next trial
                trial = trial+1;
                save(output_fname,'run_info','key_presses','trtimes','allt','switches','Accuracy','wake_call');
            end
        end %%end of experiment
        
        %update key info to save
        run_info.onsets=onset;
        run_info.durations=duration;
        run_info.responses=resp;
        run_info.rts=rt;
        run_info.tStarts = tStart;
        run_info.imgpresents = imgpresent;
        run_info.tTrials = tTrial;
        
        if get_eye
            Eyelink('Command', 'set_idle_mode');
            Eyelink('CloseFile');
            try
                fprintf('Receiving data file ''%s''\n', edf_filename );
                status=Eyelink('ReceiveFile');
                if status > 0
                    fprintf('ReceiveFile status %d\n', status);
                end
                if 2==exist(edf_filename, 'file')
                    dataFileName=[subject_code, '_',experiment_code,'_',experiment_type,'.edf'];
                    inputFullFileName = fullfile(pwd, edf_filename);
                    outputFullFileName = fullfile(pwd, dataFileName);
                    copyfile(inputFullFileName, outputFullFileName);
                    
                    fprintf('Data file ''%s'' can be found in ''%s''\n', dataFileName, pwd );
                end
                Eyelink('ShutDown');
                
            catch
                fprintf('Problem receiving data file ''%s''\n', edf_filename );
            end
        end
        
    elseif (strcmp(expType,'a'))
        eval(default_display); % fixation cross
        vbl = Screen('Flip', window);
        
        % Initial fixation period
        while (GetSecs - experiment_start_time < initialfix)
            WaitSecs(.001)
        end
        
        while (GetSecs - experiment_start_time) < expdur % in secs
            if trial < number_of_trials +1
                sprintf('run trial %1.0f',trial) % display run
                
                if get_eye
                    Eyelink('Message', 'TRIALID %d', trial);
                    % This supplies the title at the bottom of the eyetracker display
                    Eyelink('command', 'record_status_message "TRIAL %d"', trial);
                    %%%actually start recording, but not critical yet
                    Eyelink('StartRecording');
                end
                
                % This is the beep loop
                respMade = 0;
                frame = 0;
                switchTimedout = false;
                imgTimedout = false;
                respTimedout = false;
                
                % First we wait for the switchframes before sound ON
                while ~switchTimedout,
                    frame = frame +1;
                    FlushEvents
                    % check if we need to play wakeup call
                    [pressed, tWake, keyCode] = KbCheck(-1);
                    if pressed  %key is pressed
                        if keyCode(call_button)==1
                            eval(BufferWakeup);
                            tWake = PsychPortAudio('Start', pahandle, 1, 0, 1);
                            wake_call(length(wake_call)+1).time = tWake;pressed=0;
                        else
                            pressed=0;
                        end
                    end
                    
                    
                    if frame > switchesframe(trial)
                        switchTimedout = true;
                        frame = 0;
                    end
                    
                    if frame > waitframes
                        imgTimedout = true;
                        eval(default_display); % fixation cross
                    end
                    
                    if(~imgTimedout)
                        if imgpresent(trial) == 1
                            eval(square);
                        else
                            eval(default_display); % fixation cross
                        end
                    end
                    [vbl,~]=Screen(window,'Flip',vbl+ifi*prepframes-ifi*0.5);
                    Screen('DrawingFinished', window);
                    
                    if frame == 1
                        t1 = vbl;
                        if get_eye
                            % mark zero-plot time in data file, provide message
                            % to create a custom timewindow for so can get just
                            % the critical time period
                            %%%%%%%%%%%%%%%%%%%%
                            Eyelink('Message', 'SYNCTIME');
                        end
                    end
                    fcnt=fcnt+1;
                    allt(fcnt) = vbl;
                end
                
%                 KbQueueFlush(KB); %Flushes Buffer so only response after stimonset are recorded
                
                while ~respTimedout,
                    % Play sound and wait 1500ms for resp
                    frame = frame +1;
                    eval(default_display); % fixation cross
                    FlushEvents
                    % check if we need to play wakeup call
                    [pressed, tWake, keyCode] = KbCheck(-1);
                    if pressed  %key is pressed
                        if keyCode(call_button)==1
                            eval(BufferWakeup);
                            tWake = PsychPortAudio('Start', pahandle, 1, 0, 1);
                            wake_call(length(wake_call)+1).time = tWake;pressed=0;
                        else
                            pressed=0;
                        end
                    end
                    
                    if frame == 1
                        frame = frame - .03;
                        [vbl1,visonset1]=Screen(window,'Flip',vbl+ifi*prepframes-ifi*0.85);%triggers start of audio
                        % Compute tWhen onset time for wanted visual onset at >= tWhen:
                        tWhen = vbl1 + (prepframes - 0.85) * ifi;
                        fcnt=fcnt+1;
                        allt(fcnt) = vbl1;
                        tPredictedVisualOnset = PredictVisualOnsetForTime(window, tWhen);
                        eval(char(BufferTr(trial)));
                        PsychPortAudio('Start', pahandle, 1, tPredictedVisualOnset, 0);
                        eval(default_display);
                        % Ok, the next flip will do a visual flip
                        [vbl visual_onset t] = Screen('Flip', window, tWhen);
%                         Screen('DrawingFinished', window);
                        fcnt=fcnt+1;
                        allt(fcnt) = vbl;
                        tStart(trial) = tWhen;
                        if get_eye
                            Eyelink('Message', 'Sound_ON');
                        end
                        onset(trial) = tStart(trial);
                        frame = frame +1;
                        
                    else
                        [vbl,~]=Screen(window,'Flip',vbl+ifi*prepframes-ifi*0.5);
                        fcnt=fcnt+1;
                        allt(fcnt) = vbl;
                        Screen('DrawingFinished', window);
                    end
                    
                    if frame > (waitframes+respframes-1) % respframes
                        eval(default_display); % fixation cross
                        [vbl,~]=Screen(window,'Flip',vbl+ifi*prepframes-ifi*0.5);
                        fcnt=fcnt+1;
                        allt(fcnt) = vbl;
                        last_flip = vbl;
                        tTrial(trial) = last_flip - t1;
                        respTimedout = true;
                        frame = 0;
                    end
                    
%                     if(~respMade)
                        FlushEvents
                        [pressed, secs, keyCode] = KbCheck(-1);
                        if pressed  %key is pressed
                            if keyCode(call_button)==1
                                eval(BufferWakeup);
                                tWake = PsychPortAudio('Start', pahandle, 1, 0, 1);
                                wake_call(length(wake_call)+1).time = tWake;
                            elseif keyCode(buttonPresses(1))==1 || keyCode(buttonPresses(2))==1
                                if keyCode(buttonPresses(1))==1 %&& empty(key_presses.key{trial}
                                    key_presses(length(key_presses)+1).key = KbName(buttonPresses(1));
                                    key_presses(length(key_presses)).time = secs - onset(trial); % compare results with rt
                                elseif keyCode(buttonPresses(2))==1 %&& empty(key_presses.key{trial})
                                    key_presses(length(key_presses)+1).key = KbName(buttonPresses(2));
                                    key_presses(length(key_presses)).time = secs - onset(trial); % compare results with rt
                                end
                                key_presses(length(key_presses)).stimulus = BufferTr(trial);
                                key_presses(length(key_presses)).trial = trial;
                                rtidx = find(ismember([key_presses.trial],trial));
                                rt(trial) = min([key_presses(rtidx).time]);
                                sprintf('time since start: %1.0f s',GetSecs - experiment_start_time) % display experiment time for debug
                                duration(trial) = rt(trial);
                                %                             resp(length(resp)+1) =  cell(keyCode(buttonPresses(1)));
                                trtimes(trial+1) = secs;
%                                 Accuracy = Accuracy+1;  
                                respMade = true;
                                if get_eye
                                    Eyelink('Message', 'response');
                                end
                                firstpress = 1;
                            end
                        else
                            pressed=0;
                        end
                    end
                    
                if get_eye
                    % stop the recording of eye-movements for the current trial
                    Eyelink('StopRecording');
                    %interest area specific to the trial
                    Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 1, eyerect(1), eyerect(2), eyerect(3), eyerect(4),'fix');
                    %usually a count of the trial
                    Eyelink('Message', '!V TRIAL_VAR index %d', trial);
                    %%give it info about what group belongs to
                    
                    Eyelink('Message', '!V TRIAL_VAR type %s', 'trial'); %aud vis
                    Eyelink('Message', '!V TRIAL_VAR_DATA %s', 'trial'); %aud vis
                    % Sending a 'TRIAL_RESULT' message to mark the end of a trial in
                    % Data Viewer. This is different than the end of recording message
                    % END that is logged when the trial recording ends. The viewer will
                    % not parse any messages, events, or samples that exist in the data
                    % file after this message. Can use as the end
                    % message for a custom time window in data viewer
                    Eyelink('Message', 'TRIAL_RESULT 0')
                end
                % Move on to the next trial
                trial = trial+1;
                save(output_fname,'run_info','key_presses','trtimes','allt','switches','Accuracy','wake_call')
            end
        end
            
            if get_eye
                Eyelink('Command', 'set_idle_mode');
                Eyelink('CloseFile');
                try
                    fprintf('Receiving data file ''%s''\n', edf_filename );
                    status=Eyelink('ReceiveFile');
                    if status > 0
                        fprintf('ReceiveFile status %d\n', status);
                    end
                    if 2==exist(edf_filename, 'file')
                        dataFileName=[subject_code, '_',experiment_code,'_',experiment_type,'.edf'];
                        inputFullFileName = fullfile(pwd, edf_filename);
                        outputFullFileName = fullfile(pwd, dataFileName);
                        copyfile(inputFullFileName, outputFullFileName);
                        
                        fprintf('Data file ''%s'' can be found in ''%s''\n', dataFileName, pwd );
                    end
                    Eyelink('ShutDown');
                    
                catch
                    fprintf('Problem receiving data file ''%s''\n', edf_filename );
                end
            end
            %update key info to save
            run_info.onsets=onset;
            run_info.durations=duration;
            run_info.responses=resp;
            run_info.rts=rt;
            run_info.tStarts = tStart;
            run_info.imgpresents = imgpresent;
            run_info.tTrials = tTrial;
        end
        
        % display mean RT and accuracy
        Accuracy = length(unique([key_presses.trial]));
        fprintf('The mean reaction time is %f seconds\n', mean(nonzeros(run_info.rts)))
        fprintf('Accuracy is %0.8f %% \n', 100* (Accuracy / length(nonzeros(run_info.tStarts))))
        
        while (GetSecs - experiment_start_time < maxTime )
            %         WaitSecs(.001)
            instructString = 'You''re finished! Thank you.';
            DrawFormattedText_new(window,instructString, 'center','center', red, default_wrap,0,0);
            [vbl,~]=Screen('Flip',window,vbl+ifi*prepframes-ifi*0.5);
        end
        
        allt = allt;
        
        
        %% Wrap up and save
        fprintf('The experiment lasted %f seconds\n',GetSecs-experiment_start_time)
        
        % save the data to the desired file
        save(output_fname,'run_info','key_presses','trtimes','allt','switches','Accuracy','wake_call');
        
        
        m = mfilename('fullpath');
        % system(['copy ' m ' .m'  output_mname])
        m = sprintf('%s.m',m);
        copyfile(m, output_mname, 'f')
        
        
        % KbQueueRelease(KB);
        PsychPortAudio('Close');
        ShowCursor;
        Priority(0);
        Screen('CloseAll');
        if udpsend == 1
            pnet(udp,'close');
        end
catch myerr
            myerr.message
            myerr.stack.line
            %% Wrap up and save when error occurs
            
            % save the data to the desired file
            save(output_fname,'run_info','key_presses','trtimes','allt','switches','Accuracy','wake_call');
            
            if get_eye
                Eyelink('StopRecording');
                Eyelink('CloseFile');
                Eyelink('ShutDown');
            end
            
            if udpsend == 1
                pnet(udp,'close');
            end
            
            m = mfilename('fullpath');
            % system(['copy ' m ' .m'  output_mname])
            m = sprintf('%s.m',m);
            copyfile(m, output_mname, 'f')
            
            % KbQueueRelease(KB);
            ShowCursor;
            Priority(0);
            Screen('CloseAll');
            PsychPortAudio('Close');
end
    diary off;
end












