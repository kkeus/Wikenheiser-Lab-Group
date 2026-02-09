function result = availableMeasurements()

%   Copyright 2017 The MathWorks, Inc.

    mc = matlabshared.hwsdk.internal.findSubClasses('matlabshared.sensors', 'matlabshared.sensors.sensor', false, false);
    result = {};
    for i = 1:size(mc, 1)
        result{end+1} = matlabshared.hwsdk.internal.shortName(mc{i}.Name); %#ok<AGROW>
    end
    result{end+1} = 'raw';
    result = sort(result);
end

% LocalWords:  matlabshared
