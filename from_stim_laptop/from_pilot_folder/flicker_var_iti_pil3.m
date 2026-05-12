% checkerboard with kbqueue integrated. Red dot changes luminance.
% flicker is a numerical input (ex. 12) for flicker frequency in Hz
% contrast determines a high(h) and low (l) contrast version

%example call
% flicker_var_iti(12,'h', 0);

function [allt,y,trtimes,keyval]= flicker_var_iti_pil3(flicker,contrast, scanner)
Screen('Preference', 'SkipSyncTests', 1)

try 
KbName('UnifyKeyNames')
fpath='/home/lewislab/stimuli/logfiles/';
c=clock;
fname=sprintf(['%spilot' contrast '_SW_vZ%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.mat'],fpath,c);
mname=sprintf(['%spilot' contrast '_SW_vZ%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.m'],fpath,c);
bname=sprintf(['%spilot' contrast '_SW_vZ%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.mat'],fpath,c);

%keyindex=22;
trigger = KbName('+');
keyindex=trigger;
buttonPresses = [KbName('1!') KbName('2@') KbName('3#') KbName('4$') ] ; %11 12 KB
tr=0.378;
keylist = zeros(1, 256); 
keylist([buttonPresses]) = 1; 
triggerlist = zeros(1,256); 
triggerlist(trigger) = 1; 
[i j]=GetKeyboardIndices;

if scanner
KB=i(find(strcmp(j,'Current Designs, Inc. 932'))); %% CHANGE THIS FOR BU  DESIGNS %% CORRECT FOR BU SCANNER
expdur=196; % 339; 
else
 KB=i(find(strcmp(j,'AT Translated Set 2 keyboard')));
expdur = 40;
%%'P. I. Engineering Xkeys'))) %% CHANGE THIS  'P.I. Engineering Xkeys'
end
% KB = i(10);

dotsize=14;
allflicker=[0.5 1 2 4 8 12 20 30 40 50]; 
blockdur=16;

if (contrast=='h')
    maxlum=0.9; %normal/standard contrast
elseif (contrast == 'm')
    maxlum=0.81; %decreases constrast by 10%
elseif (contrast == 'l')
    maxlum=0.45; %decreases contrast by 20%
end 
minlum=0;
disp('made it to line 51')

%%
% set up screen
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
Priority(0);

%% make colours and plot gray
owhite = WhiteIndex(window); % pixel value for white
white=owhite*maxlum;
black = BlackIndex(window); % pixel value for black
black=black+owhite*minlum;
Screen(window, 'FillRect',mean([white black]));

%% make checkerboard

imsize=2000;
l=linspace(-1,1,imsize);
[x,y] = meshgrid(l,l);

spacing_radial=6;
spacing_concentric=10;

I_radial= sin( ((((sqrt(x.^2+y.^2).^0.3)*2*pi)+0)*spacing_radial) );
I_concentric = sin( atan2(x,y)*spacing_concentric );

checks=sign(I_radial).*sign(I_concentric);
checks=(checks+1)/2;
checks=checks*(white-black)+black;

% delete middle
%radsize=0.0003;
%checks((x.^2+y.^2)<radsize)=0;

%% add jitter
gapdur=30; 
allstim=[192 192 192 192 192 192 192]; % units: number of inversions of 12 Hz flicker (ninversion*12 = 16 s) 
% randomize order and jitter
presentstim=allstim(randperm(length(allstim)));
maxjitter=2.5;
jitter=randi(maxjitter*60*2,size(allstim))-maxjitter*60; % units: number of frames at 60 hz

%% design stim timing
%ifi=1/60;
ifi = measifi; 
%ifi = 1/119.94 ; % changed in display settings 
if ifi-measifi>0.1
    disp('Warning: check IFI values');
end

flickerframes=round(1/flicker/ifi);

inverting=[2*ones(1,flickerframes) 3*ones(1,flickerframes)];

y=ones(1,ceil(expdur/ifi));
x=(1:length(y))*ifi;
disp(size(y))
stimindx=zeros(size(allstim));
prevstimoff=zeros(size(allstim));
s=1;
stimindx(s)=3/ifi;
y(stimindx(s):stimindx(s)+presentstim(s)*flickerframes-1)=...
    repmat(inverting,1,presentstim(s)/2);
disp(size(y))

prevstimoff(s+1)=stimindx(s)+presentstim(s)*flickerframes-1;

for s=2:length(allstim)
    stimindx(s)=prevstimoff(s)+(gapdur)/ifi+jitter(s);
    y(stimindx(s):stimindx(s)+presentstim(s)*flickerframes-1)=...
        repmat(inverting,1,presentstim(s)/2);
    prevstimoff(s+1)=stimindx(s)+presentstim(s)*flickerframes-1;
end
disp(size(y))
y=y(1:length(x));
%% Set up dot luminance

% add a offset period before stimuli to allow to reach steady state 
offset = 14 % units = seconds 
offsetsamples=ceil(offset/ifi);
steadystate =ones(1,offsetsamples);
y  = [steadystate y];
x=(1:length(y))*ifi;


% range between 0.3 and 0.8
dotlum=ones(size(x));
dotcol=[1 0 0];

%dotlum=dotlum*200;
isi=unifrnd(1,4,expdur,1);
switches=[0; cumsum(isi)];

for i=1:length(x)
    f=find((-x(i)+switches)>0);
    f=f(1);
    dotlum(i)=mod(f,2)*80+150;
end

Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize,dotcol*dotlum(i),[0 0],2);



%%

%white = WhiteIndex(window); % pixel value for white
black = BlackIndex(window); % pixel value for black
% Now we make this into a PTB texture
radialCheckerboardTexture(1)  = Screen('MakeTexture', window, mean([white black])*ones(size(checks)));
radialCheckerboardTexture(2)  = Screen('MakeTexture', window, checks);
radialCheckerboardTexture(3)  = Screen('MakeTexture', window, flip(checks));


%% Loop at desired frequency
ds=1;

ifi = Screen('GetFlipInterval', window);


% add a key list for each key we want (1s in array of 256 for key we want) 
KbQueueCreate(KB, triggerlist);
%TEMP UNCOMMENT 
%KbQueueCreate(KB)
KbQueueStart(KB);

trtimes=zeros(ceil(expdur/tr)+200,1);
keyval=zeros(size(trtimes));

% line up first= stim image
Screen('Flip',window);
Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize,dotcol*dotlum(i),[0 0],2);
HideCursor;
allt=zeros(length(y),1);

Priority(topPriorityLevel); 
disp('topPriorityLevel') 
disp('prior')

save(bname,'allt','trtimes','x','y','keyval','switches');



pressed=0;
while ~pressed
    pause(0.005);
    [pressed, firstpress]=KbQueueCheck(KB);
    disp(pressed)
%     if ismember(keyindex,find(firstpress))
%         pressed=1;
%     end
end

ts=firstpress(keyindex);
KbQueueRelease(KB);


%only look for keypresses
KbQueueCreate(KB, keylist);
KbQueueStart(KB);

%}
%tyLevel);


%ts=KbWait(-3); %COMMENT BEfORE RUNNING
indx=2;
trtimes(1)=ts;
ts=Screen('Flip',window);

for i=1:length(y)
    Screen('DrawTexture', window, radialCheckerboardTexture(y(i)));
    Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize+10,[1 1 1]*ceil(255/2),[0 0],2);
    Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize,dotcol*dotlum(i),[0 0],2);
    
    [ts,stimon]=Screen(window,'Flip',ts+ifi*ds-ifi*0.5);
    allt(i)=ts;
    
    [pressed,firstpress]=KbQueueCheck(KB);
    if pressed
        k=find(firstpress);
%         if (k == KbName('q'))
%             ShowCursor;
%             Priority(0);
%             Screen('CloseAll');
%             fname=sprintf('%sQUITOUT_flickerblocked_SW_vZ%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.mat',fpath,c);
%             save(fname,'allt','trtimes','x','y','keyval','switches');
%             m=mfilename('fpath');
%             system(['cp ' m '.m ' mname]);
%             KbQueueRelease(KB);
%         end 
        for j=1:length(k)
            keyval(indx)=k(j);
            trtimes(indx)=firstpress(k(j));
            indx=indx+1;
        end
        
    end
end

disp(i);
%disp(['Responses: ' num2str(sum(~isnan(rt))/length(rt)*100) '%']);
%save(fname,'rt','-append');
% calculate accuracy
maxrt=0.8;
realswitches=sum(switches<expdur);
rt=zeros(length(realswitches),1);

for m=1:(realswitches)
    resp=trtimes(keyval~=0&keyval~=22);
    resp=resp-allt(1)-switches(m);
    resp=resp(resp>0&resp<maxrt);
    if isempty(resp)
        rt(m)=nan;
    else
        rt(m)=min(resp);
    end
end
disp(['Responses: ' num2str(sum(~isnan(rt))/length(rt)*100) '%']);

%if (i==y)
%end stimulus
ShowCursor;
Priority(0);
Screen('CloseAll');
save(fname,'allt','trtimes','x','y','keyval','switches');
m=mfilename('fullpath');
system(['cp ' m '.m ' mname]);
KbQueueRelease(KB);
accur = ['Accuracy: ' num2str(sum(~isnan(rt))/length(rt)*100) '%'];
disp(accur);
txtsize = '\fontsize{18} ';
CreateStruct.Interpreter = 'tex';
CreateStruct.WindowStyle = 'modal';
f = msgbox([txtsize accur],CreateStruct);
% disp(['Mean 1RT: ' num2str(nanmean(rt)*1000) ' ms']);
%end
% cleanup = onCleanup(@()myCleanupFun(allt,trtimes,x,y,keyval,switches));



catch 
  ShowCursor;
  Priority(0);
  Screen('CloseAll');
  fname=sprintf('%sERROREDOUT_flickerblocked_SW_vZ%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.mat',fpath,c);
  save(fname,'allt','trtimes','x','y','keyval','switches');
  m=mfilename('fullpath');
  system(['cp ' m '.m ' mname]);
  KbQueueRelease(KB);
end 
end

