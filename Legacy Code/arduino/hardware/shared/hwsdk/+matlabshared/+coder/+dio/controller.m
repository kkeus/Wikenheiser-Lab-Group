classdef controller < handle

% Copyright 2019-2022 The MathWorks, Inc.

%#codegen
    properties (Access = {?matlabshared.coder.dio.controller, ?matlabshared.coder.hwsdk.controller, ?matlabshared.coder.spi.device})
        % This objects holds an handle of the peripheral for a particular
        % target. The property is initialized inside hardware class
        DigitalIODriverObj
    end
    methods
        function data = readDigitalPin(obj, pin)
        % For number of input arguments less than 2 throw error
            coder.internal.errorIf(nargin < 2, 'MATLAB:minrhs');
            % Convert the pin number into numeric value
            pinNumber = obj.validateDigitalPinNumberHook(pin);
            coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidDigitalPinNumberCodegen', pin);

            data = readDigitalPinHook(obj, pinNumber);
        end

        function writeDigitalPin(obj, pin, data)
        % For number of input arguments less than 3 throw error
            coder.internal.errorIf(nargin < 3, 'MATLAB:minrhs');
            % Convert the pin number into numeric value
            pinNumber = obj.validateDigitalPinNumberHook(pin);
            data = validateDigitalOutputData(obj, data);
            coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidDigitalPinNumberCodegen', pin);
            writeDigitalPinHook(obj, pinNumber, data);
        end

        function pinNumber = validateDigitalPinNumberHook(~, pin)
            pinNumber = pin;
        end
    end

    methods(Access = protected)
        function data = readDigitalPinHook(obj, pinNumber)
            data = readDigitalPinInternal(obj.DigitalIODriverObj, pinNumber);
        end

        function writeDigitalPinHook(obj, pinNumber, value)
            writeDigitalPinInternal(obj.DigitalIODriverObj, pinNumber, value);
        end
    end

    methods(Sealed, Access = protected)
        function data = validateDigitalOutputData(~, data)
            coder.internal.assert(islogical(data) ||  isnumeric(data) && isscalar(data) && isreal(data) && ...
                                  isfinite(data) && ~isnan(data) && data==floor(data), 'MATLAB:hwsdk:general:invalidDigitalType');
            coder.internal.assert(data == 0 || data == 1, 'MATLAB:hwsdk:general:invalidDigitalType');
        end
    end
end
