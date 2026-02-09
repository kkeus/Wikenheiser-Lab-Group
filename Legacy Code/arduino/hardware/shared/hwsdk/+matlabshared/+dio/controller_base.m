classdef (Abstract) controller_base < matlabshared.hwsdk.internal.base
%   Digital controller Base class

%   Copyright 2017-2022 The MathWorks, Inc.
    % User Interface
    %
    properties(Abstract, GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableDigitalPins
    end
    
    methods(Abstract, Access = public)
        data = readDigitalPin(obj, pin);
        writeDigitalPin(obj, pin, data);
    end

    % Developer Interface
    %
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        availableDigitalPins = getAvailableDigitalPins(obj);
    end
    
    methods(Abstract, Access = protected)
        availableDigitalPins = getAvailableDigitalPinsImpl(obj);
    end
end