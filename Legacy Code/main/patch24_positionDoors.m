function patch24_positionDoors(a,pos)

%pos is a two-element vector (one for each door) that denotes the desired
%end positions of each after calling fx. 0 = open, 1 = closed, NaN = don't
%change

if pos(1)==0 & pos(2)==0; %open both doors
    a.writeDigitalPin('D6',0);
    pause(0.1);
    a.writeDigitalPin('D6',1);

elseif pos(1)==1 & pos(2)==1; %close both doors
    a.writeDigitalPin('D7',0);
    pause(0.1);
    a.writeDigitalPin('D7',1);

elseif pos(1)==0 & isnan(pos(2)); %open 1
    a.writeDigitalPin('D8',0);
    pause(0.1);
    a.writeDigitalPin('D8',1);

elseif pos(1)==1 & isnan(pos(2)); %close 1
    a.writeDigitalPin('D9',0);
    pause(0.1);
    a.writeDigitalPin('D9',1);

elseif isnan(pos(1)) & pos(2)==0; %open 2
    a.writeDigitalPin('D10',0);
    pause(0.1);
    a.writeDigitalPin('D10',1);

elseif isnan(pos(1)) & pos(2)==1; %close 2
    a.writeDigitalPin('D11',0);
    pause(0.1);
    a.writeDigitalPin('D11',1);

end