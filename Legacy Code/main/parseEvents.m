function [events] = parseEvents(eventID, eventTime, varargin)

process_varargin(varargin);

%find the events that occurred in this session
eventNames = unique(eventID);

%pre-allocate events output structure
events = struct();

%loop through event names, find matching timestamps, write them to events
%struct
for iName = 1:length(eventNames);
    match = strcmp(eventNames{iName},eventID);
    events.(eventNames{iName}) = eventTime(match);
end