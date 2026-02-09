
%   Copyright 2017-2021 The MathWorks, Inc.

classdef (Abstract) controller_base < matlabshared.hwsdk.internal.base
    % User Interface
    %
    properties(Abstract, GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailablePWMPins
    end
    
    methods(Abstract, Access = public)
        writePWMVoltage(obj, pin, voltage);
    end

    % Developer Interface
    %
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        availablePWMPins = getAvailablePWMPins(obj);
        voltageRange = getPWMVoltageRange(obj);
    end
    
    methods(Abstract, Access = protected)
        availablePWMPins = getAvailablePWMPinsImpl(obj);
        voltageRange = getPWMVoltageRangeImpl(obj);
    end
end