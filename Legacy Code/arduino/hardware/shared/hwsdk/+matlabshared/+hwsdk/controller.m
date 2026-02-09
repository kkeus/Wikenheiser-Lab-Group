classdef controller < matlabshared.hwsdk.controller_base &...
        matlab.mixin.CustomDisplay

% hwsdk controller class

%   Copyright 2017-2024 The MathWorks, Inc.

    properties(GetAccess = public, SetAccess = private)
        AvailablePins string
    end

    properties(Access = private, Constant = true)
        Group = 'MATLAB_HARDWARE'
        Prefix = 'MATLABIO_'
    end

    properties(Hidden, SetAccess = private)
        Pref
        Args

        %Type and Object of communication between Hardware and host
        ConnectionType matlabshared.hwsdk.internal.ConnectionTypeEnum
        ConnectionController matlabshared.hwsdk.internal.connections.ConnectionController

        %Display debug trace of commands executed on Arduino hardware
        TraceOn

        %Force compile and download of Arduino server.
        ForceBuildOn

        %Flag of whether uploading a library or not
        LibrariesSpecified
    end

    properties(Access = private, Constant = true)
        % major release/minor release - 25a
        LibVersion = '25.1.0';
    end

    properties(Access = private)
        IsInitialized = false;
        Connection = [];
        ResourceOwner = [];
        DefaultBaudRate = 115200;
        DefaultTCPIPPort = 9500;
        %Default service UUID to search BLE devices setup with MW infra, same as that specified
        %in IOServer
        ServiceUUID = 'BEC069d9-E1DC-49C4-8A05-F24198ED6E57'
        PinModeMap
    end

    properties(Access = {?matlabshared.hwsdk.internal.base,?matlabshared.sensors.MultiStreamingUtilities})
        Protocol = [];
    end

    properties(Access = protected)
        % Flag to indicate whether the hardware is storing debug messages
        % on the host or not
        IsDebugObjectRequired = 0;
    end

    methods
        % HWSDK displays a string array. Some hardware might require a
        % different type of display. Since a Getter cannot be
        % inherited, a trip is provided here which the individual hardware
        % can make use of.
        function availablePins = get.AvailablePins(obj)
            availablePins =  getAvailablePinsForPropertyDisplayHook(obj, obj.AvailablePins);
        end
    end

    methods(Access = protected)
        % Hardware inherits this method to modify the property display
        function availablePins = getAvailablePinsForPropertyDisplayHook(~, pins)
            availablePins = pins;
        end
    end

    methods (Access = private, Static = true)
        function name = matlabCodegenRedirect(~)
        % Codegen redirector class. During codegen the current class
        % will be replaced by matlabshared.coder.hwsdk.controller by
        % MATLAB
            name = 'matlabshared.coder.hwsdk.controller';
        end
    end

    methods(Sealed, Access = public)
        function varargout = configurePin(obj, pin, varargin)
            try
                % configurePin can be called with and without config mode,
                % adding following logic for data integration for both of
                % the function calls. This parameter is responsible for
                % integrating config mode.
                if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    if  nargin == 3
                        dconfig = varargin{1};
                    else
                        dconfig = 'NA';
                    end

                    % Register on clean up for integrating all data.
                    if nargin >= 2
                        c = onCleanup(@() integrateData(obj, dconfig, pin));
                    else
                        c = onCleanup(@() integrateData(obj, dconfig));
                    end
                end
                if nargout > 1
                    obj.localizedError('MATLAB:maxlhs');
                end
                if (nargout > 0 && nargin > 2)
                    obj.localizedError('MATLAB:maxrhs');
                end
                if ~isPinNumericHook(obj) && isstring(pin)
                    pin = char(pin);
                end
                prevMode = obj.configurePinImpl(pin);
                if nargin ~= 2
                    % Writing pin configuration
                    % Get a map of pins and modes to be configured
                    obj.configurePinImpl(pin, varargin{:});
                    configurePinHardware(obj, prevMode);
                else
                    % Reading pin configuration
                    varargout = {prevMode};
                end
            catch e
                obj.throwCustomErrorHook(e);
            end
        end

        function obj = device(parentObj, varargin)
        %DEVICE  Create I2C, SPI or Serial device
        %
        %   Connect to the I2C device at the specified address on the I2C bus
        %
        %   [I2CDevice] = device(obj, 'I2CAddress', ADDRESS) returns
        %   I2C object and connects to an I2C device at the specified address on the default I2C bus of the Arduino hardware
        %
        %   [I2CDevice] = device(obj, 'I2CAddress', ADDRESS, 'NAME', 'VALUE')
        %   returns I2C object and connects to an I2C device at the specified address using  using one or more name-value pair arguments
        %
        %   Example:
        %   i2cDevice = device(obj, 'I2CAddress', address) Connects to an I2C device at the specified address on the default I2C bus of the Arduino hardware.
        %
        %   Examples:
        %       % Construct an arduino object
        %       a = arduino();
        %
        %       % Construct an I2C device object at I2CAddress '0x48'
        %       tmp102 = device(a,'I2CAddress','0x48');
        %
        %       % Construct microbit object
        %       m = microbit();
        %
        %       % Construct an I2C device object at I2CAddress '0x48'
        %       tmp102 = device(m,'I2CAddress','0x25','Bus',1);
        %
        %       % Construct an I2C device object at I2CAddress '0x48'
        %       and BitRate 100KHz
        %       tmp102 = device(a,'I2CAddress','0x48','BitRate',100000);
        %
        %       % Construct an I2C device object at I2CAddress '0x48',
        %       Bus 1 and BitRate 100KHz
        %       tmp102 = device(a,'I2CAddress','0x48','Bus',1,'BitRate',100000);
        %
        %   Connect to the SPI device enabled with a specified Chip Select Pin.
        %
        %   [SPIDevice] = device(obj, 'SPIChipSelectPin', PIN) returns SPI device object and connects to an SPI device enabled with a specified Chip Select Pin
        %   [SPIDevice] = device(obj, 'SPIChipSelectPin', PIN, 'NAME', 'VALUE')
        %   returns SPI device object and connects to an SPI device enabled with a specified Chip Select Pin using one or more name-value pairs
        %
        %   Examples:
        %       % Construct an arduino object
        %       a = arduino();
        %
        %       % Construct an SPI device object with 'D8' as ChipSelectPin
        %       eeprom = device(a,'SPIChipSelectPin','D8');
        %
        %       % Construct microbit object
        %       m = microbit();
        %
        %       % Construct an SPI device object with 'P16' as SPIChipSelectPin
        %       eeprom = device(m,'SPIChipSelectPin','P16');
        %
        %       % Construct SPI device object with 'D8' as ChipSelectPin and 100KHz Bit Rate
        %       eeprom = device(a,'SPIChipSelectPin','D8','BitRate',100000);
        %
        %       % Construct SPI device object with 'D8' as ChipSelectPin and ActiveLevel 'high'
        %       eeprom = device(a,'SPIChipSelectPin','D8','Activelevel','high');
        %
        %       % Construct SPI device object with 'D8' as ChipSelectPin and SPIMode 3
        %       eeprom = device(a,'SPIChipSelectPin','D8','SPIMode',3);
        %
        %       % Construct SPI device object with 'D8' as ChipSelectPin and BitOrder lsbfirst
        %       eeprom = device(a,'SPIChipSelectPin','D8','BitOrder','lsbfirst');
        %
        %   Connection to Serial device connected to TX and RX Pin of Arduino Board
        %
        %   [SERIALDEVICE]= device(obj, 'SerialPort', PORT) creates a connection to Serial Port PORT of the Arduino board and returns Serial device object
        %   [SERIALDEVICE]= device(obj, 'SerialPort', PORT) creates a connection to Serial Port PORT of the Arduino board using one or more name -value pairs and returns Serial device object
        %
        %   Examples:
        %       % Construct an arduino object
        %       a = arduino();
        %
        %       % Construct a Serial device object at Port 1
        %       dev1 = device(a,'SerialPort',1);
        %
        %       % Construct a Serial device object at Port 1 with 100KHz Baud Rate
        %       dev1 = device(a,'SerialPort',1,'BaudRate',100000);
        %
        %       % Construct a Serial device object at Port 1 with 8 Data Bits
        %       dev1 = device(a,'SerialPort',1,'DataBits',8);
        %
        %       % Construct a Serial device object at Port 1 with 1 Stop Bit
        %       dev1 = device(a,'SerialPort',1,'StopBits',1);
        %
        %       % Construct a Serial device object at Port 1 with even parity
        %       dev1 = device(a,'SerialPort',1,'Parity','even');
        %
        %   See also read, write, readRegister, writeRegister, writeRead

        % Register on clean up for integrating all data.
            if isa(parentObj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                c = onCleanup(@() integrateData(parentObj,varargin{:}));
            end
            try
                obj = getDeviceHook(parentObj, parentObj, varargin{:});
            catch e
                if isa(parentObj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(parentObj, e.identifier);
                end
                throwAsCaller(e);
            end
        end
    end

    methods(Hidden)
        % Needs to be callable from device factory (function) which can
        % return I2C, SPI or Serial devices.
        %
        function dev = getDevice(obj, varargin)
            dev = obj.getDeviceHook(varargin{:});
            assert(isa(dev, 'matlabshared.i2c.device') || ...
                   isa(dev, 'matlabshared.spi.device') || ...
                   isa(dev, 'matlabshared.serial.device'));
        end

        function varargout = configurePinInternal(obj, pin, config, varargin)
        % configures pin for all standard peripherals supported by
        % HWSDK
        % varargin{1} -> caller
        % varargin{2} -> Resource Owner

            try
                m = message('MATLAB:hwsdk:general:ConfigInternalOneOutput');
                assert(nargout <= 1, getString(m));

                if isstring(pin)
                    pin = char(pin);
                end
                varargout = {[]};
                prevMode = obj.configurePinImpl(pin);
                if nargin == 2
                    % Reading pin configuration
                    varargout = {prevMode};
                else
                    % Writing pin configuration
                    m = message('MATLAB:hwsdk:general:ConfigInternalCallerMust');
                    assert(nargin > 3, getString(m));
                    validateCaller(obj, varargin{1});
                    % Get a map of pins and modes to be configured
                    if nargout
                        % From HWSDK internal files while construction
                        varargout = {obj.configurePinImpl(pin, config, varargin{:})};
                    else
                        % From HWSDK internal files while destruction
                        obj.configurePinImpl(pin, config, varargin{:});
                    end
                    configurePinHardware(obj, prevMode);
                end
            catch e
                throwAsCaller(e);
            end
        end

        function validateCaller(obj, callerMethodID)
        % validates caller to be one of known methods of hardware obj
            allowedMethodNames = lower(methods(obj));
            % Find the position of last dot
            callerPosition = find(callerMethodID == '.', 1, "last");
            % Caller is the substring after the last dot.
            caller = string.empty;
            if ~isempty(callerPosition)
                caller = extractAfter(callerMethodID, callerPosition);
            end
            if isempty(caller) || any(ismissing(caller))
                % GPIO operations from HWSDK or some invalid
                % entry from user
                caller = callerMethodID;
            end
            assert(contains(lower(caller), allowedMethodNames), 'Caller invalid');
        end

        function status = getBLEConnectedStatus(obj)
        % property getter method for Connected property added
        % dynamically for BLE connection type
            assert(obj.ConnectionType== matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE);
            status = obj.Connection.IsTransportLayerConnectedHandle();
        end
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})
        function name = getHardwareName(obj)
            name = obj.getHarwdareNameImpl();
            assert(isstring(name));
            assert(size(name, 1) == 1);
            assert(size(name, 2) == 1);
        end

        function precisions = getAvailablePrecisions(obj)
            precisions = obj.getAvailablePrecisionsHook();
            assert(size(precisions, 1) == 1); % row based
            assert(all(ismember(precisions, matlabshared.hwsdk.internal.precisions)));
        end

        function pinNumber = getPinNumber(obj, pin)
            pinNumber = obj.getPinNumberImpl(pin);
            assert(isscalar(pinNumber) && isnumeric(pinNumber));
        end

        function pins = getAvailablePins(obj)
            pins = obj.getAvailablePinsImpl();
        end

        function initHardware(obj, varargin)
            % Note for MATLAB Online:
            % parseInputs has validation to handle serial port name on
            % machine running MATLAB Connector as input.
            obj.Args = parseInputs(obj, varargin{:});

            % Derive parameters if not specified by user inputs.
            % discoverDevices is going to assign valid Address and
            % ConnectionType.
            discoverDevices(obj);

            % Add dynamic properties according to connection type
            [addressKey, obj.Args] = addConnectionTypeProperties(obj.ConnectionController, obj);

            % Check if transport layer already occupied, or hardware connection already exists.
            validateConnection(obj.ConnectionController, addressKey);

            updateNonPeripheralProperties(obj);

            if (initHardwareBeforeServerConnectionHook(obj, obj.ConnectionType))
                initHardwareHook(obj);
                initServerConnection(obj);
            else
                initServerConnection(obj);
                initHardwareHook(obj);
            end

            updatePeripheralProperties(obj);

            % Update preference last to ensure preference is only
            % updated when an hardware object is successfully created
            if ~(ispref('MATLAB_HARDWARE','HostIOServerEnabled') && getpref('MATLAB_HARDWARE','HostIOServerEnabled'))
                updatePreferences(obj.ConnectionController, obj);
            end
        end
    end

    methods(Access = private)
        function args = parseInputs(obj, varargin)
        % Parse validate given inputs
            nInputs = numel(varargin);

            % Initialize this way instead of 'struct' to avoid empty struct
            args.Address = [];
            args.Libraries = {};
            args.TraceOn = [];
            args.ForceBuildOn = false;
            args.LibrariesSpecified = false;
            args.CustomParams = [];
            args.BaudRate = [];

            paramNames = obj.getCustomInputParameterNamesHook();
            assert(isstring(paramNames));
            nCustomParams = size(paramNames, 2);
            args = initializeCustomParams(obj, nCustomParams, args, paramNames);

            % No parameters to parse
            if nInputs == 0
                return;
            end

            % Step 1 - Derive connection type based on first input parameter
            iParam = 0;
            if nInputs > 0
                iParam = iParam + 1;
                [args.Address, args.Port] = obj.validateTransport(varargin{iParam});
            end

            % Step 2 - Get board parameter (Port and Board parameters are
            % required before specifying any parameter-value pairs)
            if nInputs > 1
                if nCustomParams > 0
                    if (obj.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial || ...
                        obj.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi)
                        assert(size(paramNames, 1) == 1); % row based
                        for paramName = paramNames
                            % Fetch only if input has enough data
                            if nInputs > iParam
                                iParam = iParam + 1;
                                customParams.(char(paramName)) = varargin{iParam};
                            end
                        end
                        args.CustomParams = obj.parseCustomInputParamsHook(customParams);
                        % port number will be updated only if it is given
                        % as a part of the customParams
                        if(isfield(args.CustomParams,'Port') && ~isempty(args.CustomParams.Port))
                            args.Port = args.CustomParams.Port;
                        end
                    else
                        % No configuration is allowed if connection type is BLE and Bluetooth
                        obj.localizedError('MATLAB:hwsdk:general:BoardNameParamUnSupported');
                    end
                end
            end

            % Step 3 - Parse additional NV parameters
            if nInputs > 1 + nCustomParams
                iParam = iParam + 1;
                args = parseAdditionalNVParameters(obj.ConnectionController, obj, iParam, args, nInputs, nCustomParams, char(getHarwdareNameImpl(obj)), varargin{:});
            end
        end

        function [flag, serverInfo]  = getServerInfo(obj)
            serverInfo.ioServerVersion = getCoreIOServerVersion(obj.Protocol); % IOServer version Number
            serverInfo.hwSPPKGVersion = getBoardIOServerVersion(obj.Protocol); % HWSPPKG + HWSDK version Number
            serverInfo.boardServerInfo = getBoardInfo(obj.Protocol);
            flag = ~isempty(serverInfo.ioServerVersion) && ~isempty(serverInfo.hwSPPKGVersion) && ~isempty(serverInfo.boardServerInfo);
        end

        function libraryList = extractLibrariesFromServerInfo(~,boardServerInfo)
            libList = boardServerInfo.LibraryList;
            libraryList = split(libList,',')';
            if strcmpi(libraryList,"") %If empty string convert to empty cell array, being handled throughout code for empty Libraries
                libraryList = {};
            end
        end

        function status = validateServerInfo(obj,varargin)
            if nargin < 2
                dispVersionError = false;
            else
                % Input specifies whether the hw is programmable or not.
                % Display version mismatch error only if HW is not
                % programmable.
                dispVersionError = ~varargin{1};
            end
            % Below code is a workaround for Arduino CLI's incapability
            % to report error code when another arduino board's port is
            % given for the current board
            status = false;
            if ispref('MATLAB_HARDWARE','Test_BuildOnly')
                % Call getBuildOnlyServerInfoHook for build only test
                [flag,serverInfo] = getBuildOnlyServerInfoHook(obj);
            else
                [flag, serverInfo]  = getServerInfo(obj);
            end
            flagLib = getLibraryAvailability(obj, flag, serverInfo);
            if isequal(obj.ConnectionType, matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial)
                serverTrace = getServerTraceInfoHook(obj,serverInfo.boardServerInfo.CustomData);
                serverBaudRate = str2double(extractAfter(extractBefore(serverInfo.boardServerInfo.CustomData,','),'  '));
                baudRate = obj.BaudRate;
            else
                serverTrace = obj.TraceOn;
                serverBaudRate = getDefaultBaudRate(obj);
                baudRate = getDefaultBaudRate(obj);
            end
            flagserverVersion = validateServerVersionHook(obj,serverInfo,obj.LibVersion);
            if ~flagserverVersion && dispVersionError
                obj.localizedError('MATLAB:hwsdk:general:invalidSPPKGVersion',char(obj.getHarwdareNameImpl),char(obj.getSPPKGBaseCodeImpl));
            end
            if obj.validateServerInfoHook(serverInfo.boardServerInfo) && ...
                    flag && ... % verify if server config is same as config specified by user to avoid rebuilding everytime
                    flagserverVersion && ...
                    flagLib && ... % check if Libraries on server are same as the ones specified
                    (serverTrace == obj.TraceOn) && ... % check if Trace value is same as what is specified
                    (serverBaudRate == baudRate)  % check with Baudrate is same as what is specified
                if isa(obj, 'matlabshared.addon.controller')
                    obj.LibraryIDs = 0:(length(obj.Libraries)-1); % assign LibIDs
                end
                status = true;
            end
        end

        function updateLibraryIDs(obj, libNames, libIDs)
            for whichLib = 1:numel(obj.Libraries)
                IndexC = strfind(libNames, obj.Libraries{whichLib});
                obj.LibraryIDs(whichLib) = libIDs(not(cellfun('isempty', IndexC)));
            end
        end

        function flag = initCommunication(obj, connectionObj)
            flag = false;
            try
                if isempty(obj.Protocol)
                    if(isprop(obj,'CheckSumEnable') && isequal(obj.CheckSumEnable,1))
                        obj.Protocol = matlabshared.ioclient.IOProtocol(connectionObj,'Checksum','enable');
                    else
                        obj.Protocol = matlabshared.ioclient.IOProtocol(connectionObj);
                    end
                    timeoutval = getIOProtocolTimeoutHook(obj);
                    setIOProtocolTimeout(obj.Protocol,timeoutval);
                    if(obj.IsDebugObjectRequired)
                        debugObj = getDebugObjectHook(obj);
                        if(~isempty(debugObj))
                            % If the hardware class does not implement the
                            % function hook, the return will be an empty
                            % array.
                            obj.Protocol.setDebugObj(debugObj);
                        end
                    end
                end
                resetDelay = obj.getResetDelayHook();
                if ispref('MATLAB_HARDWARE','Test_BuildOnly')
                    % Set the flag to true for build-only test
                    flag = true;
                else
                    flag = connect(obj.Protocol, resetDelay);
                end
            catch
            end
        end

        function updateServer(obj)
            if isa(obj, 'matlabshared.addon.controller')
                if ~obj.LibrariesSpecified
                    obj.Libraries = obj.getDefaultLibraries();
                end
                obj.Libraries = obj.validateLibraries(obj.Libraries); % check existence and completeness of libraries
                obj.LibraryIDs = 0:(length(obj.Libraries)-1);
            end

            obj.updateServerImpl();
        end

        function configurePinHardware(obj, prevMode)
        % Communicates with IOServer peripheral classes to update pin
        % configuration in Hardware
        % Fetch all pins from the map
            pinNumbers = keys(obj.PinModeMap);
            functionName = [];
            status = [];
            if ~isempty(pinNumbers)
                for pinNumber = pinNumbers                   % Configure every pin
                    pinNum = pinNumber{:};
                    pinPrevMode = prevMode;
                    for mode = obj.PinModeMap(pinNum)  % in all modes requested, sequentially
                        if ~strcmp(mode, pinPrevMode)
                            preHardwareConfigurationHook(obj, pinPrevMode, mode, pinNum);
                            switch(mode)
                              case 'Unset'
                                switch pinPrevMode
                                  case {'DigitalInput', 'DigitalInput_PullUp', 'DigitalOutput'}
                                    status = unconfigureDigitalPinInternal(obj.DigitalIODriverObj, obj.Protocol, pinNum);
                                    functionName = 'unconfigureDigitalPinInternal';
                                  case 'AnalogInput'
                                    status = unconfigureAnalogInSingleInternal(obj.AnalogDriverObj, obj.Protocol, pinNum);
                                    functionName = 'unconfigureAnalogInSingleInternal';
                                  case 'PWM'
                                    status = unconfigurePWMPinInternal(obj.PWMDriverObj, obj.Protocol, pinNum);
                                    functionName = 'unconfigurePWMPinInternal';
                                  otherwise
                                    % NOP
                                end
                              case {'DigitalInput', 'DigitalInput_PullUp', 'DigitalOutput'}
                                status = configureDigitalPinInternal(obj.DigitalIODriverObj, obj.Protocol, pinNum, mode);
                                functionName = 'configureDigitalPinInternal';
                              case 'AnalogInput'
                                param = getAnalogParamsForConfigurationHook(obj, pinNum);
                                if ~isempty(param)
                                    status = configureAnalogInSingleInternal(obj.AnalogDriverObj, obj.Protocol, pinNum, param);
                                    functionName = 'configureAnalogInSingleInternal';
                                else
                                    status = configureAnalogInSingleInternal(obj.AnalogDriverObj, obj.Protocol, pinNum);
                                    functionName = 'configureAnalogInSingleInternal';
                                end
                              case 'PWM'
                                params = getPWMParamsForConfigurationHook(obj, pinNum);
                                if ~isempty(params)
                                    status = configurePWMPinInternal(obj.PWMDriverObj, obj.Protocol, pinNum, params);
                                    functionName = 'configurePWMPinInternal';
                                else
                                    status = configurePWMPinInternal(obj.PWMDriverObj, obj.Protocol, pinNum);
                                    functionName = 'configurePWMPinInternal';
                                end
                              otherwise
                                % NOP
                            end
                            postHardwareConfigurationHook(obj, pinPrevMode, mode, pinNum, functionName, status);
                            % While configuring the same pin to next mode,
                            % prevMode should be current mode.
                            pinPrevMode = mode;
                        end
                    end
                    % It is possible to that configurePin is accessed
                    % by a callback even before the previous operation
                    % is complete. Hence the removal needs to go
                    % through a check whether a key is available at all
                    if isKey(obj.PinModeMap, pinNum)
                        % empty the map so that it is ready for next
                        % operation
                        remove(obj.PinModeMap, pinNum);
                    end
                end
            end
        end

        function discoverDevices(obj)
        % No parameters given:
        % If no last preference, auto-detect serial port / PubSub
        % If last preference exists, reuse last preference if address exists
        % If last preference exists, auto-detect serial if address no longer exists

            [isPref, oldPref] = obj.getPreference();

            if isempty(obj.Args.Address)
                if isPref
                    discoverDevicesWithPref(obj, oldPref);
                else
                    discoverDevicesWithoutPref(obj);
                end
            end

            % Address is now available. Validate next argument.
            if ~isempty(obj.Args.CustomParams)
                if isPref
                    obj.Args.CustomParams = obj.validateCustomInputParamsHook(obj.Args.CustomParams, oldPref);
                else
                    obj.Args.CustomParams = obj.validateCustomInputParamsHook(obj.Args.CustomParams, []);
                end
                assert(isstruct(obj.Args.CustomParams), 'CustomParams returned from validateCustomInputParamsHooks is expected to be a structure');
            end
        end

        function discoverDevicesWithPref(obj, oldPref)
            obj.ConnectionType = oldPref.ConnectionType;
            obj.ConnectionController = getConnectionController(obj.ConnectionType);
            % For MATLAB Online, all the addresses being used in
            % validateAddressExistence and validateSerialPort are the
            % address on the machine runs MATLAB Connector
            status = validateAddressExistence(obj.ConnectionController, obj, oldPref.Address, getExistingDevicesHook(obj));
            if status
                % Unix systems assigns same serial port for
                % different boards. Therefore always auto-detect
                % the serial port to ensure correct board is used
                % rather than blindly reuse the last preference.
                %
                if ~ispc && (obj.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial)
                    origPort = oldPref.Address;
                    % Only perform the readlink check on MATLAB dekstop at
                    % the moment
                    % TODO Need to assess the need to run the readlink for
                    % MATLAB online (on user's machine) in case if the user
                    % is using some alias to the actual serial port (g3203256)
                    % TODO The RemoteUtilities does not support MATLAB
                    % compiler deployment yet, need to remove the %#exclude
                    % below and isdeployed once g3238819 is resolved
                    %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
                    if (isdeployed || ~matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW) && ~ismac
                        [~, origPort] = system(['readlink ', oldPref.Address]);
                        if ~isempty(origPort)
                            origPort = ['/dev/',strtrim(origPort)];
                        else
                            origPort = oldPref.Address;
                        end
                    end
                    boardName = obj.validateSerialPort(origPort);
                    if ~isempty(oldPref.CustomParams)
                        if isfield(oldPref.CustomParams,'Board')
                            obj.Args.CustomParams.Board = boardName;
                        end
                    end
                else
                    obj.Args.CustomParams = oldPref.CustomParams;
                    % This line is added to ensure that port number is
                    % initialized according to older preference in case of other hardware
                    % and to standard port 18734 in case of
                    % raspi, if no arguments are given
                    if(isa(obj,"raspi.internal.RaspiHWSDKController"))
                        obj.Args.CustomParams.Port  = raspi.internal.getServerPort;
                    end
                end
                obj.Args.Address = oldPref.Address;
                obj.Args.TraceOn = oldPref.TraceOn;
                obj.Args.BaudRate = oldPref.BaudRate;
                obj.ConnectionController.BaudRateSpecified = false;
            else
                discoverDevicesWithoutPref(obj);
            end
        end

        function discoverDevicesWithoutPref(obj)
        % assume serial/PubSub connection and auto-detect
            if isempty(obj.ConnectionType)
                % If connection type hasn't been identified earlier, use
                % all supported transports
                supportedTransports = obj.getSupportedTransportsHook();
            else
                supportedTransports = obj.ConnectionType;
            end
            if all(supportedTransports ~= matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial) && ...
                    all(supportedTransports ~= matlabshared.hwsdk.internal.ConnectionTypeEnum.PubSub)
                % Auto detection is not possible for other transports
                obj.localizedError('MATLAB:hwsdk:general:boardNotDetected', char(obj.getHarwdareNameImpl));
            end
            assert(size(supportedTransports, 1) == 1); % Row based
            assert(size(supportedTransports, 2) >= 1);
            assert(isa(supportedTransports, 'matlabshared.hwsdk.internal.ConnectionTypeEnum'));
            port = [];
            for transport = supportedTransports
                switch (transport)
                  case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                    % Note for MATLAB Online: this method returns the port
                    % ID on the machine that runs MATLAB Connector
                    port = obj.scanSerialPorts();
                  case matlabshared.hwsdk.internal.ConnectionTypeEnum.PubSub
                    devices = getExistingDevicesHook(obj, transport);
                    if ~isempty(devices)
                        port = devices.Name(1);
                    end
                  otherwise
                end
                if ~isempty(port)
                    % It is enough to identify 1 device
                    obj.ConnectionType = transport;
                    break;
                end
            end
            if isempty(port)
                obj.localizedError('MATLAB:hwsdk:general:boardNotDetected', char(obj.getHarwdareNameImpl));
            else
                obj.ConnectionController = getConnectionController(obj.ConnectionType);
            end
            obj.Args.Address = port;
        end

        function updateNonPeripheralProperties(obj)
        % Update properties like Libraries, LibrariesSpecified, TraceOn
        % ForceBuildOn and BaudRate
            [isPref, oldPref] = obj.getPreference();
            if isa(obj, 'matlabshared.addon.controller')
                obj.Libraries = obj.Args.Libraries;
                obj.LibrariesSpecified = obj.Args.LibrariesSpecified;
            end

            if isempty(obj.Args.TraceOn)
                if isPref
                    obj.TraceOn = oldPref.TraceOn;
                else
                    obj.TraceOn = false;
                end
            else
                obj.TraceOn = obj.Args.TraceOn;
            end

            obj.ForceBuildOn = obj.Args.ForceBuildOn;

            if isequal(obj.ConnectionType, matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial)
                if isempty(obj.Args.BaudRate)
                    if isPref && ~isempty(oldPref.BaudRate) && isequal(obj.ConnectionType,oldPref.ConnectionType)
                        % If BaudRate is not specified as NV pair get and prefs
                        % exist, take the BaudRate from preferences
                        obj.BaudRate = oldPref.BaudRate;
                    else
                        % If BaudRate is not specified as NV pair and no prefs, get
                        % default Baud Rate for the hardware
                        obj.BaudRate = getBaudRateHook(obj);
                    end
                else
                    obj.BaudRate = obj.Args.BaudRate;
                end
            end
        end

        function updatePeripheralProperties(obj)
            if isa(obj, 'matlabshared.dio.controller')
                obj.AvailableDigitalPins = obj.getAvailableDigitalPins();
            end

            if isa(obj, 'matlabshared.adc.controller')
                obj.AvailableAnalogPins = obj.getAvailableAnalogInputVoltagePins();
                availableAnalogPinsHook(obj);
            end

            if isa(obj, 'matlabshared.pwm.controller')
                obj.AvailablePWMPins = obj.getAvailablePWMPins();
            end

            if isa(obj, 'matlabshared.i2c.controller')
                obj.AvailableI2CBusIDs = obj.getAvailableI2CBusIDs();
            end

            if isa(obj, 'matlabshared.spi.controller')
                obj.AvailableSPIBusIDs = obj.getAvailableSPIBusIDs();
            end

            if isa(obj, 'matlabshared.serial.controller')
                obj.AvailableSerialPortIDs = obj.getAvailableSerialPortIDs();
            end

            obj.AvailablePins = obj.getAvailablePins();
        end

        function args = initializeCustomParams(~, nCustomParams, args, paramNames)
            if nCustomParams > 0
                args.CustomParams = struct();
                for paramName = paramNames
                    args.CustomParams.(char(paramName)) = [];
                end
            end
        end

        function prepareAndThrowTransportValidationError(obj, status, supportedTransports, param)
            if ~status
                errorText = '';
                BLEIndex = find(supportedTransports == "BLE");
                supportedTransportsList = supportedTransports;
                if ~isempty(BLEIndex)
                    supportedTransportsList(BLEIndex) = [];
                end
                for transport = supportedTransportsList
                    if isempty(errorText)
                        % Fill the text of first transport
                    elseif transport == supportedTransportsList(end)
                        % Separate last error Text by 'or'
                        % string " or " is used because character
                        % concatenation ignores spaces.
                        errorText = strcat(errorText, " or ");
                    else
                        % Separate all error messages by comma
                        errorText = strcat(errorText, ", ");
                    end
                    errorText = char(strcat(errorText, getErrorText(transport)));
                end
                if ispc || ismac
                    obj.localizedError('MATLAB:hwsdk:general:invalidAddressPCMac', char(obj.getHarwdareNameImpl), param, errorText);
                else
                    obj.localizedError('MATLAB:hwsdk:general:invalidAddressLinux', char(obj.getHarwdareNameImpl), param, errorText);
                end
            end
        end

        function uploadServer(obj, connectionStatus)
            if(isa(obj.Protocol.TransportLayer, 'matlabshared.ioclient.transport.TransportLayerAbstract'))
                % Update server and try again
                obj.Protocol.TransportLayer.close();
                if connectionStatus
                    obj.updateServerImpl();
                else
                    if(obj.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial)
                        % TODO The RemoteUtilities does not support MATLAB
                        % compiler deployment yet, need to remove the %#exclude
                        % below and isdeployed once g3238819 is resolved
                        %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
                        if ~isdeployed && matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
                            remoteUtils = matlabshared.remoteconnectivity.internal.RemoteUtilities;
                            startupDelay = 3; % Delay in seconds between port connect and first access attempt
                            useDedicatedTransport = true;
                            % Update the virtual serial port with new
                            % baudrate. If the serial port has been
                            % requested before, the virtual serial port
                            % stays the same after the baudrate change.
                            % So there is no need to modify the port in the
                            % TransportProtocolObj
                            remoteUtils.createVirtualSerialPort(obj.Port, ...
                                num2str(obj.BaudRate), startupDelay, useDedicatedTransport);
                        end
                        obj.Connection.TransportProtocolObj.BaudRate = obj.BaudRate; %update the BaudRate of Connection Object to the current BaudRate, if Baudrate retrieved from preferences doesn't work
                    end
                    obj.updateServer();
                end
                obj.Protocol.TransportLayer.open();
            else
                % Update server and try again for
                % ITransport since the API for open and close is
                % different
                obj.Protocol.TransportLayer.disconnect();
                if connectionStatus
                    obj.updateServerImpl();
                else
                    obj.updateServer();
                end
                obj.Protocol.TransportLayer.connect();
            end
        end

        function interface = prepareInterface(~, interfaceRequested)
            switch interfaceRequested
              case "I2CAddress"
                interface = matlabshared.hwsdk.internal.InterfaceEnum.I2C;
              case "SPIChipSelectPin"
                interface = matlabshared.hwsdk.internal.InterfaceEnum.SPI;
              case "SerialPort"
                interface = matlabshared.hwsdk.internal.InterfaceEnum.Serial;
              otherwise
                % Can't reach here because earlier try-catch manages it
            end
        end

        function dev = prepareDeviceObject(obj, interface, varargin)
            switch interface
              case matlabshared.hwsdk.internal.InterfaceEnum.I2C
                dev = matlabshared.i2c.device(varargin{:});
              case matlabshared.hwsdk.internal.InterfaceEnum.SPI
                dev = obj.getSPIDeviceHook(varargin{:});
              case matlabshared.hwsdk.internal.InterfaceEnum.Serial
                dev = matlabshared.serial.device(varargin{:});
              otherwise
                % Can't reach here because earlier try-catch manages it
            end
        end

        function prepareAndThrowDeviceParsingErrors(obj, areMandatoryParametersFilled, e, p)
            if isempty(areMandatoryParametersFilled)
                switch e.identifier
                  case {'MATLAB:hwsdk:general:invalidAddressValue', ...
                        'MATLAB:hwsdk:general:invalidAddressType', ...
                        'MATLAB:hwsdk:general:invalidChipSelectPin', ...
                        'MATLAB:hwsdk:general:unsupportedPort', ...
                        'MATLAB:device:expectedScalar', ...
                        'MATLAB:expectedScalar', ...
                        'MATLAB:expectedRow', ...
                        'MATLAB:expectedNonempty',...
                        'MATLAB:invalidType', ...
                        'MATLAB:expectedScalartext'}
                    % Dedicated error message at an earlier stage
                    throwAsCaller(e);

                  case 'MATLAB:InputParser:ParamMustBeChar'
                    % No manipulation required when there is a number
                    % in place of NV pair Name(char)
                    obj.localizedError('MATLAB:hwsdk:general:requiredNVPairName', 'device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                  otherwise
                    % Extract the string representing the NV pair
                    % Name
                    message = e.message;
                    index = strfind(message, '''');
                    str = message(index(1)+1:index(2)-1);
                    validNVPairName = find(cellfun(@(x) (strcmpi(x, str) == 1), fieldnames(p.Results)),1);
                    if isempty(validNVPairName)
                        % If str is not mandatory NV pair
                        obj.localizedError('MATLAB:hwsdk:general:requiredNVPairName', 'device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                    elseif strcmp(e.identifier, 'MATLAB:InputParser:ParamMissingValue') || strcmp(e.identifier,'MATLAB:InputParser:ArgumentFailedValidation')
                        % If mandatory NV pair Name is available
                        % but no Value is provided
                        obj.localizedError('MATLAB:InputParser:ParamMissingValue', str);
                    end
                end
            end
        end

        function flagLib = getLibraryAvailability(obj, flag, serverInfo)
            if isa(obj, 'matlabshared.addon.controller')
                libraryList = extractLibrariesFromServerInfo(obj,serverInfo.boardServerInfo);
                if obj.LibrariesSpecified % no libraries are given
                    obj.Libraries = obj.validateLibraries(obj.Libraries); % check existence and completeness of libraries
                else
                    if flag && ~obj.ForceBuildOn% use the retrieved libs from the board
                        obj.Libraries =  libraryList;
                    else % use default libraries
                        obj.Libraries = obj.getDefaultLibraries();
                    end
                end
                flagLib = isempty(setxor(libraryList,obj.Libraries));
            else
                flagLib = true;
            end
        end
    end

    methods(Access = public, Hidden)
        function obj = controller()
            obj.Pref = obj.Prefix + obj.getHardwareName();
            obj.PinModeMap = containers.Map('KeyType',getPinTerminalTypeImpl(obj),'ValueType','any');
            % Get the utility to handle pin related validations
            if (isPinNumericHook(obj))
                obj.PinValidator = matlabshared.hwsdk.internal.NumericValidator;
            else
                obj.PinValidator = matlabshared.hwsdk.internal.StringValidator;
            end
        end
    end

    methods(Access = protected)

        function dev = getDeviceHook(obj, varargin)
            if (nargin < 3)
                obj.localizedError('MATLAB:minrhs');
            end

            parent = varargin{1};
            if ~isa(parent, 'matlabshared.hwsdk.controller')
                obj.localizedError('MATLAB:hwsdk:general:incompatibleHardware', class(parent));
            end

            p = inputParser;
            p.PartialMatching = true;

            if isa(parent, 'matlabshared.i2c.controller')
                addParameter(p, 'I2CAddress', [], @(address) (validateI2CAddress(obj, address)));
            end

            if isa(parent, 'matlabshared.spi.controller')
                addParameter(p, 'SPIChipSelectPin', '', @(pin) (validateSPIChipSelectPin(obj, pin)));
            end

            if isa(parent, 'matlabshared.serial.controller')
                addParameter(p, 'SerialPort', '', @(serialPort) validateDeviceSerialPort(obj, serialPort));
            end

            if isempty(p.Parameters)
                error('The specified hardware does not support I2C, SPI or Serial.');
            end

            try
                parse(p, varargin{2:end});
            catch e
                areMandatoryParametersFilled = find(structfun(@(x) ~isempty(x), p.Results),1);
                prepareAndThrowDeviceParsingErrors(obj, areMandatoryParametersFilled, e, p);
            end

            % Check which of the parameters (I2C / SPI / Serial) is used
            results = find(structfun(@(x) ~isempty(x), p.Results));

            interface = prepareInterface(obj, p.Parameters{results(1)});

            dev = prepareDeviceObject(obj, interface, varargin{:});
        end

        function dev = getSPIDeviceHook(~,varargin)
        % This is a hook for creating SPI device. The hardware
        % object can override this method for custom SPI
        % implementation.
            dev = matlabshared.spi.device(varargin{:});
        end

        function supportedTransports = getSupportedTransportsHook(~)
            supportedTransports = enumeration('matlabshared.hwsdk.internal.ConnectionTypeEnum')';
            supportedTransports(supportedTransports == matlabshared.hwsdk.internal.ConnectionTypeEnum.Mock) = [];
            supportedTransports(supportedTransports == matlabshared.hwsdk.internal.ConnectionTypeEnum.PubSub) = [];
        end

        function modes = getSupportedModesHook(~)
            modes = ['DigitalInput', 'DigitalOutput', 'AnalogInput', 'PWM', 'SPI', 'I2C', 'Unset'];
        end

        % status = validateServerInfoHook(obj, serverInfo)
        function status = validateServerInfoHook(~, ~)
            status = true;
        end

        function status = validateServerVersionHook(obj,serverInfo, ~)
        % The third argument should be defined as HWSDKVersion in the
        % overriding methods. Overriding methods should implement logic to validate LibVersion, HWSDKVersion, and IOServer version
        % verify that SPPKG version number and IOServer version number are in sync, this enables catching errors from different IOServer,HWSDK and HWSPPKG versions
            releaseIndex = strfind(obj.LibVersion,'.');
            % Major.Minor should be same for hwSPPKG and ioServer version
            statusRelease = strncmpi(serverInfo.hwSPPKGVersion,serverInfo.ioServerVersion,releaseIndex(end)-1);
            % hwSPPKG monthly should be greater than ioServer version number
            statusMonthly = str2double(extractAfter(serverInfo.hwSPPKGVersion,releaseIndex(end))) >= str2double(extractAfter(serverInfo.ioServerVersion,releaseIndex(end)));
            status = strcmpi(serverInfo.hwSPPKGVersion, obj.LibVersion) && ...
                     statusRelease && statusMonthly;
        end

        function precisions = getAvailablePrecisionsHook(obj) %#ok<MANU>
        % Required for sensors. Used by I2C to read data of number of bytes
        % related to specified precision.
            precisions = ["int8", "uint8", "int16", "uint16", "int32", "uint32", "int64", "uint64"];
        end

        % paramNames = getCustomInputParameterNamesHook(obj)
        function paramNames = getCustomInputParameterNamesHook(~)
            paramNames = strings(0,0);
        end

        function [flag,serverInfo] = getBuildOnlyServerInfoHook(~)
        % Hardware SPKG uses this hook to getServerInfo for build only test
            flag = false;
            serverInfo = [];
        end

        % customParams = parseCustomInputParamsHook(obj, customParams)
        function customParams = parseCustomInputParamsHook(~, customParams)
        %             error(['Must implement ''parseCustomInputParamsHook'' to parse custom parameters (' ...
        %                 char(matlabshared.hwsdk.internal.renderArrayOfStringsToString(obj.getCustomInputParameterNamesHook())) ')']);
        end

        % customParams = validateCustomInputParamsHook(obj, customParams, prefs)
        function customParams = validateCustomInputParamsHook(~, customParams, ~)
        %             error(['Must implement ''validateCustomInputParamsHook'' to validate custom parameters (' ...
        %                 char(matlabshared.hwsdk.internal.renderArrayOfStringsToString(obj.getCustomInputParameterNamesHook())) ')']);
        end

        % isValid = validateSerialDeviceHook(obj, vid, pid)
        function isValid = validateSerialDeviceHook(~, ~, ~)
            isValid = false;
        end

        function baudRate = getBaudRateHook(obj)
            baudRate = getDefaultBaudRate(obj);
        end

        % delay = getResetDelayHook(obj)
        function delay = getResetDelayHook(~)
            delay = 0;
        end

        function val = getIOProtocolTimeoutHook(~)
        % use default value of 10 seconds
            val = 10;
        end

        function showFailedUploadErrorHook(obj)
            showFailedUploadError(obj.ConnectionController, getBoardNameHook(obj), obj.Port);
        end

        function debugObj = getDebugObjectHook(~)
        % This is a function hook. The hardware class should implement
        % this method to return the debug message object if the debug
        % messages are stored on the host.
            debugObj = [];
        end

        function serverTrace = getServerTraceInfoHook(~,CustomData)
            serverTrace = str2double(extractAfter(extractAfter(CustomData,','),'  '));
        end

        function availableAnalogPinsHook(~)
        % This method manages board specific analog pins
        % Method definition is overridden in arduino
        end

        function mapPinModes(obj, pin, modes)
        % Update the map of pins and their modes to be configured
        % INPUTS:
        % obj - hardware object
        % pin - as a user sees it. For example, Arduino displays pins
        % as char vector. Cannot validate it here because different
        % hardware has pins in different types.
        % modes - mode string that the pin needs to be configured to

            assert(isstring(modes), 'Third argument expected to be array of strings');
            if isKey(obj.PinModeMap, pin) % Is pin already in the pinMode map?
                                          % Fetch already queued modes
                currentModes = obj.PinModeMap(pin);
                % Add needed modes as well
                obj.PinModeMap(pin) = [currentModes, modes];
            else % pin not in the pinMode map
                 % Add pin as a fresh key to map and assign modes
                obj.PinModeMap(pin) = modes;
            end
        end

        function devices = getExistingDevicesHook(~, ~)
        % GETEXISTINGDEVICESHOOK allows HSP to specify if any known
        % device is available in the specified transport.
        % Inputs:
        % 1. obj - matlabshared.hwsdk.controller - Hardware object
        % 2. transport - matlabshared.hwsdk.internal.ConnectionTypeEnum
        % OUTPUTS:
        % 1. devices - A table with properties of Name and SerialNumber

            devices = table.empty;
        end

        function flag = initHardwareBeforeServerConnectionHook(~, transport)
        % Specifies whether any hardware initialization or derivation
        % needs to be done before we program it.
            switch(transport)
              case { matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial, ...
                     matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi }
                flag = true;

              otherwise
                flag = false;
            end
        end
    end

    methods (Access = protected)
        % Custom Display
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);

            displayAddress(obj.ConnectionType, obj);

            obj.displayDynamicPropertiesHook();
            fprintf('         AvailablePins: [%s]\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(obj.AvailablePins));
            if isa(obj, 'matlabshared.dio.controller')
                fprintf('  AvailableDigitalPins: [%s]\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(obj.AvailableDigitalPins));
            end
            if isa(obj, 'matlabshared.pwm.controller')
                fprintf('      AvailablePWMPins: [%s]\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(obj.AvailablePWMPins));
            end
            if isa(obj, 'matlabshared.adc.controller')
                fprintf('   AvailableAnalogPins: [%s]\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(obj.AvailableAnalogPins));
            end
            if isa(obj, 'matlabshared.i2c.controller')
                fprintf('    AvailableI2CBusIDs: %s\n', ...
                        matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableI2CBusIDs));
            end
            if isa(obj, 'matlabshared.spi.controller') && (1 < length(obj.AvailableSPIBusIDs))
                fprintf('    AvailableSPIBusIDs: %s\n', ...
                        matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableSPIBusIDs));
            end
            if isa(obj, 'matlabshared.serial.controller')
                fprintf('    AvailableSerialPortIDs: %s\n', ...
                        matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableSerialPortIDs));
            end

            if isa(obj, 'matlabshared.addon.controller')
                fprintf('             Libraries: [%s]\n', matlabshared.hwsdk.internal.renderArrayOfStringsToString(...
                    obj.Libraries, ', ', 1));
            end


            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            %footer = matlabshared.hwsdk.internal.footer(inputname(1));

            if ~isempty(footer)
                disp(footer);
            end
            fprintf('\n');
        end

        function displayDynamicPropertiesHook(obj)
            p = findprop(obj, 'Board');
            if ~isempty(p)
                fprintf('                 Board: "%s"\n', char(obj.getBoardNameHook));
            end
        end
    end

    methods(Access = {?matlabshared.hwsdk.controller, ?matlabshared.hwsdk.internal.connections.ConnectionController})
        function setPreference(obj, type, address, port, trace, baudRate, customParams)
        % This function add the given input parameters to MATLAB preference
        % if none exists, or set the existing preference with the given
        % input parameters
            newPref.Address = address;
            newPref.CustomParams = customParams;
            newPref.ConnectionType = type;
            newPref.Port = port; % TCPIP port
            newPref.TraceOn = trace;
            newPref.BaudRate = baudRate;

            [isPref, oldPref] = getPreference(obj);
            if isPref && ~isequal(newPref, oldPref)
                setpref(obj.Group, char(obj.Pref), newPref);
            elseif ~isPref
                addpref(obj.Group, char(obj.Pref), newPref);
            end
        end

        function status = portEmulatorAvailableHook(~, ~)
        % Hook to be appropriately overridden in the derived classes to
        % validate a pseudo or virtual serial port
        % board specific object and port address should be passed in the
        % overriding hook impl
        % e.g. portEmulatorAvailableHook(arduinoObj, portAddress)
        % e.g  portEmulatorAvailableHook(microbitObj, portAddress)
            status = false;
        end

        function list = getBleListHook(obj,varargin)
        % Hook to overridden to detect list of ble devices with a
        % different service UUID than the one specified in HWSDK controller
        % This function returns list of ble devices advertising with the specific service UUID
            assert(nargin > 1);
            if(nargin == 1)
                list = blelist('Services',obj.ServiceUUID,'Timeout',varargin{1});
            else
                list = blelist('Services',obj.ServiceUUID);
            end
        end

        function port = getTCPIPPortHook(obj)
        % While parsing input arguments, obj.Args.Port is empty. Fetch
        % from preferences or assume default.
        % While adding properties, the port would have been fetched
        % from input. Use it from obj.Args.
            if isfield(obj.Args, 'Port') && ~isempty(obj.Args.Port)
                port = obj.Args.Port;
            else
                [isPref, oldPref] = getPreference(obj);
                if isPref
                    port = oldPref.Port;
                else
                    port = obj.DefaultTCPIPPort;
                end
            end
        end

        function parseCustomNameValueParametersHook(~, ~)
        % parseCustomNameValueParametersHook(obj, inputparserObj)
        % Hardware spkg uses this hook to parse additional NV Pairs
        % specific to their application like ArduinoIDELocation for
        % MALTAB Compiler Support for Arduino I/O APIs. Look at the
        % implementation done in arduino.m
        end

        function unmatchedCustomParamsErrorHook(obj,param)
        % Hardware spkg can override this hook to parse additional
        % NV Pairs specific to their application like AnalogReference
        % for Arduino I/O APIs in the 'MATLAB:hwsdk:general:invalidParam'
        % error message . Look at the implementation done in arduino.m

            if isa(obj, 'matlabshared.addon.controller')
                obj.localizedError('MATLAB:hwsdk:general:invalidParam', param, upper(class(obj)), 'are ''Libraries'',');
            else
                obj.localizedError('MATLAB:hwsdk:general:invalidParam', param, upper(class(obj)), 'are');
            end
        end

        function inputParserErrorHook(~,e)
        % Hardware spkg can override this hook to catch additional
        % errors while parsing user inputs and throw error messages
        % specific to arduino class, Look at the implementation done in arduino.m

            throwAsCaller(e);
        end

        % connection = serialHook(obj, varargin)
        function connection = serialHook(~, varargin)
            connection = serialport(varargin{:});
        end

        % connection = bluetoothHook(obj, varargin)
        function connection = bluetoothHook(~, varargin)
            connection = bluetooth(varargin{:});
        end

        % connection = tcpClientHook(obj, varargin)
        function connection = tcpClientHook(~, varargin)
            connection = matlabshared.network.internal.TCPClient(varargin{:});
        end

        % connection =  blePeripheralHook(obj, deviceAddress)
        function connection = blePeripheralHook(~,deviceAddress)
            connection = matlabshared.ioclient.transport.TransportLayerUtility.getTransportLayer('ble',deviceAddress);
        end

        function connection = pubSubConnectionHook(~,~)
            connection = [];
        end

        function addCustomNameValueParametersHook(~, ~)
        % addCustomNameValueParametersHook(obj, inputparserObj)
        % Hardware spkg uses this hook to add additional NV Pairs
        % specific to their application like ArduinoIDELocation for
        % MALTAB Compiler Support for Arduino I/O APIs. Look at the
        % implementation done in arduino.m
        end

        % Adding a validateCustomParamsHook hook which is overridden in the
        % Arduino class
        function validateCustomParamsHook(~)
        end

        function initServerConnection(obj)
            obj.Connection = createConnectionObject(obj.ConnectionController, obj);
            connectionStatus = initCommunication(obj, obj.Connection);
            if ispref('MATLAB_HARDWARE','Test_BuildOnly') && isequal(obj.ConnectionType, matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial) && ~ispref('MATLAB_HARDWARE','Test_OutdatedServer')
                % Set connection status to false so that getServerInfo is
                % called after build for build only test
                connectionStatus = false;
            end

            %%
            serverUpdateAttempted = false;
            if ~connectionStatus
                if ~ obj.ConnectionController.BaudRateSpecified && isequal(obj.ConnectionType, matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial)
                    obj.BaudRate = getBaudRateHook(obj);
                end
                uploadServer(obj, connectionStatus);
                serverUpdateAttempted = true;
                connectionStatus = initCommunication(obj, obj.Connection);
                if ~connectionStatus
                    obj.localizedError('MATLAB:hwsdk:general:incorrectServerInitialization');
                end
            end

            % Check already downloaded libraries if any and retrieve IDs
            % If nothing has been downloaded, update server code
            % If server code exists but libraries are different, update
            % server code.
            %
            % If server code exists and libraries are the same, reuse old
            % library IDs
            %
            serverStatus = validateServerInfo(obj,isHardwareProgrammableHook(obj));
            if ~serverUpdateAttempted && (~serverStatus || obj.ForceBuildOn)
                if isHardwareProgrammableHook(obj)
                    uploadServer(obj, connectionStatus);
                    flag = initCommunication(obj, obj.Connection);
                    serverStatus = false;
                    if flag
                        % Validation is required after the server is
                        % uploaded because the server needs to be checked
                        % if it is compatabile with the SPKG version. False
                        % argument is passed here to throw the error when
                        % there is a version mismatch.
                        serverStatus = validateServerInfo(obj,false);
                    end
                end
            end

            if ~serverStatus
                showFailedUploadErrorHook(obj);
            end
        end

        function baudRate = getDefaultBaudRate(obj)
            baudRate = obj.DefaultBaudRate;
        end

        function status = validateWiFiAddressHook(obj, address)
            status = false;
            % Check for xxx.xxx.xxx.xxx IP address format to
            % determine whether address is IP or hostname
            if strcmp(computer, 'GLNXA64')
                currentLDLibPath = getenv('LD_LIBRARY_PATH');
                setenv('LD_LIBRARY_PATH', '');
                c = onCleanup(@() cleanup(obj, currentLDLibPath));
            end
            if strcmp(computer, 'PCWIN64')
                cmd = ['ping -n 3 ',address];
                [pingStatus, result] = system(cmd);
                % pingStatus = 1 means failed ping
                % pingStatus = 0 means either success or Destination not reachable (which is again a failed ping)
                if(isequal(pingStatus, 0))
                    addressMatch = regexpi(result,address);
                    % For a successful ping the address is printed
                    % in the reply messages as well
                    % For messages containing Destination host
                    % unreachable, the IP address of the board is
                    % not present in the reply messages
                    % 3 pings + 2 in the headers
                    if isequal(numel(addressMatch), 5)
                        status = true;
                    end
                end
            else
                cmd = ['ping -c 3 ',address];
                [~, result] = system(cmd);
                % ttl=56 time=6.42ms - This pattern being detected once is sufficient.
                match = regexpi(result,'ttl=\d+ time=[0-9.]+ ms','ONCE');
                status = ~isempty(match);
            end

            function cleanup(~, currentLDLibPath)
                setenv('LD_LIBRARY_PATH', currentLDLibPath);
            end
        end
    end

    methods(Access = protected)
        % initHardwareHook(obj)
        function initHardwareHook(~)
        end

        function pins = renderPins(~, pins)
            if numel(pins) <= 8
                pins = matlabshared.hwsdk.internal.renderArrayOfStringsToString(pins, ', ', 1);
            else
                pins = ['"' char(pins(1)) '-' char(pins(end)) '"'];
            end
        end

        function [address, port] = validateTransport(obj, param)

            if ~ischar(param) && ~isstring(param)
                obj.localizedError('MATLAB:hwsdk:general:invalidAddressTypeFirstInput');
            end
            if isstring(param)
                param = char(param);
            end

            supportedTransports = obj.getSupportedTransportsHook();
            assert(size(supportedTransports, 1) == 1); % Row based
            assert(size(supportedTransports, 2) >= 1);
            assert(isa(supportedTransports, 'matlabshared.hwsdk.internal.ConnectionTypeEnum'));

            for transport = supportedTransports
                [status, address, port] = validateAddressExistence(getConnectionController(transport), obj, param, getExistingDevicesHook(obj, transport));
                if status
                    obj.ConnectionType = transport;
                    obj.ConnectionController = getConnectionController(obj.ConnectionType);
                    break;
                end
            end
            prepareAndThrowTransportValidationError(obj, status, supportedTransports, param);
        end

        function [isPref, pref] = getPreference(obj)
            isPref = ispref(obj.Group, char(obj.Pref));
            pref = [];
            if isPref
                pref = getpref(obj.Group, char(obj.Pref));
                if ~isfield(pref, 'ConnectionType') || isempty(pref.ConnectionType) || ~isenum(pref.ConnectionType)
                    isPref = false;
                    rmpref(obj.Group, char(obj.Pref));
                    pref = [];
                end
            end
        end

        function boardName = validateSerialPort(obj, port)
            origPort = port;
            % Workaround for g1452757 to allow user specify tty port
            % for auto-detection since the HW connection API only
            % detect cu port.
            if ismac
                port = strrep(port, 'tty', 'cu');
            end
            usbdev = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
            [foundPorts, devinfo] = getSerialPorts(usbdev);
            if ~isempty(foundPorts)
                % Workaround to find VID/PID based on given serial port
                index = find(strcmpi(foundPorts, port),1);
                if ~isempty(index)
                    vid = string(devinfo(index).VendorID);
                    pid = string(devinfo(index).ProductID);
                end
            end
            [isValid, boardName] = obj.validateSerialDeviceHook(vid, pid);
            if ~isValid % No hardware found at the given port
                obj.localizedError('MATLAB:hwsdk:general:invalidPort', char(obj.getHarwdareNameImpl), origPort);
            end
        end

        function port = scanSerialPorts(obj)
            port = [];
            usbdev = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
            [foundPorts, devinfo] = getSerialPorts(usbdev);
            for iPort = 1:numel(foundPorts)
                vid = string(devinfo(iPort).VendorID);
                pid = string(devinfo(iPort).ProductID);

                try
                    if (obj.validateSerialDeviceHook(vid, pid))
                        port = char(foundPorts{iPort});
                    end
                catch
                    % do nothing
                    % obj.validateSerialDeviceHook is expected to throw an
                    % error if an invalid vid_pid is found on iPort
                    % Keep on scanning
                    % If a valid board is found, 'port' will have a
                    % non-empty port address
                end
            end
        end

        function params = getPWMParamsForConfigurationHook(~, ~)
        % Returns hardware specific values needed to configure a pin to
        % PWM.
        % INPUTS:
        % obj - this
        % pinNumber - that will be used by IOServer
        % OUTPUTS:
        % varargout{1} = frequency.
        % varargout{2} = dutycycle.
        % varargout{3} = counterModeType.

            params = [0, 0];
        end

        function param = getAnalogParamsForConfigurationHook(~, ~)
        % Returns hardware specific values needed to configure a pin to
        % PWM.
        % INPUTS:
        % obj - this
        % pinNumber - that will be used by IOServer
        % OUTPUTS:
        % varargout{1} = frequency.
        % varargout{2} = dutycycle.
        % varargout{3} = counterModeType.

            param = [];
        end

        function preHardwareConfigurationHook(~, ~, ~, ~)
        % Hw SPPKG performs any task needed before configuring a pin to
        % a specified mode here.
        % INPUTS:
        % obj - this
        % prevMode - mode before configuration
        % mode - mode after configuration
        % pinNumber - that will be used by IOServer
        end

        function postHardwareConfigurationHook(~, ~, ~, ~, ~, ~)
        % Hw SPPKG performs any task needed after configuring a pin to
        % a specified mode here.
        % INPUTS:
        % obj - this
        % prevMode - mode before configuration
        % mode - mode after configuration
        % pinNumber - that will be used by IOServer
        % functionName - IOClient Function that was used to configure
        % status - output of the that IOClient function
        end

        function status = isHardwareProgrammableHook(obj)
        % Specifies if a hardware is programmable or not for the current
        % connection type. Defaults to Serial. HSP overrides this and
        % provides its status.
        % Programmable means flashable for arduino; server launchable for
        % raspi.

            switch obj.ConnectionType
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                status = true;
              otherwise
                status = false;
            end
        end
    end

    methods(Access = {?matlabshared.hwsdk.internal.base,?arduino.accessor.UnitTest})
        function result = isDigitalPin(obj, pin)
            result = ismember(pin, obj.AvailableDigitalPins) || ismember(pin, obj.AvailablePWMPins);
        end

        function result = isAnalogPin(obj, pin)
            result = ismember(pin, obj.AvailableAnalogPins);
        end

        function boardName = getBoardNameHook(obj)
            boardName = getHarwdareNameImpl(obj);
            assert(isstring(boardName) || ischar(boardName));
        end

        function modes = getSupportedModes(obj)
            modes = getSupportedModesHook(obj);
        end

        % pin = getPinAliasHook(obj, pin)
        function pin = getPinAliasHook(~, ~)
            pin = [];
        end

        function isPinConfigurable = isPinConfigurableHook(~, varargin)
        % ISPINCONFIGURABLEHOOK specifies if a particular pin (and/or)
        % interface is configurable or not
        % INPUTS:
        %   obj - this
        %   NV Pairs:
        %       Interface (matlabshared.hwsdk.internal.InterfaceEnum
        %       Pin
        % OUTPUTS:
        %   isPinConfiguraPle (bool)
        %       true => the pin is configurable and configurePinInternal
        %       will be called on it
        %       false => the pin is not configurable
            isPinConfigurable = true;
        end

        function throwIOProtocolExceptionsHook(~, ~, ~)
        % Method to react to failure of IOClient operations
        % Inputs:
        % obj - matlabshared.hwsdk.controller
        % methodName - IOProtocol command that failed (openI2CBus)
        % status - return value of IOProtocol command
        end
    end

    methods(Access = {?matlabshared.hwsdk.internal.base})
        function [pin, terminal, mode, resource] = getPinInfoHook(obj, pin)
            terminal = pin;
            mode = configurePinInternal(obj, pin);
            if any(contains(mode, ["DigitalOutput", "DigitalInput", "AnalogInput", "PWM", "Pullup"]))
                resource = '';
            else
                resource = mode;
            end
        end

        function pinNumeric = isPinNumericHook(~)
        % Specifies if the pins are treated as numbers or strings
            pinNumeric = false;
        end

        function compatibleModes = getCompatibleModesHook(~, ~)
        % A hardware may allow operations when the pin is configured to
        % some other mode. Those are called compatible modes. HSP can
        % provide if there is such a case.
        % INPUTS:
        %   obj - matlabshared.dio.controller
        %   mode - HSP must provide modes that are compatible with this
        % OUTPUTS:
        %   compatibleModes - string array of modes that are compatible
        %   with mode mentioned above.
            compatibleModes = string.empty;
        end
    end
end
