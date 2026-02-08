function [x, y] = loadTracking_trodes(varargin)

fs = 30; %if ~=0, resamples tracking to uniform 30 hz rate

process_varargin(varargin);

%find trodes tracking file
fn_tracking = FindFile('*.videoPositionTracking', 'CheckSubdirs', 1);
tracking = readTrodesExtractedDataFile(fn_tracking);
    
%find time stamps file
fn_ts = FindFile('*.videoTimeStamps', 'CheckSubdirs',1);
[timestamps,~] = readCameraModuleTimeStamps(fn_ts);

%% ALTERED CODE HERE TO TEST FIXING THE TIMESTAMP ISSUE
% DELETE THIS SECTION LATER TO PRESERVE ORIGINAL CODE

timestamps_camera = timestamps;
timestamps_tracking = tracking.fields(2).data;
index2subtract = length(timestamps_camera)-length(timestamps_tracking);
index2subtract = index2subtract+1;
timestamps_camera = timestamps_camera(index2subtract:end,1);
try
    x = tsd(timestamps_camera, double(tracking.fields(2).data));
    y = tsd(timestamps_camera, double(tracking.fields(3).data));
catch
    x = tsd(timestamps_camera(1:end-64), double(tracking.fields(2).data));
    y = tsd(timestamps_camera(1:end-64), double(tracking.fields(3).data));
end

% UN-COMMENT OUT THE NEXT SESSION WHEN DONE TESTING THIS METHOD
% END SECTION

%% SECTION OF ANDREW'S CODE THAT NEEDS TO BE COMMENTED OUT FOR TESTING

% %package x and y into tsds
% try
%     x = tsd(timestamps, double(tracking.fields(2).data));
%     y = tsd(timestamps, double(tracking.fields(3).data));
% catch
% 
%     x = tsd(timestamps(1:end-64), double(tracking.fields(2).data));
%     y = tsd(timestamps(1:end-64), double(tracking.fields(3).data));
% end

%%

%resample at set sampling rate
xd = x.data; xr = x.range;
yd = y.data; yr = y.range;


[xd_new,xr_new] = resample(xd,xr,fs);
x = tsd(xr_new,xd_new);

[yd_new,yr_new] = resample(yd,yr,fs);
y = tsd(yr_new,yd_new);

