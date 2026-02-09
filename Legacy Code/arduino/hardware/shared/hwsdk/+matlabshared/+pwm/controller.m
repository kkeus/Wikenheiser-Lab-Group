classdef controller < matlabshared.pwm.controller_base
% HWSDK PWM controller
%
% All the methods and hooks to interface HWSDK to IOSERVER are implemented here
%
% Available methods Syntax:
%       writePWMVoltage(obj, pin, voltage); % Write PWM duty cycle
% Input Arguments:
%       obj = Object belonging to target class which inherits from pwm.controller
%   pin = Pin on which specified PWM duty cycle needs to be generated on (Eg: 'D13')
%   voltage = Voltage of digital pin's PWM specified as number between 0 and reference volts
%
% Available methods Syntax:
%       writePWMDutyCycle(obj, pin, dutyCycle); % Write PWM duty cycle
% Input Arguments:
%       obj = Object belonging to target class which inherits from pwm.controller
%   pin = Pin on which specified PWM duty cycle needs to be generated on (Eg: 'D13')
%   dutyCycle = Value of digital pin's PWM duty cycle specified as number between 0 and 1.

%   Copyright 2017-2023 The MathWorks, Inc.

    properties(GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailablePWMPins
    end

    properties(Access = ?matlabshared.hwsdk.internal.base)
        PWMDriverObj = matlabshared.ioclient.peripherals.PWM;
    end

    methods
        % HWSDK displays a string array. Some hardware might require a
        % different type of display. Since a Getter cannot be
        % inherited, a trip is provided here which the individual hardware
        % can make use of.
        function availablePins = get.AvailablePWMPins(obj)
            availablePins =  getAvailablePWMPinsForPropertyDisplayHook(obj, obj.AvailablePWMPins);
        end
    end

    methods(Access = protected)
        % Hardware inherits this method to modify the property display
        function availableDigitalPins = getAvailablePWMPinsForPropertyDisplayHook(~, pins)
            availableDigitalPins = pins;
        end
    end

    methods(Access = public, Hidden)
        function obj = controller()
        end
    end

    methods (Access = private, Static = true)
        function name = matlabCodegenRedirect(~)
        % Codegen redirector class. During codegen this class will be
        % replaced by matlabshared.coder.controller.controller by MATLAB
            name = 'matlabshared.coder.pwm.controller';
        end
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

        % Register on clean up for integrating all data.
            if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                if nargin < 2
                    pin = "NA";
                    voltage = "NA";
                elseif nargin < 3
                    voltage = "NA";
                end
                c = onCleanup(@() integrateData(obj, pin, voltage));
            end
            try
                if nargin < 3
                    obj.localizedError('MATLAB:minrhs');
                end
                pin = validatePWMPin(obj, pin);
                voltageRange = obj.getPWMVoltageRange();
                range = voltageRange(2) - voltageRange(1);
                voltage = obj.validatePWMVoltage(voltage, voltageRange);
                dutyCycle = voltage/range;
                configureControllerPin(obj, pin, "writePWMVoltage");
                obj.writePWMDutyCycleHook(pin, dutyCycle);
            catch e
                obj.throwCustomErrorHook(e);
            end
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

        % Register on clean up for integrating all data.
            if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                if nargin < 2
                    pin = "NA";
                    dutyCycle = "NA";
                elseif nargin < 3
                    dutyCycle = "NA";
                end
                c = onCleanup(@() integrateData(obj, pin, dutyCycle));
            end
            try
                if nargin < 3
                    obj.localizedError('MATLAB:minrhs');
                end
                pin = validatePWMPin(obj, pin);
                dutyCycle = obj.validatePWMDutyCycle(dutyCycle);
                configureControllerPin(obj, pin, "writePWMVoltage");
                obj.writePWMDutyCycleHook(pin, dutyCycle);
            catch e
                obj.throwCustomErrorHook(e);
            end
        end
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})
        function availablePWMPins = getAvailablePWMPins(obj)
            availablePWMPins = obj.getAvailablePWMPinsImpl();
            % row based
            assert(size(availablePWMPins, 1)==1, 'ASSERT: getAvailablePWMPinsImpl must return a row based array of strings');
            validatePWMPinType(obj.PinValidator, availablePWMPins);
        end

        function voltageRange = getPWMVoltageRange(obj)
            voltageRange = obj.getPWMVoltageRangeImpl();
            assert(all(size(voltageRange)==[1 2]));    % 1x2 range
            assert(isnumeric(voltageRange));
        end

        function pin = validatePWMPin(obj, pin)
            pin = validateControllerPin(obj.PinValidator, pin, obj.getAvailablePWMPins(), obj.getBoardNameHook());
            % No alias pin for PWM.
        end

        function voltage = validatePWMVoltage(obj, volt, voltRange)
            try
                validateattributes(volt,{'numeric'},...
                                   {'scalar','real','finite'},'','volt');
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidPWMType', 'voltage', [num2str(voltRange(1)) ' - ' num2str(voltRange(2))]);
            end
            if (volt < voltRange(1) || volt > voltRange(2))
                obj.localizedError('MATLAB:hwsdk:general:invalidPWMValue', 'voltage', [num2str(voltRange(1)) ' - ' num2str(voltRange(2))]);
            else
                voltage = volt;
            end
        end

        function dutyCycle = validatePWMDutyCycle(obj, duty)
            try
                validateattributes(duty,{'numeric'},...
                                   {'scalar','real','finite'},'','duty');
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidPWMType', 'duty cycle', '0 - 1');
            end
            if duty < 0 || duty > 1
                obj.localizedError('MATLAB:hwsdk:general:invalidPWMValue', 'duty cycle', '0 - 1');
            else
                dutyCycle = duty;
            end
        end
    end

    methods(Access = protected)
        function writePWMDutyCycleHook(obj, pin, dutyCycle)
            pinNumber = obj.getPinNumber(pin);
            status = setPWMDutyCycleInternal(obj.PWMDriverObj, obj.Protocol, pinNumber, dutyCycle);
            throwIOProtocolExceptionsHook(obj, 'setPWMDutyCycleInternal', status);
        end
    end
end
