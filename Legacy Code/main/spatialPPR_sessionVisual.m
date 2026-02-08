function spatialPPR_sessionVisual

%load tracking data
[x, y] = loadTracking_trodes;

%load events
[eventID, eventTime_trodes, ~] = loadEvents_trodes;
%e2 = zeros(127,1);
%e2(2:end,1) = eventTime_trodes;
%eventTime_trodes = e2;


%load task record
tr = load(FindFile('*taskRecord*'));

%parse events
events = parseEvents(eventID,eventTime_trodes);

%get session ID number
[~,fn] = fileparts(pwd);

%do the plot
figure

%2-d tracking plot
subplot(221)
%hard-coded task zones
patch([1014 1575 1575 1014],[ 900 900 200 200],'g');
hold on
patch([1008,1008,875,875],[900 200 200 900],'r');
alpha(0.05);
plot(x.data,y.data,'k');
axis equal 
axis off
%add some events
if isfield(events,'entered_patch2');
    plot(x.data(events.entered_patch2),...
        y.data(events.entered_patch2), 'bo','MarkerFaceColor','b');
end
title(fn)

%add some events
if isfield(events,'left_patch2');
    plot(x.data(events.left_patch2),...
        y.data(events.left_patch2), 'ro','MarkerFaceColor','r');
end

%1-d tracking plot
subplot(2,2,[2,4])
% axis equal
box off
ylabel('Session time (s)')
xlabel('Rat x-position')
yl = [0 tr.parms.sessionDuration];
hold on
patch([1014 1575 1575 1014],[ yl(2) yl(2) yl(1) yl(1)],'g');
patch([1008,1008,875,875],[ yl(2) yl(1) yl(1) yl(2)],'r');
alpha(0.05);
plot(x.data,x.range-events.sessionStart,'k')
plot(x.data(events.feeder_patch2_1),events.feeder_patch2_1-events.sessionStart,'m.','MarkerSize',15)

xlim([875 1575])
ylim(yl)
set(gca,'XTickLabel',[]);

%compute rewards/visit and visit duration
entry = events.entered_patch2;
exit = events.left_patch2;
entry = entry(1:length(exit));
if length(entry)>0;
    ppv = NaN(length(entry),1);
    for iE = 1:length(entry);
        ppv(iE) = sum(events.feeder_patch2_1>=entry(iE)&events.feeder_patch2_1<=exit(iE));
    end
    res = exit-entry;
end


subplot(223)
plotSpread(res,'XValues',1,'showMM',1,'DistributionColors','k','DistributionMarkers','o');
ylabel('Patch residence duration (s)');
ylim([0,round(max(res).*1.1)])
yyaxis right
plotSpread(ppv,'XValues',2,'showMM',1,'DistributionColors','b','DistributionMarkers','o');
ylabel('Pellets per visit');
ylim([0,round(max(ppv).*1.1)])
xlim([0 3])
axis square
