function patch25_spatialPPR(a, varargin)

%Rebuilt from patch24_gaussianPatch; 27-July-25 - amw

notes = [];

sessionDuration = 15*60; % - s, length of session 
travelTime = 10; % - s
progression = 1; %sets how the effort requirement increases; zero would result in no progression

doorOpenTimeout = 3; %rat can't officially enter the patch until this much time elapses from doorOpen command

d1_pos = [571,631]; %measured from center of open door! -- remeasured 14 May 24
d2_pos = [741,631]; %measured from center of open door! -- remeasured 14 May 24

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
l_pos = [1328 , 808; 
         1524 , 524;
         1313 , 255  ];
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

l_pins = {'A1','A2','A3'};
l_thresh = 35;

travel_pos = [657,128]; %measured 4 Feb 24
travelThresh = 350;
patchEntryThresh = 500; %measured from door

nPellets = 1; %pellets delivered per feeder activation

nSample_pre = 500; %this is the number of tracking samples to flush before actually starting session....

process_varargin(varargin);

%initialize counter
TotalPellets = 0;

%generate list of LEDs to activate with no repeats
l_active = randi(3,5000,1);
bad = 1;
while bad;
    bad = l_active(1:end-1)==l_active(2:end);
    l_active = l_active(~bad);
end

%setup output variables
eventTime = [];
eventID = [];

%initialize main loop
tSess = 0;

state_desc = {'travel','pre-forage','forage'};
state = 1; %initialize task in "travel" state

%connect to trodes
sub = init_tracking_client;

%prompt user and wait for command to start
disp('--------------------------------------------------------------------');
disp('Task set up complete!');
disp('Place rat in corridor and start recording in Trodes.');
disp('Press any key to begin the patch task');
disp('--------------------------------------------------------------------');

pause;

%set up display figure
f = figure(1); clf;
TimeDisplay = uicontrol('Style','text','String','ElapsedSessionTime   ', 'units', 'normalized','Position', [0.15 0.5 0.7 0.10],'FontSize',18);
StateDisplay = uicontrol('Style','text','String','Task State', 'units', 'normalized','Position', [0.15 0.7 0.7 0.10],'FontSize',18);
TravelDisplay = uicontrol('Style','text','String','In shelter ', 'units', 'normalized','Position', [0.15 0.3 0.7 0.10],'FontSize',18);
RatioDisplay = uicontrol('Style','text','String','Ratio progress: ', 'units', 'normalized','Position', [0.15 0.1 0.7 0.10],'FontSize',18);
shelterDisplay = {'No','Yes'};


%timers
f0 = NaN; %this is the forage timer
w0 = NaN; %this is the travel timer
door0 = NaN; %this is the door timer...
counter = NaN;
requirement = NaN;

travelDoorFlag = 0; %on means doors need to be closed
ledFlag = 1; %on means an LED needs to be turned on

t_loop = []; %for debugging purposes only

%run n seconds worth of tracking to ensure buffer is full of actually good
%tracking samples....
x_pre = NaN(nSample_pre,1);
y_pre = x_pre;
for iS = 1:(30*8);
    [x_pre(iS), y_pre(iS)] = get_latest_xy(sub);
end

%take initial time stamp
t0 = clock;

%send start code and log event in matlab
eventTime(end+1) = etime(clock,t0);
patch24_flipPin(a,'A0'); %A0 is the sync ttl to the spike gadgets logger dock
eventID{end+1} = 'sessionStart';

%turn on travel timer so first state is travel time
w0 = clock;

%main task control loop
while tSess<=sessionDuration;

    %session time?
    tSess = etime(clock,t0);

    % %for debugging only: track loop speed
    % t_loop(end+1) = tSess;

    %where is the rat?
    [x, y] = get_latest_xy(sub);

    %any checks/fixes for bad samples would go here
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %is the rat in the travel area or patch?
    inShelter = ratInShelter(x,y); %middle waiting area
    inPatch = ratInPatch(x,y); 

    %what is the current state?
    if ~isnan(w0) & isnan(f0); %travel timer is active, must be travel state
        state = 1; %travel state
    elseif isnan(w0) & isnan(f0); %rat isn't travelling or foraging, must be waiting for rat to enter a patch
        state = 2; %pre-forage state
    elseif isnan(w0) & ~isnan(f0); %forage timer is active, rat must be foraging
        state = 3; %forage_2
    end

    %update display
    set(TimeDisplay, 'String', sprintf('ElapsedTime %.2f ... %.2f', tSess, sessionDuration));
    set(StateDisplay, 'String', strcat({'State:  '}, state_desc{state}));
    set(TravelDisplay, 'String', strcat({'In Shelter: '}, shelterDisplay{inShelter+1}));
    % set(RatioDisplay, 'String', sprintf('Ratio progress: %.2f / %.2f', counter, requirement));
    set(RatioDisplay, 'String', sprintf('Ratio progress: %.2f / %.2f', x, y)); %debugging tracking display

    drawnow;

    %follow approrpriate control sequence for that state

    if state == 1; %the travel state

        if travelDoorFlag == 1; %first time here, close all doors
            patch24_positionDoors(a,[NaN 1]);

            %timestamp
            eventTime(end+1) = tSess;
            eventID{end+1} = 'Door2_closed';
            patch24_flipPin(a,'A0');

            travelDoorFlag = 0;
        end

        %has the travel time elapsed?
        if etime(clock, w0)>=travelTime; %travel time elapsed

            %Cancel the wait timer
            w0 = NaN;

            %open door, start door timer, and timestamp
            patch24_positionDoors(a,[NaN 0]);
            door0 = clock;

            eventTime(end+1) = tSess;
            eventID{end+1} = 'Door2_opened';
            patch24_flipPin(a,'A0');
        end

    elseif state == 2; %pre-forage state

        %have the doors finished moving?
        doorOK = etime(clock,door0)>doorOpenTimeout;

        %has the rat entered patch 2?
        if pdist([d2_pos(1),d2_pos(2);x,y]) > patchEntryThresh && ~inShelter && inPatch==2 && doorOK;

            %mark timestamp
            eventTime(end+1) = tSess;
            eventID{end+1} = 'entered_patch2';
            patch24_flipPin(a,'A0');

            %set forage timer
            f0 = clock;

            %reset the door timer
            door0 = NaN;
        end

    elseif state == 3; %the forage_2 state

        if isnan(counter); %first time here, set counter and thresh
            counter = 0;
            requirement = 1;
        end

        if ledFlag; %true means we need to turn on the next LED in sequence

            %advance LED list
            l_active = circshift(l_active,-1);

            %write next LED
            a.writeDigitalPin(l_pins{ l_active(1) }, 1);

            %mark timestamp
            eventTime(end+1) = tSess;
            eventID{end+1} = strcat('led',num2str(l_active(1)),'On');
            patch24_flipPin(a,'A0');

            %turn off LED flag
            ledFlag = 0;

        end

        %did the rat leave the patch?
        if y < travelThresh && inShelter; %rat left the patch

            %reset forage timer
            f0 = NaN;
            w0 = clock;
            travelDoorFlag = 1;
            counter = NaN;
            requirement = NaN;

            %turn off any LEDs
            for iP = 1:length(l_pins);
                a.writeDigitalPin(l_pins{iP},0);
            end

            %turn on LED flag
            ledFlag = 1;

            %timestamp exit
            eventTime(end+1) = tSess;
            eventID{end+1} = 'left_patch2';
            patch24_flipPin(a,'A0');

        else

            %has the rat approached the active LED?
            if pdist([l_pos(l_active(1),:);x,y]) < l_thresh;

                %timestamp successful approach
                eventTime(end+1) = tSess;
                eventID{end+1} = strcat('approachedLed',num2str(l_active(1)));
                patch24_flipPin(a,'A0');

                %turn off the LED
                a.writeDigitalPin(l_pins{l_active(1)},0);

                %increment counter
                counter = counter+1;

                %turn on LED flag
                ledFlag = 1;

                %do we fire a feeder?
                if counter>=requirement;
                    patch_fireFeeder(a, 'A5',nPellets); %feeder2

                    eventTime(end+1) = tSess;
                    eventID{end+1} = 'feeder_patch2_1';
                    patch24_flipPin(a,'A0');

                    %increment TotalPellets
                    TotalPellets = TotalPellets + 1;

                    %reset counter
                    counter = 0;

                    %increment threshold
                    requirement = requirement+progression;
                end


            end
        end
    end
end

%timestamp session end
eventTime(end+1) = tSess;
eventID{end+1} = 'sessionEnd';
patch24_flipPin(a,'A0');

close(f); %close display figure

soundsc(sin(1:450),1820); %play completion noise
pause(.4)
soundsc(sin(1:430),1520);
pause(.55)
soundsc(sin(1:1300),1350);

% display total pellets dispensed
disp('-----------------------------------------------------------')
disp(strcat({'Total pellets earned = '}, num2str(TotalPellets)));
disp('-----------------------------------------------------------')

%turn off any LEDs
for iP = 1:length(l_pins);
    a.writeDigitalPin(l_pins{iP},0);
end

%package outputs & save
%parms
parms.progression = progression;
parms.travelTime = travelTime;
parms.sessionDuration = sessionDuration;
parms.patchEntryThresh = patchEntryThresh;
parms.nPellets = nPellets;
parms.d1_pos = d1_pos;
parms.d2_pos = d2_pos;
parms.l_pos = l_pos;
parms.travel_pos = travel_pos;
parms.travelThresh = travelThresh;
parms.notes = notes;
parms.nSample_pre = nSample_pre;
parms.x_pre = x_pre;
parms.y_pre = y_pre;

od = pwd;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cd('D:\amwLab_data');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dStr = string(datetime('now','TimeZone','local','Format','dMMyy_HHmmss'));
fn = char(strcat('taskRecord_',dStr,'.mat'));
save(fn,'eventTime','eventID','parms');
cd(od);

disp('Press any key to close both doors');
pause
patch24_positionDoors(a,[NaN 1]);
pause(4);




end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function inShelter = ratInShelter(x,y);

%inShelter = inpolygon(x,y,[1008,1008,875,875],[900 200 200 900]); %new coords 10 Jun 24
inShelter = inpolygon(x,y,[1013,1013,870,870],[900 200 200 900]); %new coords 13 Aug 25 TF

end

function inPatch = ratInPatch(x,y);

p1 = inpolygon(x,y,[0 562 571 0],[747 747 -25 -25]); %new coords - 10 June 24
p2 = inpolygon(x,y,[1014 1575 1575 1014],[900 900 200 200]);

if p1;
    inPatch = 1;
elseif p2;
    inPatch = 2;
else
    inPatch = 0;
end
end

function patch24_flipPin(a,pin)

a.writeDigitalPin(pin,1);
pause(0.12);
a.writeDigitalPin(pin,0);
pause(0.12);

end
