classdef controller < matlabshared.dio.controller_base
% HWSDK Digital IO controller
%
% All the methods and hooks to interface HWSDK to IOSERVER are implemented here
%
% Available methods Syntax:
%       data = readDigitalPin(obj, pin); % Reads a Digital Pin
%       writeDigitalPin(obj, pin, data); % writes to a Digital Pin
% Input Arguments:
%       obj = Object belonging to target class which inherits from dio.controller (Eg: 'a')
%       pin = pin to perform read or write operation on (Eg: 'D13')
%       data = logical 1/0 or true/false to be written to pin or read from the digital pin

% Copyright 2017-2023 The MathWorks, Inc.
    properties(GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableDigitalPins
    end

    properties(Access = ?matlabshared.hwsdk.internal.base)
        % This property holds the Digital IO driver object that provides
        % internal APIs for IO and code generation
        DigitalIODriverObj = matlabshared.ioclient.peripherals.DigitalIO;
    end

    methods
        % HWSDK displays a string array. Some hardware might require a
        % different type of display. Since a Getter cannot be
        % inherited, a trip is provided here which the individual hardware
        % can make use of.
        function availablePins = get.AvailableDigitalPins(obj)
            availablePins =  getAvailableDigitalPinsForPropertyDisplayHook(obj, obj.AvailableDigitalPins);
        end
    end

    methods(Access = protected)
        % Hardware inherits this method to modify the property display
        function availableDigitalPins = getAvailableDigitalPinsForPropertyDisplayHook(~, pins)
            availableDigitalPins = pins;
        end
    end

    methods (Access = private, Static = true)
        function name = matlabCodegenRedirect(~)
        % During codegen this class will be replaced by
        % matlabshared.coder.dio.controller by MATLAB
            name = 'matlabshared.coder.dio.controller';
        end
    end

    methods(Access = public, Hidden)
        function obj = controller(varargin)
        end
    end

    methods(Access = public)
        function data = readDigitalPin(obj, pin)
        %   Read digital pin value.
        %
        %   Syntax:
        %   value = readDigitalPin(obj,pin)
        %
        %   Description:
        %   Reads logical value from the specified pin on the Arduino hardware.
        %
        %   Input Arguments:
        %   obj - Low cost hardware object
        %   pin - Digital pin number on the Arduino hardware (character vector or string)
        %
        %   Output Arguments:
        %   value - Digital (0, 1) value acquired from digital pin (double)
        %
        %   See also writeDigitalPin

        % Register on clean up for integrating all data.
            if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                if nargin < 2
                    pin = "NA";
                end
                c = onCleanup(@() integrateData(obj, pin));
            end
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                pin = validateDigitalPin(obj, pin);
                configureControllerPin(obj, pin, "readDigitalPin");
                data = obj.readDigitalPinHook( pin);
            catch e
                obj.throwCustomErrorHook(e);
            end
        end

        function writeDigitalPin(obj, pin, data)
        %   Set or Reset a digital pin.
        %
        %   Syntax:
        %   writeDigitalPin(obj,pin,value)
        %
        %   Description:
        %   Writes specified value to the specified pin on the Arduino hardware.
        %
        %   Input Arguments:
        %   obj   - Low cost hardware object
        %   pin   - Digital pin number on the hardware (character vector or string)
        %   value - Digital value (0, 1) or (true, false) to write to the specified pin (double).
        %
        %   See also readDigitalPin, writePWMVoltage, writePWMDutyCycle

        % Register on clean up for integrating all data.
            if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                if nargin < 2
                    pin = "NA";
                    data = "NA";
                elseif nargin < 3
                    data = "NA";
                end
                c = onCleanup(@() integrateData(obj, pin, data));
            end
            try
                if (nargin < 3)
                    obj.localizedError('MATLAB:minrhs');
                end
                pin = validateDigitalPin(obj, pin);
                data = matlabshared.hwsdk.internal.validateDigitalParameter(data);
                configureControllerPin(obj, pin, "writeDigitalPin");
                obj.writeDigitalPinHook(pin, data);
            catch e
                obj.throwCustomErrorHook(e);
            end
        end
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})
        function availableDigitalPins = getAvailableDigitalPins(obj)
            availableDigitalPins = getAvailableDigitalPinsImpl(obj);
            assert(size(availableDigitalPins, 1)==1, ...    % row based... && isstring(availableDigitalPins), ...
                   'ASSERT: getAvailableDigitalPinsImpl must return a row based array of strings');
        end

        function pin = validateDigitalPin(obj, pin)
            try
                pin = validateControllerPin(obj.PinValidator, pin, obj.getAvailableDigitalPins(), obj.getBoardNameHook());
            catch e
                if isa(obj.PinValidator, 'matlabshared.hwsdk.internal.StringValidator')
                    switch e.identifier
                      case 'MATLAB:hwsdk:general:invalidPinNumber'
                        if isempty(getPinAliasHook(obj, pin))
                            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidPinNumber', char(obj.getBoardNameHook()), char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(obj.getAvailableDigitalPins())));
                        end
                      otherwise
                        throwAsCaller(e);
                    end
                else
                    throwAsCaller(e);
                end
            end
        end
    end

    methods(Access = protected)
        function data = readDigitalPinHook(obj, pin)
            pinNumber = obj.getPinNumber(pin);
            % ReadDigitalIO internally calls the corresponding IO Client
            % method
            % devicedrivers returns logical data, whereas HwSDK returns
            % double data
            [data, status] = obj.DigitalIODriverObj.readDigitalPinInternal(obj.Protocol, pinNumber);
            throwIOProtocolExceptionsHook(obj, 'readDigitalPinInternal', status);
        end

        function writeDigitalPinHook(obj, pin, value)
            pinNumber = obj.getPinNumber(pin);
            % writeDigitalIO internally calls the corresponding IO Client
            % method
            status = obj.DigitalIODriverObj.writeDigitalPinInternal(obj.Protocol, pinNumber, value);
            throwIOProtocolExceptionsHook(obj, 'writeDigitalPinInternal', status);
        end
    end

end
