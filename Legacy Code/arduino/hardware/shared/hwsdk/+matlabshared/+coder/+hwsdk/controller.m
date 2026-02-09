classdef controller < handle
%

% Copyright 2019-2022 The MathWorks, Inc.

%#codegen
    methods(Abstract, Access = protected)
        % This function should return the hardware board name in string or
        % character array
        boardName = getBoardNameImpl(obj);
    end

    methods(Sealed, Access = public)
        function varargout = configurePin(obj, pin, config)
        % For number of input arguments less than 3 throw error
            coder.internal.errorIf(nargin < 3, 'MATLAB:minrhs');
            coder.internal.errorIf(nargout>0, 'MATLAB:hwsdk:general:maxlhs');
            % Validate if the mode provided is correct
            if isstring(config)
                configChar = char(config);
            else
                configChar = config;
            end
            if ~isempty(configChar)
                validModes = {'AnalogInput', 'PWM', 'DigitalInput', 'DigitalOutput', 'PullUp', ...
                              'I2C', 'SPI', 'Unset'};
                mode = validatestring(configChar, validModes, 'configurePin', 'mode');
            else
                % Empty mode indicates 'Unset'.
                mode = 'Unset';
            end
            configurePinHook(obj, pin, mode);
            varargout{1} = {};
        end

        function deviceObj = device(parentObj, varargin)
            deviceObj = getDeviceHook(parentObj, parentObj, varargin{:});
        end
    end

    methods(Hidden)
        function availablePrecisions = getAvailablePrecisions(obj)
            availablePrecisions = obj.getAvailablePrecisionsHook();
        end

        function boardName = getBoardName(obj)
            boardName = getBoardNameImpl(obj);
            validateattributes(boardName, {'char', 'string'}, {}, '', 'board name');
        end
    end

    methods (Access = protected)
        function configurePinHook(obj, pin, mode)
        % Based on the configuration type call functions on that
        % particular peripheral object
            if(strcmpi(mode, 'AnalogInput'))
                pinNumber = validateAnalogPinNumberHook(obj, pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidADCPinNumberCodegen', pin);
                configureAnalogInSingleInternal(obj.AnalogObj, pinNumber);

            elseif (strcmpi(mode, 'PWM'))
                pinNumber = validatePWMPinNumberHook(obj, pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.DefaultTimerPin , 'MATLAB:hwsdk:general:defaultTimerPinCodegen', pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidPWMPinNumberCodegen', pin);
                configurePWMPinInternal(obj.PWMDriverObj, pinNumber, 0, 0);

            elseif (strcmpi(mode, 'DigitalInput'))
                pinNumber = validateDigitalPinNumberHook(obj, pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidDigitalPinNumberCodegen', pin);
                configureDigitalPinInternal(obj.DigitalIODriverObj, pinNumber, matlabshared.devicedrivers.internal.SVDTypes.MW_Input);

            elseif (strcmpi(mode, 'DigitalOutput'))
                pinNumber = validateDigitalPinNumberHook(obj, pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidDigitalPinNumberCodegen', pin);
                configureDigitalPinInternal(obj.DigitalIODriverObj, pinNumber, matlabshared.devicedrivers.internal.SVDTypes.MW_Output);

            elseif (strcmpi(mode, 'PullUp'))
                pinNumber = validateDigitalPinNumberHook(obj, pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidDigitalPinNumberCodegen', pin);
                % number 2 indicates pullup. Add a new entry to the
                % enumeration and C function should accept this as an input
                configureDigitalPinInternal(obj.DigitalIODriverObj, pinNumber, matlabshared.devicedrivers.internal.SVDTypes.MW_Input_PullUp);

            elseif (strcmpi(mode, 'Unset'))
                pinNumber = validatePinNumberHook(obj, pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidPinNumberCodegen', pin);
                configureUnsetHook(obj, pinNumber);

            elseif (strcmpi(mode, 'I2C'))
                pinNumber = validateI2CPinNumberHook(obj, pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidI2CPinNumberCodegen', pin);
                % No action needs to be taken for I2C
            elseif (strcmpi(mode, 'SPI'))
                pinNumber = validateSPIPinNumberHook(obj, pin);
                coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidSPIPinNumberCodegen', pin);
                % No action needs to be taken for SPI
            else
                coder.internal.errorIf(true, 'MATLAB:hwsdk:general:invalidPinModeCodegen', mode);
            end
        end

        function configureUnsetHook(~, ~)
        % To implement 'Unset' mode, a resource manager is required to
        % remember the previous configuration. However, some targets
        % might have a generic implementation irrespective of the
        % previous mode.
        end

        function deviceObj = getDeviceHook(~, varargin)
            parms = struct('SerialPort', uint32(0), 'SPIChipSelectPin', uint32(0), 'Bus', uint32(0), 'ActiveLevel', uint32(0), ...
                           'SPIMode', uint32(0), 'BitOrder', uint32(0), 'BitRate', uint32(0), 'I2CAddress', uint32(0));
            poptions = struct('CaseSensitivity',false, 'PartialMatching','unique', ...
                              'StructExpand',false);
            % First element is hardware object
            pstruct = coder.internal.parseParameterInputs(parms,poptions,varargin{2:end});
            % Throw error if neither SPIChipSelectPin nor I2CAddress is
            % passed as an N-V pair arguments in device method
            coder.internal.errorIf(pstruct.SPIChipSelectPin == 0 && pstruct.I2CAddress == 0 && pstruct.SerialPort == 0,...
                                   'MATLAB:hwsdk:general:requiredNVPairName', ...
                                   'device', 'SPIChipSelectPin, I2CAddress, SerialPort');
            if pstruct.I2CAddress ~=0
                deviceObj = matlabshared.coder.i2c.device(varargin{:});
            elseif pstruct.SPIChipSelectPin ~=0
                deviceObj = matlabshared.coder.spi.device(varargin{:});
            else
                deviceObj = matlabshared.coder.serial.device(varargin{:});
            end
        end

        function precisions = getAvailablePrecisionsHook(~)
        % This can be used by I2C and Serial
            precisions = {'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'};
        end
    end


    methods(Access = public)
        function pinNumber = validatePinNumberHook(~, pin)
            pinNumber = pin;
        end
    end
end
