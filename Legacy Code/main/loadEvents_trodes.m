function [eventID, eventTime_trodes, eventTime_matlab] = loadEvents_trodes(varargin)

process_varargin(varargin);

%load matlab task record
fn_tr = FindFile('*.mat');
tr = load(fn_tr);

try
    eventTime_matlab = tr.eventTime_matlab';
catch
    eventTime_matlab = tr.eventTime;
end
eventID = tr.eventID';

%load trodes digital events stream
fn_trodes = FindFiles('*.rec', 'CheckSubdirs',1);
timestamps = readTrodesFileDigitalChannels(fn_trodes{2});
    
%find rising edges in trodes events stream
[eventTime_trodes, ~]  = ttlEdges(tsd(double(timestamps.timestamps), double(timestamps.channelData(1).data)));
eventTime_trodes = eventTime_trodes.data;


%make sure they match up!
if length(eventTime_trodes)~=length(eventTime_matlab);
    disp('Warning: Event length mismatch! Check your data!')
end




