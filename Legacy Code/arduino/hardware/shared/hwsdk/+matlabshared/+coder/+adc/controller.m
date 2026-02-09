classdef controller < handle

%#codegen

% Copyright 2019-2022 The MathWorks, Inc.
    properties (Access = {?matlabshared.coder.adc.controller, ?matlabshared.coder.hwsdk.controller})
        AnalogObj
    end

    properties(Access = protected)
        Resolution = 10;
    end

    methods(Static)
        function props = matlabCodegenNontunableProperties(~)
            props = {'Resolution'};
        end
    end

    methods(Access = public)
        function [data] = readVoltage(obj, pin)
        % For number of input arguments less than 2 throw error
            coder.internal.errorIf(nargin < 2, 'MATLAB:minrhs');
            validateAnalogPinNumberHook(obj, pin);
            data = readVoltageHook(obj, pin);
        end

        function pinNumber = validateAnalogPinNumberHook(~, pin)
            pinNumber = pin;
        end
    end

    methods(Access = protected)
        function resultDatatype = getDatatypeFromResolutionHook(~, resolution)
            if 8 >= resolution
                resultDatatype = "uint8";
            elseif 16 >= resolution
                resultDatatype = "uint16";
            elseif 32 >= resolution
                resultDatatype = "uint32";
            elseif 64 >= resolution
                resultDatatype = "uint64";
            end
        end

        function data = readVoltageHook(obj, pin)
            pinNumber = validateAnalogPinNumberHook(obj, pin);
            coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidADCPinNumberCodegen', pin);
            resultDatatype = getDatatypeFromResolutionHook(obj, obj.Resolution);
            reading = readResultAnalogInSingleInternal(obj.AnalogObj, pinNumber, resultDatatype);
            maxCount = coder.const(power(2, obj.Resolution) - 1);
            data = double(reading) / maxCount*getReferenceVoltageImpl(obj);
        end
    end

    methods(Abstract, Access = protected)
        refVoltage = getReferenceVoltageImpl(obj);
    end
end
