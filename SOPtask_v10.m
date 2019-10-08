%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   SOPtask.m     8 Feb, 2019 
%   Description: Social Orientation Paradigm (task)
%   Session, Researcher ID, Number of minutes (default 8), Points to start with (default 20) 
%   
%   
%   
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% imp pt compile Psychtoolbox cu sunet
% https://www.mathworks.com/matlabcentral/answers/306114-compiler-issue-depe33ndecy-problem
% cd('E:\Cinetic idei noi\Psychtoolbox & Matlab\SOPtask');
% cd ('C:\Users\Administrator\Desktop\SOPtask v.10');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Experimental parameters
clear all; % clears all workspace variables
close all; % closes all open figures
sca;
Screen('Preference', 'SkipSyncTests', 1);

deviceIndex = [];
KbName('UnifyKeyNames');
%ListenChar(-1);
Key1 = KbName('1!'); Key2 = KbName('2@'); Key3 = KbName('3#');
spaceKey = KbName('space'); escapeKey = KbName('escape');
keysOfInterest=zeros(1,256);
keysOfInterest(KbName('1!'))=1;
keysOfInterest(KbName('2@'))=1;
keysOfInterest(KbName('3#'))=1;
keysOfInterest(KbName('escape'))=1;

corrkey = [49, 50, 51]; % 1,2,3 on Windows
gray = [127 127 127]; white = [255 255 255]; black = [0 0 0]; red = [255 0 0];
bgcolor = black; textcolor = white; 
text2color = red;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Sound feedback
InitializePsychSound(1); %inidializes sound driver...the 1 pushes for low latency
repetitions=1; % how many repititions of the sound
nrchannels = 2; % stereo?

[Bwavedata Bfreq] = audioread('./bad_snd.wav');  % load sound file (make sure that it is in the same folder as this script
[Gwavedata Gfreq] = audioread('./good_snd.wav'); 
% Open Psych-Audio port, with the follow arguements
% (1) [] = default sound device
% (2) 1 = sound playback only
% (3) 1 = default level of latency
% (4) Requested frequency in samples per second
% (5) 2 = stereo putput

% Bpahandle = PsychPortAudio('Open', 1, 1, 1, Bfreq, 1); % Settings used on eye tracking laptop
% Gpahandle = PsychPortAudio('Open', 1, 1, 1, Gfreq, 2); 
Bpahandle = PsychPortAudio('Open', [], 1, 1, Bfreq, 1); % Settings used on MET EEG task PC (opens sound buffer at a set frequency)
Gpahandle = PsychPortAudio('Open', [], 1, 1, Gfreq, 2); % necesary to use channel 2 for second sound, not sure why

PsychPortAudio('FillBuffer', Bpahandle, Bwavedata'); % loads data into buffer
PsychPortAudio('FillBuffer', Gpahandle, Gwavedata'); 
%PsychPortAudio('Start', Bpahandle, repetitions, 0); %starts sound immediatley
%PsychPortAudio('Start', Gpahandle, repetitions, 0);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Check if Excel & Excel COM server installed
        %[Result1, WordPath1] = system('WHERE /F /R "C:\Program Files (x86)" excel.exe')
        %[Result2, WordPath2] = system('WHERE /F /R "C:\Program Files" excel.exe')
    try
            % See if there is an existing instance of Excel running.
            % If Excel is NOT running, this will throw an error and send us to the catch block below.
            Excel = actxGetRunningServer('Excel.Application');
            % If there was no error, then we were able to connect to it.
        catch
            % No instance of Excel is currently running.  Create a new one.
            % Normally you'll get here (because Excel is not usually running when you run this).
            try
            Excel = actxserver('Excel.Application');
             %Excel.Version
            end
    end
       % RELEASE command with the ActiveX server object
       if exist('Excel','var') == 1  
          release(Excel)
       end

       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Login prompt and open file for writing data out

prompt = {'Outputfile', 'Subject''s number:', 'Age', 'Gender', 'Group', 'Task Time(minutes)','Start Points'};
defaults = {'SopTask', 'ID', '18', 'F', 'experimental' , '8','20'};
answer = inputdlg(prompt, 'SopTask', 2, defaults);
[output, subid, subage, gender, group, taskTime,pcts] = deal(answer{:}); % all input variables are strings
pcts = str2num(pcts);
points = pcts; % should be default and set at prompt
%outputname = [output gender subid group subage '.xls'];
outputname=[output subid group];
outputnamecheck=[outputname '.xls'];
taskTime=str2num(taskTime);
secondsTrial1 = 60;     % 60 seconds until -1 point 
secondsTrial2 = 45;     % 45 seconds until -1 point 
% both timers will subtract 1 point at 60 sec, but 1 will have 60 sec delay, the other 45 sec 
pointsTime = [];       % Atention: pointsTime define trials => 2/min => 16 trials
keyName = [];
keyTime = [];
numberTrials = taskTime;    % trail is defined by two -1 point attacks (one at 45, one at 60 sec)      
CloseTask = 0;     

if exist(outputnamecheck)==2 % check to avoid overiding an existing file
    warning = questdlg('That file already exists! Append a .x (1), overwrite (2), or break (3/default)?',...
        'Warning',...
        'Append x','Overwrite','Cancel','Cancel');
            switch warning
                case 'Append x'
                fileproblem = 1;
                case 'Overwrite'
                fileproblem = 2;
                case 'Cancel'
                fileproblem = 3;
            end
    if fileproblem==3
        return;
    elseif fileproblem==1
        outputname = [outputname 'X' '.xls'];
    end
end

% Open Excel file for writting
if exist('Excel','var') == 1
    line1={'Subj_id','Subj_age', 'Gender', 'Group', 'TaskTime(minutes)','KeyName', 'KeyTime', 'Contor1', 'Contor3', 'PointsTime', 'Points'};
    xlswrite(outputname,line1);
    line21={subid,subage, gender, group, taskTime};
    xlswrite(outputname,line21,'','A2' ); 
end 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% What timers should do
placeHolder = ['points = points - 1;' ...
               'pointsTime = [pointsTime (GetSecs - startSecs)];'...
               'PsychPortAudio(''Start'', Bpahandle, repetitions, 0);' ...
               'Screen(''TextSize'', mainwin, 120);'...
               'Screen(''TextFont'', mainwin, ''Arial'');' ...
               'DrawFormattedText(mainwin, sprintf(''%.5g'', points), center(1)-70, center(2)+300, red);' ...
               'Screen(''TextSize'', mainwin, 100);' ...
               'DrawFormattedText(mainwin, ''1'', center(1)-500, center(2)-300, white);' ...
               'DrawFormattedText(mainwin, ''2'', center(1), center(2)-300, white);' ...
               'DrawFormattedText(mainwin, ''3'', center(1)+500, center(2)-300, white);' ...
               ' Screen(''Flip'', mainwin);' ...
               'Screen(''FillRect'', mainwin, black);'];
           
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Screen parameters
[mainwin, screenrect] = Screen(0, 'OpenWindow');
Priority(MaxPriority(mainwin));
HideCursor();
Screen('FillRect', mainwin, bgcolor);
center = [screenrect(3)/2 screenrect(4)/2];
Screen(mainwin, 'Flip');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   Experimental instructions, wait for a spacebar response to start
Screen('FillRect', mainwin, bgcolor);
Screen('TextSize', mainwin, 24);
Screen('DrawText',mainwin,['Apasati space pentru a incepe experimentul.'] ,center(1)-350,center(2)-20,textcolor);
Screen('Flip',mainwin );
%KbStrokeWait;


keyIsDown=0;
while 1
    [keyIsDown, secs, keyCode] = KbCheck;
    if keyIsDown
        if keyCode(spaceKey)
            break ;
        elseif keyCode(escapeKey)
             ShowCursor;
             Screen('CloseAll');
            return;
        end
    end
end
WaitSecs(0.1);

startSecs = GetSecs;
KbQueueCreate(deviceIndex, keysOfInterest);
KbQueueStart(deviceIndex);


Screen('TextSize', mainwin, 120);
Screen('TextFont', mainwin, 'Arial');
DrawFormattedText(mainwin, sprintf('%.5g' ,points), center(1)-70, center(2)+300, red);
Screen('TextSize', mainwin, 100);
DrawFormattedText(mainwin, '1', center(1)-500, center(2)-300, white);
DrawFormattedText(mainwin, '2', center(1), center(2)-300, white);
DrawFormattedText(mainwin, '3', center(1)+500, center(2)-300, white);
Screen('Flip', mainwin);
Screen('FillRect', mainwin, black);

% 60 sec delayed timer subtracts every 60 secs until end
t1 = timer('StartDelay', secondsTrial1, ...                 
          'TimerFcn', placeHolder, ...          
          'ExecutionMode','fixedRate','Period', secondsTrial1, ...     
          'TasksToExecute', numberTrials, ...
          'StopFcn', 'CloseTask=1' ); 
% 45 sec delayed timer (still secs subtracts at every 60 sec)  
t2 = timer('StartDelay', secondsTrial2, ...                
          'TimerFcn', placeHolder, ...          
          'ExecutionMode','fixedRate','Period', secondsTrial1, ...     
          'TasksToExecute', numberTrials);     
      
start(t1)
start(t2)
 

while 1
     
    
    if CloseTask==1                 % when task needs to end
        if exist('Excel','var') == 1  
            % Save to excel
            xlswrite(outputname,keyName.','','F2');
            xlswrite(outputname,keyTime.','','G2');
            xlswrite(outputname,contor1,'','H2');
            xlswrite(outputname,contor3,'','I2');
            xlswrite(outputname,pointsTime.','','J2');
            xlswrite(outputname,points,'','K2');
        end
        % Save .mat file
        data.Subj_id = subid;
        data.Subj_age = subage;
        data.Gender = gender;
        data.Group = group;
        data.TaskTime = taskTime;
        data.KeyName = (keyName).';
        data.KeyTime = (keyTime).';
        data.Contor1 = contor1;
        data.Contor3 = contor3;
        data.PointsTime = (pointsTime).';
        data.Points = points;
        matFileName = strtok(outputname, '.')
        save(strcat(matFileName, '.mat'), 'data');

         ShowCursor;   
         Screen('CloseAll');
         return;
    end
    
    
    [pressed, firstPress]=KbQueueCheck(deviceIndex);
    timeSecs = firstPress(find(firstPress)); 
    if pressed           
        
        % fprintf('"%s" typed at time %.3f seconds\n', KbName(min(find(firstPress))), timeSecs - startSecs);
        % extract 1,2,3 from 1!,2@,3# and make double ... ESCAPE will be 21
        keyName = [keyName subsref(KbName(min(find(firstPress))),struct('type','()','subs',{{1}})) - '0'];
        keyTime = [keyTime timeSecs - startSecs];
       
        contor1=length(find(keyName(:)==1));
        contor3=length(find(keyName(:)==3));
        
        
        if firstPress(Key1) || firstPress(Key2) || firstPress(Key3) & ~firstPress(escapeKey)
                 
             if firstPress(Key1) & rem(contor1, 30)==0            
               points=points+1;
               PsychPortAudio('Start', Gpahandle, repetitions, 0);
                              
                Screen('TextSize', mainwin, 120);
                Screen('TextFont', mainwin, 'Arial');
                DrawFormattedText(mainwin, sprintf('%.5g', points), center(1)-70, center(2)+300, red);
                Screen('TextSize', mainwin, 100);
                DrawFormattedText(mainwin, '1', center(1)-500, center(2)-300, white);
                DrawFormattedText(mainwin, '2', center(1), center(2)-300, white);
                DrawFormattedText(mainwin, '3', center(1)+500, center(2)-300, white);
                Screen('Flip', mainwin);
                Screen('FillRect', mainwin, black);
             end
             
             
           if firstPress(Key3) & rem(contor3, 15)==0
                points=points+0.5;
                PsychPortAudio('Start', Gpahandle, repetitions, 0);  
                
                Screen('TextSize', mainwin, 120);
                Screen('TextFont', mainwin, 'Arial');
                DrawFormattedText(mainwin, sprintf('%.5g', points), center(1)-70, center(2)+300, red);
                Screen('TextSize', mainwin, 100);
                DrawFormattedText(mainwin, '1', center(1)-500, center(2)-300, white);
                DrawFormattedText(mainwin, '2', center(1), center(2)-300, white);
                DrawFormattedText(mainwin, '3', center(1)+500, center(2)-300, white);
                Screen('Flip', mainwin);
                Screen('FillRect', mainwin, black);
           end
                

        end
        
     
     if firstPress(escapeKey)
           break;

     end
     

      
    end


end


KbQueueRelease(deviceIndex);
ListenChar(0);


PsychPortAudio('Stop', Bpahandle);% Stop sound playback
PsychPortAudio('Close', Bpahandle);% Close the audio device:
PsychPortAudio('Stop', Gpahandle);% Stop sound playback
PsychPortAudio('Close', Gpahandle);% Close the audio device:





% End
Screen('CloseAll');
% Priority(0);
% ShowCursor;
