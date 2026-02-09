classdef controller < handle

%#codegen

% Copyright 2019-2022 The MathWorks, Inc.
    properties (Access = {?matlabshared.coder.pwm.controller, ?matlabshared.coder.hwsdk.controller})
        % In the hardware class this property should be initialized with
        % the corresponding peripheral device driver object for that
        % particular hardware
        PWMDriverObj
    end

    methods(Access = protected, Abstract)
        % This function should be filled by target author to return the
        % lower and higher range of PWM Voltage. Example - For Arduino it
        % is [0 - 3.3 V] or [0 - 5 V] based on the board
        voltageRange = getPWMVoltageRangeImpl(obj);
    end

    methods(Sealed, Access = public)
        function writePWMVoltage(obj, pin, voltage)
        %   Output a PWM signal on a PWM pin.
        %
        %   Syntax:
        %   writePWMVoltage(obj,pin,voltage)
        %
        %   Description:
        %   Write the specified voltage to the specified PWM pin.
        %
        %   Input Arguments:
        %   obj     - Low Cost Hardware Object
        %   pin     - PWM pin number on the hardware (character vector or string)
        %   voltage - PWM signal voltage to write to the PWM pin (double).
        %
        %   See also writeDigitalPin, writePWMDutyCycle

        % For number of input arguments less than 3 throw error
            coder.internal.errorIf(nargin < 3, 'MATLAB:minrhs');
            voltageRange = obj.getPWMVoltageRange();
            range = voltageRange(2) - voltageRange(1);
            voltage = obj.validatePWMVoltage(voltage, voltageRange);
            dutyCycle = voltage/range;
            obj.writePWMDutyCycleHook(pin, dutyCycle);
        end

        function writePWMDutyCycle(obj, pin, dutyCycle)
        %   Output a PWM signal on a PWM pin.
        %
        %   Syntax:
        %   writePWMDutyCycle(obj,pin,dutyCycle)
        %
        %   Description:
        %   Set the specified duty cycle on the specified PWM pin.
        %
        %   Input Arguments:
        %   obj       - Low Cost Hardware Object
        %   pin       - Digital pin number on the hardware (character vector or string)
        %   dutyCycle - PWM signal duty cycle to write to the PWM pin (double).
        %
        %   See also writeDigitalPin, writePWMVoltage

        % For number of input arguments less than 3 throw error
            coder.internal.errorIf(nargin < 3, 'MATLAB:minrhs');
            dutyCycle = obj.validatePWMDutyCycle(dutyCycle);
            obj.writePWMDutyCycleHook(pin, dutyCycle);
        end
    end

    methods(Sealed, Access = protected)
        function voltageRange = getPWMVoltageRange(obj)
            voltageRange = obj.getPWMVoltageRangeImpl();
        end

        function voltage = validatePWMVoltage(~, volt, voltRange)
            if isnumeric(volt) && isscalar(volt)
                coder.internal.assert(volt >= voltRange(1) && volt <=voltRange(2), 'MATLAB:hwsdk:general:invalidPWMValue',...
                                      'voltage', [num2str(voltRange(1)) ' - ' num2str(voltRange(2))]);
                % Clip the input voltage value between lower and higher
                % bound of reference voltage
                voltage = max(voltRange(1), min(volt, voltRange(2)));
            else
                % Throw compile time error.
                coder.internal.errorIf(true, 'MATLAB:hwsdk:general:invalidPWMType', 'voltage',...
                                       [num2str(voltRange(1)) ' - ' num2str(voltRange(2))]);
            end
        end

        function dutyCycle = validatePWMDutyCycle(~, duty)
            if isnumeric(duty) && isscalar(duty)
                % Throw compile time error
                coder.internal.errorIf(duty < 0 || duty > 1, 'MATLAB:hwsdk:general:invalidPWMValue', 'duty cycle', '0 - 1');
                % In run time since it is not possible to throw error, duty
                % cycle value is clipped between 0 and 1.
                dutyCycle = max(0,min(1, duty));
            else
                coder.internal.errorIf(true, 'MATLAB:hwsdk:general:invalidPWMType', 'duty cycle', '0 - 1');
            end
        end
    end

    methods(Access = protected)
        function writePWMDutyCycleHook(obj, pin, dutyCycle)
            pinNumber = obj.validatePWMPinNumberHook(pin);
            coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.DefaultTimerPin , 'MATLAB:hwsdk:general:defaultTimerPinCodegen', pin);
            coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidPWMPinNumberCodegen', pin);
            % This is generic implementation. Target author should overload
            % this method for target specific implementation
            setPWMDutyCycleInternal(obj.PWMDriverObj, dutyCycle*100);
        end
    end

    methods(Access = public)
        function pinNumber = validatePWMPinNumberHook(~, pin)
            pinNumber = pin;
        end
    end
end
