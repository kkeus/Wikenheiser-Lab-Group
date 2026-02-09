classdef (Abstract) controller_base < matlabshared.hwsdk.internal.base
%   ADC Controller Base class

%   Copyright 2017-2024 The MathWorks, Inc.
    % User Interface
    %
    properties(Abstract, GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableAnalogPins string
    end
    
    methods(Abstract, Access = public)
        data = readVoltage(obj, pin);
    end

    % Developer Interface
    %
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        availableAnalogPins = getAvailableAnalogInputVoltagePins(obj);
    end
    
    methods(Abstract, Access = protected)
        availableAnalogPins = getAvailableAnalogInputVoltagePinsImpl(obj);
        referenceVoltage = getReferenceVoltageImpl(obj);
    end
    methods(Abstract, Access = protected)
        pinNumber = getADCPinNumberHook(obj, pin);
        voltage = sampleToVoltageConverterHook(obj,counts,resultDatatype);
        resolution = getADCResolutionInBitsHook(obj);
        resultDatatype = getDatatypeFromResolutionHook(obj);
        recordingPreCheckHook(obj);
    end
end
