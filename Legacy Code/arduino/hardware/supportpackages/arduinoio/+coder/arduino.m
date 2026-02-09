classdef arduino < matlabshared.coder.hwsdk.controller &...
        matlabshared.coder.dio.controller & matlabshared.coder.adc.controller ...
        & matlabshared.coder.pwm.controller & matlabshared.coder.i2c.controller ...
        & matlabshared.coder.spi.controller & matlabshared.coder.serial.controller...
        & matlabshared.sensors.coder.matlab.SensorCodegenUtilities
%

% Copyright 2019-2022 The MathWorks, Inc.

%#codegen

    properties (Access = protected)
        PinMap = [];
        Aref;
    end

    properties(Access = private, Constant)
        % I2C BitRate Range for Arduino 100kHz to 400kHz
        I2CBitRate = [100000 400000];

        % Since all the supported boards have SPI Bus ID as 1, adding this
        % as a constant property in this class. If in future, if other bus
        % ids are also supported, then PinMap class for each board should
        % have a constant property with the same name.
        SPIBusID = 1;
    end

    methods(Sealed, Access = public)
        function obj = arduino(varargin)
        % arduino constructor is not supposed to take any input.
        % varargin is added to detect the presence of input arguments
        % to throw proper error.
            coder.internal.errorIf(nargin>0, 'MATLAB:maxrhs');
            obj.DigitalIODriverObj = arduinodriver.ArduinoDigitalIO();
            obj.AnalogObj = arduinodriver.ArduinoAnalogInput();
            obj.PWMDriverObj = matlabshared.devicedrivers.coder.PWM();
            arduinodriver.arduinoPWMAddLibrary();
            obj.SPIDriverObj = arduinodriver.ArduinoSPI();

            % The pin map will be dynamically created and assigned during
            % codegen depending on the board.
            coder.extrinsic('codertarget.arduinobase.internal.getArduinoTargetName');
            coder.extrinsic('getActiveConfigSet');
            % Check if code is being generated from a MATLAB Function block
            % inside a Simulink block. Otherwise, throw error as generating
            % code from a script using MATLAB Coder is not supported.
            coder.internal.errorIf(isempty(coder.const(getActiveConfigSet(bdroot))), ...
                                   'MATLAB:arduinoio:general:unsupportedFunction', 'arduino');
            % Find out which Arduino board is currently being used. Based
            % on that the set of pin numbers are provided.
            platform = coder.const(codertarget.arduinobase.internal.getArduinoTargetName);
            obj.PinMap = codertarget.arduinobase.internal.ArduinoPinMap(platform);

            % Set the analog reference voltage based on the board
            switch(platform)
              case {'Arduino Due', 'Arduino MKR1000', 'Arduino MKR WiFi 1010', 'Arduino MKRZero'}
                obj.Aref = 3.3;
                obj.Resolution = 12;
              otherwise
                obj.Aref = 5;
                obj.Resolution = 10;
            end
            switch(platform)
              case 'Arduino Due'
                % Two objects for two modules on Arduino Due. Each
                % module is associated with a MW_I2C_Handle.
                obj.I2CDriverObj = {arduinodriver.ArduinoI2C, arduinodriver.ArduinoI2C};
              otherwise
                obj.I2CDriverObj = {arduinodriver.ArduinoI2C};
            end
        end
    end

    %% Methods from hwsdk coder controller class

    methods(Access = protected)

        function configureUnsetHook(obj, pinNumber)
        % For Arduino, 'Unset' mode configures a pin to 'DigitalInput'
        % mode. Take care when playTone is supported
            configureDigitalPinInternal(obj.DigitalIODriverObj, pinNumber, SVDTypes.MW_Input);
        end

        function deviceObj = getDeviceHook(~, varargin)
            parms = struct('SerialPort', uint32(0), 'BaudRate', uint32(0), 'DataBits', uint32(0), ...
                           'Parity', uint32(0), 'StopBits', uint32(0), 'Timeout', uint32(0),...
                           'SPIChipSelectPin', uint32(0), 'Bus', uint32(0), 'ActiveLevel', uint32(0), ...
                           'SPIMode', uint32(0), 'BitOrder', uint32(0), 'BitRate', uint32(0), 'I2CAddress', uint32(0));
            poptions = struct('CaseSensitivity',false, 'PartialMatching','unique', ...
                              'StructExpand',false);
            % First element is hardware object
            pstruct = coder.internal.parseParameterInputs(parms,poptions,varargin{2:end});
            % Throw error if neither SPIChipSelectPin nor I2CAddress is
            % passed as an N-V pair arguments in device method
            coder.internal.errorIf(pstruct.SPIChipSelectPin == 0 && pstruct.I2CAddress == 0 && pstruct.SerialPort == 0,...
                                   'MATLAB:hwsdk:general:requiredNVPairName', 'device', 'SPIChipSelectPin, I2CAddress, SerialPort');
            if pstruct.I2CAddress ~= 0
                deviceObj = matlabshared.coder.i2c.device(varargin{:});
            elseif pstruct.SPIChipSelectPin ~= 0
                % This is a temporary change to tackle the incompatibility
                % of Arduino Simulink target. This will be removed as soon
                % as Arduino targets C driver is updated.
                deviceObj = coder.arduino.spi.device(varargin{:});
            elseif pstruct.SerialPort ~= 0
                deviceObj = coder.arduino.serial.device(varargin{:});
            else
                % parser should throw an error before reaching this point.
                deviceObj = [];
            end
        end

        function boardName = getBoardNameImpl(~)
            coder.extrinsic('codertarget.arduinobase.internal.getArduinoTargetName');
            boardName = coder.const(codertarget.arduinobase.internal.getArduinoTargetName);
        end
    end

    %% Hardware specific validation from HWSDK peripheral classes
    methods(Access = public)
        function pinNumber = validateAnalogPinNumberHook(obj, pin)
            if isempty(pin)
                pinNumber = uint8(matlabshared.coder.internal.CodegenID.PinNotFound);
                return;
            end
            % For Arduino Leonardo and Micro A6-A11 modules are actually on
            % digital pins. It returns the actual pin number for these
            % modules
            % Ideally, Digital IO should also be configured on the same
            % pin. But for Arduino the pinMode is same for analog input and
            % digital input. Also, Digital IO module does not use handle
            % map. So digital configuration is not required.
            if isa(obj.PinMap.pinMapObj, 'codertarget.arduinobase.internal.pinMaps.Leonardo')...
                    || isa(obj.PinMap.pinMapObj, 'codertarget.arduinobase.internal.pinMaps.Micro')
                ADCModuleOnDigitalPins = {'D4', 'D6', 'D8', 'D9', 'D10', 'D12'};
                ADCPinNo = uint8(24:29);
                for i = 1: numel(ADCModuleOnDigitalPins)
                    if strcmpi(pin, ADCModuleOnDigitalPins{i})
                        pinNumber = ADCPinNo(i);
                        return;
                    end
                end
            end
            pinNumber = obj.PinMap.validateAnalogPinNumberHook(pin);
        end

        function pinNumber = validatePWMPinNumberHook(obj, pin)
            if isempty(pin)
                pinNumber = uint8(matlabshared.coder.internal.CodegenID.PinNotFound);
                return;
            end
            pinNumber = obj.PinMap.validatePWMPinNumberHook(pin);
        end

        function pinNumber = validateDigitalPinNumberHook(obj, pin)
            if isempty(pin)
                pinNumber = uint8(matlabshared.coder.internal.CodegenID.PinNotFound);
                return;
            end
            % For arduino both analog and digital pins can be used as
            % digital
            pinNumber = obj.PinMap.validateDigitalPinNumberHook(pin);
            if pinNumber == uint8(matlabshared.coder.internal.CodegenID.PinNotFound)
                pinNumber = obj.PinMap.validateAnalogPinNumberHook(pin);
            end
        end

        function pinNumber = validateI2CPinNumberHook(obj, pin)
            if isempty(pin)
                pinNumber = uint8(matlabshared.coder.internal.CodegenID.PinNotFound);
                return;
            end
            % For I2C, it has to be checked if the pin is actually a valid
            % I2C pin. For arduino, the I2C pins available for
            % configuration are actually a digital pin.
            pinNumber = obj.validateDigitalPinNumberHook(pin);
            if pinNumber ~= uint8(matlabshared.coder.internal.CodegenID.PinNotFound)
                % If the pin is a valid digital pin, then verify if I2C
                % module is connected to those pins
                pinNumber = obj.PinMap.validateI2CPinNumber(pinNumber);
            end
        end

        function pinNumber = validateSPIPinNumberHook(obj, pin)
            if isempty(pin)
                pinNumber = uint8(matlabshared.coder.internal.CodegenID.PinNotFound);
                return;
            end
            % For SPI, it has to be checked if the pin is actually a valid
            % SPI pin. For arduino, the boards which has a SPI pin
            % externally, is a digital pin also.
            pinNumber = obj.validateDigitalPinNumberHook(pin);
            if pinNumber ~= uint8(matlabshared.coder.internal.CodegenID.PinNotFound)
                % If the pin is a valid digital pin, then verify if I2C
                % module is connected to those pins
                pinNumber = obj.PinMap.validateSPIPinNumber(pinNumber);
            end
        end

        function pinNumber = validatePinNumberHook(obj, pin)
            if isempty(pin)
                pinNumber = uint8(matlabshared.coder.internal.CodegenID.PinNotFound);
                return;
            end
            pinNumber = obj.PinMap.validatePinNumberHook(pin);
        end
    end

    %% From Sensor utility class
    methods(Access = protected)

        function timestamp = getCurrentTimeImpl(~)
        % Returns time since the beginning of program execution in
        % milliseconds.
            if coder.target('rtw')
                time = coder.nullcopy(0);
                time = coder.ceval('millis');
                timestamp = double(time)/1000;
            else
                % During mex creation do not call Arduino APIs
                timestamp = 0;
            end
        end

        function addExternalLibraryHook(obj)
        % Include external C/C++ library
            arduinodriver.ArduinoI2CAddLibrary();
            addExtraFiles(obj);
        end
    end

    methods(Access = private)
        function addExtraFiles(~)
            spkgrootDir = codertarget.arduinobase.internal.getBaseSpPkgRootDir;
            % Include Paths
            addIncludePaths(buildInfo, fullfile(spkgrootDir, 'include'));
            addIncludeFiles(buildInfo,'io_wrappers.h');
            % Source Files
            systemTargetFile = get_param(buildInfo.ModelName,'SystemTargetFile');
            if isequal(systemTargetFile,'ert.tlc')
                % Add the following when not in rapid-accel simulation
                addSourcePaths(buildInfo, fullfile(spkgrootDir,'src'));
                addSourceFiles(buildInfo,'io_wrappers.cpp', fullfile(spkgrootDir,'src'),'BlockModules');
            end
        end
    end

    %% Methods from ADC Coder controller class
    methods(Access = protected)
        function refVoltage = getReferenceVoltageImpl(obj)
        % Return refvoltage based on the Board
            refVoltage = obj.Aref;
        end
    end

    %% Methods from PWM Coder controller class
    methods(Access = protected)
        function voltageRange = getPWMVoltageRangeImpl(obj)
            voltageRange = obj.PinMap.getPWMVoltageRange;
        end

        function writePWMDutyCycleHook(obj, pin, dutyCycle)
            pinNumber = obj.validatePWMPinNumberHook(pin);
            coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.DefaultTimerPin , 'MATLAB:hwsdk:general:defaultTimerPinCodegen', pin);
            coder.internal.errorIf(pinNumber == matlabshared.coder.internal.CodegenID.PinNotFound, 'MATLAB:hwsdk:general:invalidPWMPinNumberCodegen', pin);
            % During codegen Arduino expects a range [0-255] for duty
            % cycle. Overloading this function as the original one sets a
            % range [0-100].
            setPWMDutyCycleInternal(obj.PWMDriverObj, pinNumber, uint8(dutyCycle*255));
        end
    end

    %% Methods from I2C controller class
    methods(Access = protected)
        function i2cDriverObj = getI2CDriverObjImpl(obj, busNum)
            i2cDriverObj = obj.I2CDriverObj{busNum+1};
            % Include external C/C++ library
            arduinodriver.ArduinoI2CAddLibrary();
        end

        function busIDs = getAvailableI2CBusIDsImpl(obj)
            busIDs = obj.PinMap.getAvailableI2CBusIDs();
        end

        function busId = getI2CBusInfoHook(~, HWSDKBusNum)
            busId = HWSDKBusNum;
        end

        function i2cBitRates = getI2CBitRateLimitHook(obj, ~)
            i2cBitRates = obj.I2CBitRate;
        end

        function maxI2CAddress = getMaxI2CAddressHook(~)
            maxI2CAddress = 119;
        end

        function minI2CAddress = getMinI2CAddressHook(~)
            minI2CAddress = 8;
        end
    end

    methods(Access = public, Hidden)
        function hwsdkDefaultI2CBusID = getHwsdkDefaultI2CBusIDHook(~)
            hwsdkDefaultI2CBusID = 0;
        end
    end

    %% Methods from SPI controller class
    methods(Access = protected)
        function spiBitRates = getSPIBitRatesImpl(~, ~)
            spiBitRates = 4e6;
        end

        function spiDriverObj = getSPIDriverObjHook(obj, ~)
            spiDriverObj = obj.SPIDriverObj;
            % Include external C/C++ library
            arduinodriver.ArduinoSPIAddLibrary();
        end

        function spiBusAlias = getSPIBusAliasHook(~, bus)
            spiBusAlias = bus-1;
        end

        function spiBusIDs = getAvailableSPIBusIDsImpl(obj)
            spiBusIDs = obj.SPIBusID;
        end
    end

    %% Methods from Serial controller class
    methods(Access = protected)
        function serialPinsArray = getAvailableSerialPinsImpl(~)
        % This function is not used for Arduino. Just filling with
        % dummy data.
            serialPinsArray = struct('TxPin', {0, 0, 0, 0}, 'RxPin', {0, 0, 0, 0});
        end

        function serialPorts = getAvailableSerialPortIDsHook(obj)
            serialPorts = getAvailableSerialPortIDs(obj.PinMap);
        end

        function serialDriverObj = getSerialDriverObjHook(~)
            serialDriverObj = arduinodriver.ArduinoSerial();
            % Include external C/C++ library
            arduinodriver.ArduinoSerialAddLibrary();
        end
    end

    methods (Access = public,Hidden)
        function delayFunctionForHardware(obj,factor)
        % This delay is interms of seconds. Factor represents number of seconds
            if coder.target('Rtw')% done only for code gen
                coder.cinclude('io_wrappers.h');
                coder.ceval('MW_delay_in_milliseconds', uint32(factor));
            end
        end
    end

    %% Implement methods which are not supported for code generation to throw proper error
    methods(Access = public)
        function servoObj = servo(~, ~, varargin)
            coder.internal.errorIf(true, 'MATLAB:arduinoio:general:unsupportedFunction', 'servo');
            servoObj = [];
        end
        function playTone(~, ~, varargin)
            coder.internal.errorIf(true, 'MATLAB:arduinoio:general:unsupportedFunction', 'playTone');
        end

        function register = shiftRegister(~, ~, ~, ~, varargin)
            coder.internal.errorIf(true, 'MATLAB:arduinoio:general:unsupportedFunction', 'shiftRegister');
            register = [];
        end

        function encoder = rotaryEncoder(~, ~, ~, varargin)
            coder.internal.errorIf(true, 'MATLAB:arduinoio:general:unsupportedFunction', 'rotaryEncoder');
            encoder = [];
        end

        function ultrasonicObj = ultrasonic(~, ~, varargin)
            coder.internal.errorIf(true, 'MATLAB:arduinoio:general:unsupportedFunction', 'ultrasonic');
            ultrasonicObj = [];
        end

        function mkrMCObj = addon(~, varargin)
            coder.internal.errorIf(true, 'MATLAB:arduinoio:general:unsupportedFunction', 'addon');
            mkrMCObj = [];
        end

        function addresses = scanI2CBus(~, ~)
        % This function is actually defined in I2C controller class for IO.
        % So, it should be defined in the I2C coder controller class. But
        % considering the code generation is to be enabled only for
        % Arduino, the function is put inside arduino class to avoid
        % creation of a new class just to throw an error.
            coder.internal.errorIf(true, 'MATLAB:arduinoio:general:unsupportedFunction', 'scanI2CBus');
            addresses = [];
        end
    end
end
