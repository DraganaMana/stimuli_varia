%
%   Emotion matching task modeled on modified vers. of Hariri Emotion task
%   by Steph, July 2021 
%   


%   V2 -  1.16.2021 - iti 5-10s 
%   V3 -  1.17.2021 using new stimuli sets 
%   V3.1 -  added try/catch sections
%   v3.2 - shorter isis. fear only 
%   EyeEmotMatchV3 -- ONLY USING CONDITIONS CB1 and CB3 - so cond is either 1 or 2 +
%   new path to the conditions folder condv2
%     V4 new conditions in folder condv3


% Format of Task: 
%  8 blocks of 6 trials, w trials jittered within a block
%       A 3-s cue at beginning of block indicates whether it is a FACE or SHAPE block
%       2 pictures appear for 4 s, and subj responds w button to say which matches
%       picture at the top of the screen
%       v2= updated after discussion w laura: 5-10s second ITI between trials 
%  v3 = 2-6 s ITI

% Sources used during writing: 
%  (1) Stanford-PsychToolbox example on github author-K. Katovich
%  (2) HCP EMOTION Task python code-- which is a modified Hariri Emotion Matching Task
%  (3) pieces of laura's old code
%  (4) Peter Scarf online PTB demos
%  (5) RADIATE face stimuli (B.J.Casey@yale)
%  (6) Chicago Face Database (Uchicago)
%   
% Stimuli images are now taken from 1) BJ Casey's RADIATE set, 2) UChicago's
% FACE stim set (both are racially diverse) -needed many images so had to draw across two sets 

% TOTAL TIME:  360 
 

function [acc] = EyeEmotMatchV5(counterbalancing,get_eye)
%"counterbalancing" is a number ( 1, 2, or 3 ) referencing which
%counterbalanced paradigm to run
%Screen('Preference', 'SkipSyncTests', 1)
Screen('Preference', 'SkipSyncTests', 1)
try 
KbName('UnifyKeyNames')
%Screen('Preference', 'SkipSyncTests', 1);
% if counterbalancing ==1
%     shapes = 1 ;  %CHANGE THIS FOR piloting boolean yes or no  -neutral condition
% else 
%     shapes = 0; 
% end 

rkeyvalesp = []; 
basepath='/home/lewislab/stimuli/stephanie/depression_taskfinal';

%DONT FORGET TO CHANGE EDF filename
edf_filename = 'amygseq07082021_run1.edf';


%'/Users/sdwilli/depression_taskfinal';  %ONLY PATH TO CHANGEF
%set paths
data.images_path_name = [ basepath '/imagesv3/newstim/'];
data.data_path_name =[ basepath  '/data/' ];
fpath=data.data_path_name; %'/home/lewislab/stimuli/stephanie/';
c=clock;
fname=sprintf('%smood13_EmotMatch_%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.mat',fpath,c);
mname=sprintf('%smood13_EmotMatch_%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.m',fpath,c);
dotsize=14;

%% set up trigger keys
trigger = KbName('5%'); 
buttonPresses = [KbName('1!') KbName('2@') ] ; %11 12 KB
tr=0.246; %shorter than actual so that we overshoot and dont run out of space
keylist = zeros(1, 256); 
keylist([buttonPresses]) = 1; 
triggerlist = zeros(1,256); 
triggerlist(trigger) = 1; 
[i j]=GetKeyboardIndices;
KB=i(find(strcmp(j,'Current Designs, Inc. 932'))) %for sys76 when connected 2 scanner
%KB=i(find(strcmp(j, 'Apple Internal Keyboard / Trackpad'))) %for mac
%KB = i(find(strcmp(j,'AT Translated Set 2 keyboard'))); %for sys76 when not connected 2 scanner
%% set up screens 
screens = Screen('Screens');
whichScreen = max(screens);
%[window,windowRect] = Screen(whichScreen, 'OpenWindow',[],[0 0 300 200]);
[window,windowRect] = Screen(whichScreen, 'OpenWindow');
topPriorityLevel = MaxPriority(window);
disp(topPriorityLevel)
disp('PRIORITY')
Priority(topPriorityLevel);
measifi = Screen('GetFlipInterval', window);
disp(measifi)
isisf=measifi;
Priority(0);

% get screen position info
dual=get(0,'MonitorPositions');
resolution = [0,0,dual(1,3),dual(1,4)];
data.screenX = resolution(3);
data.screenY = resolution(4);

%set up degrees of visual angle for eyetracker window of interest
% Get the screen parameters
center = [windowRect(3)  windowRect(4)]/2;
    
    % Draw the fixation plus according to the screen setup
    p.v_dist 		= 99;	%viewing distance behavioral: 60(cm)/99
    p.mon_width  	= 42.7;	%horizontal dimension of viewable Screen (cm)/ 42.7

%set up pixesl per degree
    pix_per_deg = pi * windowRect(3) / atan(p.mon_width/p.v_dist/2) / 360;	% pixels per degree
%%discrimination box
    eyesize=3.5;% in degrees
    eyesize=eyesize*pix_per_deg;
    
    eyerect=round([center-.5*eyesize, center+.5*eyesize]);
%% make colours and plot gray
owhite = WhiteIndex(window); % pixel value for white
maxlum = 0.9;
minlum = 0; 
white=owhite*maxlum;
black = BlackIndex(window); % pixel value for black
black=black+owhite*minlum;
%Screen(window, 'FillRect',mean([white black])); %CHANGED
Screen(window, 'FillRect', white);
%% trial design 
%conditions = {'CB1', 'CB3V2'}; %no longer using CB2 - this had neutral face condition  
conditions = {'CB1', 'CB2', 'CB3', 'CB4', 'CB5', 'CB6', 'CB7' }; %no longer using CB2 - this had neutral face condition  

DrawFormattedText(window, 'Loading experiment, please be patient'  ,...
            'center', 'center', black);
        Screen('Flip',window);

%% set trial info 
trialinfo= readtable([basepath '/condv3/' conditions{counterbalancing} '.xlsx']); 
data.topimgname= trialinfo(:,2);
data.leftimgname=  trialinfo(:,3);
data.rightimgname =  trialinfo(:,4);
data.corranswer=  trialinfo(:,5);

%% preload all images **very important to preload so don't run into timing issues
top_textures = {};
left_textures = {};
right_textures = {};

for i = 1:size(data.topimgname,1)
        disp(i)
        topimg = imread([ data.images_path_name char(data.topimgname{i,1}) ] );
        leftimg = imread([ data.images_path_name char(data.leftimgname{i,1}) ] );
        rightimg = imread([ data.images_path_name char(data.rightimgname{i,1}) ] );

        %  creating the pointer to the image in memory
        tex_top = Screen('MakeTexture',window,topimg);
        tex_left = Screen('MakeTexture',window,leftimg);
        tex_right = Screen('MakeTexture',window,rightimg);

        %  add the pointer to our image_textures cell array:
        top_textures{i} = tex_top;
        left_textures{i} = tex_left;
        right_textures{i} = tex_right;

end 

%% Position of images 

baseRect = [0 0 240 200]; %[0 0 112 112];
dstRects = nan(4,3);
Nshift = 120 ;  %  %90; 
dstRects(:, 1) = CenterRectOnPointd(baseRect, windowRect(3)/2, (windowRect(4)/2)-Nshift); % top
dstRects(:, 2) = CenterRectOnPointd(baseRect, (windowRect(3)/2) - (Nshift + 50), (windowRect(4)/2) + Nshift) ; % left 
dstRects(:, 3) = CenterRectOnPointd(baseRect, (windowRect(3)/2) + (Nshift + 50), (windowRect(4)/2) + Nshift) ; % right 


%% timing 
data.picture_onsets = [];
display_duration = 4.0; %updated duration time 
isiF = [ 2 2 6 6 4 4 ] ;
isiS = [ 2 2 2 2 2 2 ]; 
orderisi = isiF(randperm(size(isiF,2))); 
isiL = repmat([ orderisi isiS],1, 6); % switched this in version 4 5 is > numblocks/2
%isiL = [6.11885202348521 , 6.86781903821322 , 5.43750174788293 , 8.20058274123358 , 5.90308443876554 , 5.22525553736787 , 8.61586739591548 , 6.73718822790895 , 8.30308412251452 , 6.91934300535986 , 8.13673251221734 , 5.10824907315153 , 9.55284994261514 , 9.00279328139406 , 8.72923742171361 , 9.06556406805380 , 6.91653159312765 , 8.08639616158225 , 7.87747429851407 , 7.65025852382508 , 6.37534877910968 , 6.24314479830985 , 7.25819385225986 , 6.13856413013274 , 9.02224791806535 , 9.93052120947985 , 5.14995975134695 , 7.67832095333619 , 5.43538609950446 , 9.01045720277902 , 9.94572454850170 , 5.33473129198875 , 9.69699180942267 , 5.09088766818348 , 8.41919306873178 , 8.91868240041609 ,  6.8970] ; 
%total isiL time = 275 seconds 
%ffset=10; % time in seconds before stim start

stimonset = zeros(1,100); 
%isiL=unifrnd(5,10,37,1); %ITI 5-10 seconds - command used to get isiLs
isiTimeFrames =  ceil(isiL/isisf); % ISI = 1 second 
cueFrames = ceil(3/isisf); % CUE on screen for 3 seconds 
trialdurFrames =  ceil(display_duration/isisf); %trials last 4 seconds


%Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize,dotcol*dotlum(i),[0 0],2);
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

        el.backgroundcolour = white;% Bkcolor; % should I use the screen color here?
        el.calibrationtargetcolour = black; % try this
        
        % call this function for changes to the calibration structure to take
        % affect
        EyelinkUpdateDefaults(el);
        
        Eyelink('Message', 'TRIAL_VAR_LABELS trial face shap'); %aud vis for other study
        Eyelink('Message', 'V_TRIAL_GROUPING trial face shap'); %aud vis for other study
        eyeconditions=['face';'shap'];
        
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






disp('made it to line 155')
%% starting experiment 
ds=1;
ifi = Screen('GetFlipInterval', window);

KbQueueCreate(KB, triggerlist);
KbQueueStart(KB);

expdur=500; %overshooting
trtimes=zeros(ceil(expdur/tr)+200,1);
keyval=zeros(size(trtimes));

DrawFormattedText(window, 'Get Ready!' ,...
            'center', 'center', black);
        
% line up first= stim image
Screen('Flip',window);
DrawFormattedText(window,'+', 'center', 'center');

%[windowRect(3)/2 windowRect(4)/2],225);
%Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize,dotcol*dotlum(i),[0 0],2);
HideCursor;
allt=zeros(30000,1);
frametype=zeros(30000,1);

Priority(topPriorityLevel); 
disp('topPriorityLevel') 
disp('prior')

%wait for first scanner trigger 
pressed=0;
while ~pressed
    pause(0.005);
    [pressed, firstpress]=KbQueueCheck(KB);
    disp(pressed)
end

tic
ts=firstpress(trigger);
disp(['Starting time ' num2str(ts) ])
KbQueueRelease(KB);


%only look for keypresses
KbQueueCreate(KB, keylist);
KbQueueStart(KB);
allt(1)=ts;

indx=2;
resptimes=zeros(1,100); 
%resptimes(1)=ts;
%start
ts=Screen('Flip',window);
waitframes = 1;
framecounter=1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%main loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
responsecorr = zeros(1,50); 
respsec = zeros(1,50);
blockonset = zeros(1,50); 
acc=0; 
% if respsec(41)==0
%     disp('sending error to test catch statement')
% end 
numTrials=6; 
numBlocks=8; %change back to 8 before running 
trialcounter=0;

%start recording here? - SW 

%    if get_eye
%                Eyelink('Message', 'TRIALID %d', trial);
%                % This supplies the title at the bottom of the eyetracker display
%                Eyelink('command', 'record_status_message "TRIAL %d"', trial);
%                %%%actually start recording, but not critical yet
%                Eyelink('StartRecording');
%            end


% 
% if get_eye
%                         % mark zero-plot time in data file, provide message
%                         % to create a custom timewindow for so can get just
%                         % the critical time period
%                         %%%%%%%%%%%%%%%%%%%%
%                         Eyelink('Message', 'SYNCTIME');
%                     end



%%

shapes=1;
for bl = 1:numBlocks
    
    
    if ismember(bl, [1 3 5 7])
        
            msg = 'Match Faces';
            isface=1;


    else 
        msg = 'Match Shapes'; 
        isface=0;
    end 
    
   if get_eye
               Eyelink('Message', 'BLOCKID %d', bl);
               % This supplies the title at the bottom of the eyetracker display
               Eyelink('command', 'record_status_message "BLOCK %d"', bl);
               %%%actually start recording, but not critical yet
               Eyelink('StartRecording');
           end  

    %--------------------------------------------------------
    % 6 TRIALS  - main loop
    %--------------------------------------------------------
     
    for tr = 1:numTrials
       
        
        
        trialcounter=trialcounter+1; 
        
        %save which keypress is correct for this trial 
        if strcmp(data.corranswer{trialcounter,1}, 'left')
            keyvalcorr=buttonPresses(1);
        else
            keyvalcorr=buttonPresses(2); 
        end 

    %--------------------------------------------------------
    % 3 second cue period that specifies block type (face or shape)
    %--------------------------------------------------------

        if tr==1
        for frame = 1:cueFrames - 1
            DrawFormattedText(window, msg ,...
            'center', 'center', black);
            [ts,~]=Screen(window,'Flip',ts+ifi*waitframes-ifi*0.5);
            framecounter=framecounter+1; 
            allt(framecounter) = ts; 
            frametype(framecounter) = -1;
            if frame ==1
                blockonset(bl) = ts; 
                if get_eye
                        % mark zero-plot time in data file, provide message
                        % to create a custom timewindow for so can get just
                        % the critical time period
                        %%%%%%%%%%%%%%%%%%%%
                        Eyelink('Message', 'SYNCTIME');
                    end
            end 
        end 
        end 
        
        
        
    %--------------------------------------------------------
    % Stimulus ON
    %--------------------------------------------------------
     for frame = 1:trialdurFrames - 1
         Screen('DrawTexture', window, top_textures{trialcounter}, [], dstRects(:,1));
         Screen('DrawTexture', window, left_textures{trialcounter}, [], dstRects(:,2));
         Screen('DrawTexture', window, right_textures{trialcounter}, [], dstRects(:,3));
         DrawFormattedText(window,'+','center','center', black);
         [ts,~]=Screen(window,'Flip',ts+ifi*waitframes-ifi*0.5); % next stim comes 
         framecounter=framecounter+1; 
         allt(framecounter) = ts;
         frametype(framecounter) = 1; 
         if frame==1
             stimonset(trialcounter) = ts;
             if get_eye
                        Eyelink('Message', 'Stim ON');
                        Eyelink('Message', 'Block %d Stim %d', bl, tr);
                        totaltrialcount=(bl-1)*numTrials+tr;
                        
                        Eyelink('command', 'record_status_message "Block %d Stim %d"', bl, tr);
                    end 
         end 

         [pressed,firstpress]=KbQueueCheck(KB);
        if pressed
            k=find(firstpress);
            for j=1:length(k)
                keyval(indx)=k(j);
                %disp(['keyval ' num2str(keyval) ])
                %check if correct
                if  keyvalcorr==k(j)
                    responsecorr(trialcounter)=1; 
                else
                    responsecorr(trialcounter)=0; 
                end 
                if respsec(trialcounter)==0   
                    resptimes(indx)=firstpress(k(j)); %keep track all button press in case several 
                    respsec(trialcounter) =firstpress(k(j)) -  stimonset(trialcounter); % keep track first only 
                    indx=indx+1;
                end 
            end
        end      
        
    
     end 
    if get_eye
                        Eyelink('Message', 'Stim OFF');
    end
        
    %--------------------------------------------------------
    %  ITI + check for responses (just in case)
    %--------------------------------------------------------
        
    for frame = 1:isiTimeFrames(trialcounter) - 1
            % Draw the fixation point
            %Screen('DrawDots', window, [xCenter; yCenter], 10, black, [], 2);
            DrawFormattedText(window,'+','center','center', black);
            % Flip to the screen
            [ts, ~] = Screen('Flip', window, ts + (waitframes - 0.5) * ifi);
            framecounter=framecounter+1; 
            allt(framecounter) = ts;
            frametype(framecounter) = 2; 

        [pressed,firstpress]=KbQueueCheck(KB);
        if pressed
            k=find(firstpress);
            for j=1:length(k)
                keyval(indx)=k(j);
                resptimes(indx)=firstpress(k(j));
                indx=indx+1;
            end
        end        
            
     end
     


    end 
    if get_eye
            % stop the recording of eye-movements for the current trial
            Eyelink('StopRecording');
            %interest area specific to the trial
            Eyelink('Message', '!V IAREA RECTANGLE %d %d %d %d %d %s', 1, eyerect(1), eyerect(2), eyerect(3), eyerect(4),'fix');
            %usually a count of the trial
            Eyelink('Message', '!V TRIAL_VAR index %d', bl);
            %%give it info about what group belongs to
            
            Eyelink('Message', '!V TRIAL_VAR type %s', eyeconditions(isface+1,:)); %
            Eyelink('Message', '!V TRIAL_VAR_DATA %s', eyeconditions(isface+1,:)); %
            % Sending a 'TRIAL_RESULT' message to mark the end of a trial in
            % Data Viewer. This is different than the end of recording message
            % END that is logged when the trial recording ends. The viewer will
            % not parse any messages, events, or samples that exist in the data
            % file after this message. Can use as the end
            % message for a custom time window in data viewer
            Eyelink('Message', 'TRIAL_RESULT 0')
        end
acc = sum(responsecorr)/48; 
end 

ShowCursor;
Priority(0);
Screen('CloseAll');
save(fname,'allt','data','counterbalancing','resptimes', 'responsecorr', 'keyval', 'isiL', 'frametype', 'acc', 'stimonset', 'respsec');
m=mfilename('fullpath');
system(['cp ' m '.m ' mname]);
KbQueueRelease(KB);

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
                dataFileName=sprintf('%sEmotMatch_SW_%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.edf',fpath,c);
                
                inputFullFileName = fullfile(pwd, edf_filename);
                %outputFullFileName = fullfile(pwd, dataFileName);
                copyfile(inputFullFileName, dataFileName);

                fprintf('Data file can be found in ''%s''\n', dataFileName );
            end
            Eyelink('ShutDown');

        catch
            fprintf('Problem receiving data file ''%s''\n', edf_filename );
        end

    Eyelink('ShutDown');
    end
toc
catch
    rethrow(lasterror);
    allt=0;
    ShowCursor;
    Priority(0);
    Screen('CloseAll');
    fname=sprintf('%sERROREDOUT_EmotMatch_SW_%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.mat',fpath,c);
    save(fname,'allt','data','counterbalancing','resptimes', 'responsecorr', 'keyval', 'isiL', 'frametype', 'acc', 'stimonset', 'respsec');
    m=mfilename('fullpath');
    system(['cp ' m '.m ' mname]);
    KbQueueRelease(KB);
    if get_eye
               if Eyelink('IsConnected')==1

        Eyelink('Command', 'set_idle_mode');
        Eyelink('CloseFile');
        try
            fprintf('Receiving data file ''%s''\n', edf_filename );
            status=Eyelink('ReceiveFile');
            if status > 0
                fprintf('ReceiveFile status %d\n', status);
            end
            if 2==exist(edf_filename, 'file')
                dataFileName=sprintf('%sEmotMatch_SW_%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.edf',fpath,c);
                
                inputFullFileName = fullfile(pwd, edf_filename);
                %outputFullFileName = fullfile(pwd, dataFileName);
                copyfile(inputFullFileName, dataFileName);

                fprintf('Data file can be found in ''%s''\n', dataFileName );
            end
            Eyelink('ShutDown');

        catch
            fprintf('Problem receiving data file ''%s''\n', edf_filename );
        end
        
    Eyelink('StopRecording');
    Eyelink('CloseFile');
    Eyelink('ShutDown');

               end
    end

end 

