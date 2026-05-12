   % checkerboard with kbqueue integrated. Red dot changes luminance.

function [allt,y,trtimes,keyval]=FixationTask()
flicker=12;
Screen('Preference', 'SkipSyncTests', 1)
KbName('UnifyKeyNames')
fpath='/home/lewislab/Documents/stimuli/NIGHT/data'; % edit this to match your path
c=clock;
fname=sprintf('%sFlickerTask_%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.mat',fpath,c); % name for where our results will be saved
mname=sprintf('%sFlickerTask_%02.0f-%02.0f-%02.0f_%02.0f-%02.0f-%02.0f.m',fpath,c); % name for a dated copy of this function 

% keyindex = 22; % this is the index of the TR trigger in our system, may be different in your system
% trigger = KbName('5%'); % this is the keycode for the TR trigger in our system, which is 5/%. may be different in your system
% buttonPresses = [KbNamed('1!') KbName('2@') ] ; %11 12 KB These are the KeyCodes of the subject button presses, which are 1/! and 2/@ in our system
trigger = KbName('+');
keyindex=trigger;
buttonPresses = [KbName('1!') KbName('2@') KbName('3#') KbName('4$') ] ; %11 12 KB

tr=0.37;

keylist = zeros(1, 256); 
keylist([buttonPresses]) = 1; 
 

triggerlist = zeros(1,256); 
triggerlist(trigger) = 1; 


[i j]=GetKeyboardIndices;
%KB=i(find(strcmp(j,'Current Designs, Inc. 932'))); %% This is the name of the keyboard in our system. May be different in your system
KB=i(find(strcmp(j,'Current Designs, Inc. 932'))); %% This is the name of the keyboard in our system. May be different in your system
if isempty(KB)
    KB = -3;
end


dotsize=25 %14; % size of the centrl dot
expdur= 600; % total desired experiment time in seconds

offset=00; % time in seconds before stim start
blockdur = expdur; % length of each epoch in seconds

maxlum=0.9; % white level
minlum=0; % black level



%%
% set up screen
screens = Screen('Screens');
whichScreen = max(screens);
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

% set spacing of flicker pattern
spacing_radial=6;
spacing_concentric=10;

I_radial= sin( ((((sqrt(x.^2+y.^2).^0.3)*2*pi)+0)*spacing_radial) );
I_concentric = sin( atan2(x,y)*spacing_concentric );

checks=sign(I_radial).*sign(I_concentric);
checks=(checks+1)/2;
checks=checks*(white-black)+black;


%% design stim timing

ifi = measifi; 
if ifi-measifi>0.1
    disp('Warning: check IFI values');
end

flickerframes=round(1/flicker/ifi);

inverting=[2*ones(1,flickerframes) 3*ones(1,flickerframes)];

off=ceil(offset/ifi);
numrepeat=(expdur-offset)/ifi/length(inverting)/2;
y=ones(1,off);
y=[y repmat([inverting inverting],1,ceil(numrepeat))];
x=(1:length(y))*ifi;
y(1:offset/ifi)=1;
y(mod(1:length(y),blockdur/ifi*2)<blockdur/ifi+1)=1;


%% Set up dot luminance

% range between 0.3 and 0.8
dotlum=ones(size(x));
dotcol=[1 0 0];


isi=unifrnd(1,4,expdur,1);
switches=[0; cumsum(isi)];

for i=1:length(x)
    f=find((-x(i)+switches)>0);
    f=f(1);
    dotlum(i)=mod(f,2)*80+150;
end

Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize,dotcol*dotlum(i),[0 0],2);



%%

white = WhiteIndex(window); % pixel value for white
black = BlackIndex(window); % pixel value for black
% Now we make this into a PTB texture
radialCheckerboardTexture(1)  = Screen('MakeTexture', window, mean([white black])*ones(size(checks)));
radialCheckerboardTexture(2)  = Screen('MakeTexture', window, checks);
radialCheckerboardTexture(3)  = Screen('MakeTexture', window, -(checks-255/2)+255/2);


%% Loop at desired frequency
ds=1;

ifi = Screen('GetFlipInterval', window);


% add a key list for each key we want (1s in array of 256 for key we want) 
KbQueueCreate(KB, triggerlist);
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


pressed=0;
while ~pressed
    pause(0.005);
    [pressed, firstpress]=KbQueueCheck(KB);
    disp(pressed)
end
ts=firstpress(keyindex);
KbQueueRelease(KB);


%only look for keypresses
KbQueueCreate(KB, keylist);
KbQueueStart(KB);

indx=2;
trtimes(1)=ts;
ts=Screen('Flip',window);

for i=1:length(y)
    Screen('DrawTexture', window, radialCheckerboardTexture(y(i)));
       Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize+10,[1 1 1]*255/2,[0 0],2);
    Screen('DrawDots',window,[windowRect(3)/2 windowRect(4)/2],dotsize,dotcol*dotlum(i),[0 0],2);
    
    [ts,stimon]=Screen(window,'Flip',ts+ifi*ds-ifi*0.5);
    allt(i)=ts;
    
    [pressed,firstpress]=KbQueueCheck(KB);
    if pressed
        k=find(firstpress);
        for j=1:length(k)
            keyval(indx)=k(j);
            trtimes(indx)=firstpress(k(j));
            indx=indx+1;
        end
    end
end
ShowCursor;
Priority(0);
Screen('CloseAll');

save(fname,'allt','trtimes','x','y','keyval','switches');

m=mfilename('fullpath');
system(['cp ' m '.m ' mname]);
KbQueueRelease(KB);


%% calculate accuracy
maxrt=0.8;
realswitches=sum(switches<expdur);
rt=zeros(length(realswitches),1);

for i=1:(realswitches)
    resp=trtimes(keyval~=0&keyval~=22);
    resp=resp-allt(1)-switches(i);
    resp=resp(resp>0&resp<maxrt);
    if isempty(resp)
        rt(i)=nan;
    else
        rt(i)=min(resp);
    end
end
disp(['Responses: ' num2str(sum(~isnan(rt))/length(rt)*100) '%']);
disp(['Mean 1RT: ' num2str(nanmean(rt)*1000) ' ms']);
