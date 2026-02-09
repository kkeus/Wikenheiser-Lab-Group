classdef device < matlabshared.rawDevice.device & ...
        matlab.mixin.CustomDisplay
%   Create an I2C device object for the target class
%
%   The methods of this class provide the functions to user to read from or write to an I2C device connected to the target
%
%   Syntax:
%           eeprom = device(a,'I2CAddress',hex2dec('50')); % a = object belonging to target class
%           eeprom = device(a,'I2CAddress',hex2dec('50'),'BitRate',100000);
%           eeprom = device(a,'I2CAddress',80,'BitRate',100000);
%           eeprom = device(a,'I2CAddress',0x50,'BitRate',100000); % 0x50(80) is the I2CAddress represented in hexadecimal
%           eeprom = device(a,'I2CAddress',0b01010000,'BitRate',100000); % 0b01010000 is the I2CAddress represented in binary
%
%   Available methods:
%           write
%           read
%           writeRegister
%           readRegister

%   Copyright 2017-2023 The MathWorks, Inc.

% Properties set by the constructor
    properties(GetAccess = public, SetAccess = protected)
        I2CAddress double
        Bus
        SCLPin
        SDAPin
        BitRate double
    end
    properties(Access = private)
        DuplicateDevice
        BusResourceOwner
    end

    properties(Access = private, Constant = true)
        START_I2C       = hex2dec('00')
        READ            = hex2dec('02')
        WRITE           = hex2dec('03')
        READ_REGISTER   = hex2dec('04')
        WRITE_REGISTER  = hex2dec('05')
        AvailablePrecisions = {'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}
        SIZEOF = struct('int8', 1, 'uint8', 1, 'int16', 2, 'uint16', 2, 'int32', 4, 'uint32', 4, 'int64', 8, 'uint64', 8)
    end

    properties(Access = {?matlabshared.sensors.internal.Accessor})
        I2CDriverObj
    end

    % TODO: Make this generic for Unified Interfaces
    properties(Access = protected, Constant = true)
        LibraryName = 'I2C'
        DependentLibraries = {}
        LibraryHeaderFiles = 'Wire/Wire.h'
        CppHeaderFile = fullfile(matlabroot,'toolbox\target\shared\svd\include', 'MW_I2C.h')
        CppClassName = 'MW_I2C'
    end

    properties(Hidden,Access = private)
        % Flag to indicate successful increment in the resource count
        IsIncrementedResource = false;
    end

    methods
        % HWSDK displays a string array. Some hardware might require a
        % different type of display. Since a Getter cannot be
        % inherited, a trip is provided here which the individual hardware
        % can make use of.
        function sclPin = get.SCLPin(obj)
            sclPin =  obj.Parent.getI2CSCLPinForPropertyDisplayHook(obj.SCLPin);
        end

        function sdaPin = get.SDAPin(obj)
            sdaPin =  obj.Parent.getSDAPinForPropertyDisplayHook(obj.SDAPin);
        end
    end

    methods (Access = private, Static = true)
        function name = matlabCodegenRedirect(~)
            name = 'matlabshared.coder.i2c.device';
        end
    end

    methods(Access = protected)
        function delete(obj)
            try
                % Destructor logic is updated to align with constructor behaviour. In constructor the
                % resource count will be incremented just before starting the protocol. In destructor
                % the resource count will be decremented first before stopping the protocol. And an
                % additional logic is added here to see if there are any duplicate devices. This logic
                % will be different from other devices(SPI,Serial) implementation because in I2C device
                % multiple devices can exists on a given bus, whereas in Serial/SPI only one device
                % can exist for a given channel. See g2699842 for more info.

                % Assign count to default []
                count = [];

                % See if the resource owner is not empty. Resource owner will be empty only when
                % there are no device objects.
                if ~isempty(obj.BusResourceOwner)
                    % Get the available resource count for respective resource owner
                    count = getDeviceResourceProperty(obj, obj.BusResourceOwner, "Count");
                    if isempty(count)
                        % Math operations aren't working on empty double. Wrkarnd.
                        count = 0;
                    end
                    % We need to decrement the resource count only for non-duplicate devices.
                    % DuplicateDevice will be either empty or 0 when there are no duplicate devices.
                    if isempty(obj.DuplicateDevice) || any(obj.DuplicateDevice>0)
                        % Don't decrement further if resource count is
                        % already zero or delete is called as part of
                        % constructor with invalid address
                        if (count~=0) && obj.IsIncrementedResource
                            setDeviceResourceProperty(obj, obj.BusResourceOwner, "Count", count-1);
                            count = count - 1;
                        end
                    end
                end

                if count==0
                    try
                        stopI2C(obj);
                    catch
                    end
                end
                if isempty(obj.DuplicateDevice)
                    parentObj = obj.Parent;
                    i2cAddresses = getDeviceResourceProperty(obj, obj.BusResourceOwner, "i2cAddresses");
                    i2cAddresses(i2cAddresses == obj.I2CAddress) = [];
                    setDeviceResourceProperty(obj, obj.BusResourceOwner, "i2cAddresses", i2cAddresses);
                end
                % Construction failed, revert I2C pins back to their original states
                if obj.IsPinConfigurable && ~isempty(obj.Undo) % only revert when pin configuration has changed
                    for idx = 1:numel(obj.Undo)
                        prevMode = configurePinInternal(parentObj, obj.Undo(idx).Pin);
                        if strcmpi(prevMode, 'I2C') && count == 0 % only revert when pin has successfully configured to I2C and no more devices present on bus
                            configurePinInternal(parentObj, obj.Undo(idx).Pin, 'Unset', 'i2c.device', obj.ResourceOwner);
                        end
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
        end


        function dataOut = readHook(obj, count, precision)
            numBytes = uint8(count * obj.SIZEOF.(char(precision)));
            try
                output = rawI2CRead(obj.I2CDriverObj, obj.Parent.Protocol, obj.Parent.getI2CBusInfoHook(obj.Bus), obj.I2CAddress, numBytes);
                readSuccessFlag = 1;   %% TODO need to add this based on IOSERVER OUTPUT
                if readSuccessFlag == hex2dec('FF') % error code
                    obj.localizedError('MATLAB:hwsdk:general:unsuccessfulI2CRead', num2str(count), precision);
                else
                    dataOut = uint8(output(1:end));
                    dataOut = typecast(dataOut, char(precision));
                    dataOut = dataOut';
                end
                try
                    % Cannot represent int > 2^53 using double
                    matlabshared.hwsdk.internal.validateIntArrayParameterRanged('dataOut', ...
                                                                                dataOut, ...
                                                                                -2^52, ...
                                                                                2^52);
                    dataOut = double(dataOut);
                catch
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:hwsdk:general:connectionIsLost')
                    obj.localizedError('MATLAB:hwsdk:general:communicationLostI2C', num2str(obj.Bus));
                end
                throwAsCaller(e);
            end
        end
        function dataOut = readRegisterHook(obj, registerAddress, count, precision)
            numBytes = uint8(count * obj.SIZEOF.(char(precision)));
            try
                output = registerI2CRead(obj.I2CDriverObj, obj.Parent.Protocol, obj.Parent.getI2CBusInfoHook(obj.Bus), obj.I2CAddress, registerAddress, numBytes);
                readSuccessFlag = 1;%% TODO need to add this based on IOSERVER OUTPUT
                if readSuccessFlag == hex2dec('FF') % error code
                    obj.localizedError('MATLAB:hwsdk:general:unsuccessfulI2CRead', num2str(count), precision);
                else
                    dataOut = uint8(output(1:end));
                    dataOut = typecast(dataOut, char(precision));
                    dataOut = dataOut';
                end
                try
                    % Cannot represent int > 2^53 using double
                    matlabshared.hwsdk.internal.validateIntArrayParameterRanged('dataOut', ...
                                                                                dataOut, ...
                                                                                -2^52, ...
                                                                                2^52);
                    dataOut = double(dataOut);
                catch
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:hwsdk:general:connectionIsLost')
                    obj.localizedError('MATLAB:hwsdk:general:communicationLostI2C', num2str(obj.Bus));
                end
                throwAsCaller(e);
            end
        end

        function writeHook(obj, dataIn, precision)
            dataIn = cast(dataIn, char(precision));
            dataIn = typecast(dataIn, 'uint8');
            numBytes = (numel(dataIn));
            if numBytes > obj.Parent.getMaxI2CReadWriteBufferSize
                obj.localizedError('MATLAB:hwsdk:general:maxI2CData',num2str(floor(obj.Parent.getMaxI2CReadWriteBufferSize/obj.SIZEOF.(char(precision)))),char(precision));
            end
            try
                rawI2CWrite(obj.I2CDriverObj, obj.Parent.Protocol, obj.Parent.getI2CBusInfoHook(obj.Bus), obj.I2CAddress, dataIn);
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:hwsdk:general:connectionIsLost')
                    obj.localizedError('MATLAB:hwsdk:general:communicationLostI2C', num2str(obj.Bus));
                end
                throwAsCaller(e);
            end
        end
        function writeRegisterHook(obj,registerAddress,dataIn, precision)
            dataIn = cast(dataIn, char(precision));
            dataIn = typecast(dataIn, 'uint8');
            numBytes = (numel(dataIn));
            if numBytes > obj.Parent.getMaxI2CReadWriteBufferSize
                obj.localizedError('MATLAB:hwsdk:general:maxI2CData',num2str(floor(obj.Parent.getMaxI2CReadWriteBufferSize/obj.SIZEOF.(char(precision)))),char(precision));
            end
            try
                registerI2CWrite(obj.I2CDriverObj, obj.Parent.Protocol, obj.Parent.getI2CBusInfoHook(obj.Bus), obj.I2CAddress, registerAddress, dataIn);
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:hwsdk:general:connectionIsLost')
                    obj.localizedError('MATLAB:hwsdk:general:communicationLostI2C', num2str(obj.Bus));
                end
                throwAsCaller(e);
            end
        end
    end

    methods
        function bitRate = get.BitRate(obj)
            bitRate = getDeviceResourceProperty(obj, obj.BusResourceOwner, "i2cBitRate");
        end
    end

    methods(Hidden, Access = public)
        function obj = device(varargin)
        %   Connect to the I2C device at the specified address on the I2C bus.
        %
        %   Syntax:
        %   i2cDevice = device(obj, 'I2CAddress', address)
        %   i2cDevice = device(obj, 'I2CAddress', address, Name, Value)
        %
        %   Description:
        %   i2cDevice = device(obj, 'I2CAddress', address)      Connects to an I2C device at the specified address on the
        %                                 default I2C bus of the Arduino hardware.
        %
        %   Example:
        %       a = arduino();
        %       tmp102 = device(a,'I2CAddress','0x48');
        %
        %   Example:
        %       m = microbit();
        %       tmp102 = device(m,'I2CAddress','0x25','Bus',1);
        %   Example:
        %       a = arduino();
        %       tmp102 = device(a,'I2CAddress','0x48','BitRate',100000);
        %   Example:
        %       a = arduino();
        %       tmp102 = device(a,'I2CAddress','0x48','Bus',1,'BitRate',100000);
        %   Input Arguments:
        %   a       - Arduino object
        %   m       - BBC micro:bit object
        %   address - I2C address of device (numeric or character vector or string)
        %
        %   Name-Value Pair Input Arguments:
        %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value.
        %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
        %
        %   NV Pair:
        %   'bus'     - The I2C bus (numeric, default 1)
        %   'BitRate' - The BitRate for the i2c bus(numeric,default 100000 Hz)
        %

            obj@matlabshared.rawDevice.device(varargin{:});
            obj.Interface = "I2C";
            obj.ResourceOwner = "I2C";
            if nargin < 2
                obj.localizedError('MATLAB:minrhs');
            end
            if nargin > 7
                obj.localizedError('MATLAB:maxrhs');
            end
            try
                p = inputParser;
                p.PartialMatching = true;
                addParameter(p, 'I2CAddress', '');
                addParameter(p, 'Bus', obj.Parent.getHwsdkDefaultI2CBusIDHook());
                addParameter(p, 'BitRate', []);
                parse(p, varargin{2:end});
            catch e
                parameters = p.Parameters;
                if strcmp(e.identifier, 'MATLAB:InputParser:ParamMustBeChar')
                    nvPairs = cellfun(@ischar, varargin(4:end));
                    nvNames = nvPairs(1:2:end);
                    numericNVNames = find(~nvNames);
                    nonCharNVName = varargin{3+(numericNVNames(1)*2-1)};
                    if isnumeric(nonCharNVName)
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', num2str(nonCharNVName), 'I2C device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                    else
                        throwAsCaller(e);
                    end
                else
                    message = e.message;
                    index = strfind(message, '''');
                    str = message(index(1)+1:index(2)-1);
                    switch e.identifier
                      case 'MATLAB:InputParser:ParamMissingValue'
                        try
                            validatestring(str, p.Parameters);
                        catch
                            parameters = p.Parameters;
                            obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'I2C device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                        end
                        obj.localizedError('MATLAB:InputParser:ParamMissingValue', str);
                      case 'MATLAB:InputParser:UnmatchedParameter'
                        parameters = p.Parameters;
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'I2C device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                      case 'MATLAB:InputParser:AmbiguousParameter'
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'I2C device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                    end
                end
            end

            obj.Bus = validateBus(obj.Parent, p.Results.Bus);
            obj.BusResourceOwner = strcat("I2CBus",string(obj.Bus));

            % Get I2C Pins
            [busNumber, sclPin, sdaPin] = obj.Parent.getI2CBusInfoHook(obj.Bus);
            % Set pin properties so that other functions can access them
            obj.SCLPin = sclPin;
            obj.SDAPin = sdaPin;

            if isempty(sdaPin) || isempty(sclPin)
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:notSupportedInterface', 'I2C', getBoardNameHook(obj.Parent));
            end

            % I2CAddress is already validated in i2c.controller. Format it.
            obj.I2CAddress = matlabshared.hwsdk.internal.validateHexParameterRanged('I2C device address', ...
                                                                                    p.Results.I2CAddress, ...
                                                                                    0, ...
                                                                                    obj.Parent.getMaxI2CAddress);


            try
                deviceI2C = scanI2CBus(obj.Parent.Protocol,busNumber);
            catch e
                if strcmpi(e.identifier,'ioserver:general:CFunctionNotFound')
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'I2C');
                else
                    throwAsCaller(e);
                end
            end

            if ~ismember(obj.I2CAddress, deviceI2C)
                obj.localizedError('MATLAB:hwsdk:general:invalidAddressValue',strcat('0x',dec2hex(obj.I2CAddress)));
            end

            try
                i2cAddresses = getDeviceResourceProperty(obj, obj.BusResourceOwner, "i2cAddresses");
            catch
                i2cAddresses = [];
            end
            if ismember(obj.I2CAddress, i2cAddresses)
                obj.DuplicateDevice = 1;
                obj.localizedError('MATLAB:hwsdk:general:conflictI2CAddress', num2str(obj.I2CAddress), dec2hex(obj.I2CAddress));
            end
            i2cAddresses = [i2cAddresses obj.I2CAddress];
            setDeviceResourceProperty(obj, obj.BusResourceOwner, "i2cAddresses", i2cAddresses);

            % Configure Pins to I2C mode
            configurePins(obj, {sclPin, sdaPin});
            try
                currentBitRate = getDeviceResourceProperty(obj, obj.BusResourceOwner, "i2cBitRate");
            catch
                currentBitRate = [];
            end
            if isempty(p.Results.BitRate)
                if isempty(currentBitRate)
                    bitRate = obj.Parent.getI2CDefaultBitRate(obj.Bus);
                else
                    bitRate = currentBitRate;
                end
            else
                bitRate = obj.validateBitRate(p.Results.BitRate);
                if ~isequal(currentBitRate,bitRate) && ~isempty(currentBitRate)
                    matlabshared.hwsdk.internal.localizedWarning('MATLAB:hwsdk:general:I2CBitRateChange', num2str(obj.Bus), num2str(bitRate));
                end
            end
            setDeviceResourceProperty(obj, obj.BusResourceOwner, "i2cBitRate", bitRate);
            obj.I2CDriverObj = getI2CDriverObj(obj.Parent);

            % Increment the resource count just before starting the I2C.
            % Resource count should be incremented only after validating
            % all the error condition and corner cases. Incrementing the
            % resource count before starting the protocol will cause false
            % errors. See g2652246 and g2699842 for more details.
            currentCount = getDeviceResourceProperty(obj, obj.BusResourceOwner, "Count");
            if isempty(currentCount)
                % Math operations aren't working on empty double. Wrkarnd.
                currentCount = 0;
            end
            setDeviceResourceProperty(obj, obj.BusResourceOwner, "Count", currentCount+1);
            % Update the increment resource flag
            obj.IsIncrementedResource = true;
            startI2C(obj);
        end
    end

    methods(Sealed, Access = public)
        function dataOut = read(obj, varargin)
        %READ    Read data from I2C device.
        %
        %   See also READREGISTER, WRITE, WRITEREGISTER.
            try
                % This is needed for integrating precision parameter before
                % validating it
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    dprecision = 'NA';
                    dcount = 'NA';
                    switch nargin
                      case 2
                        dcount = varargin{1};
                        if (ischar(varargin{1}) || isstring(varargin{1}))
                            % This is needed for data integration
                            dprecision = string(varargin{1});
                        end
                      case 3
                        % This is needed for data integration
                        dprecision = varargin{2};
                        dcount = varargin{1};
                    end
                    % Register on clean up for integrating all data.
                    c = onCleanup(@() integrateData(obj.Parent,'I2C',dprecision, dcount));
                end

                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                elseif nargin > 3
                    obj.localizedError('MATLAB:maxrhs');
                end

                switch nargin
                  case 2
                    if isnumeric(varargin{1})
                        count = varargin{1};
                        precision = "uint8";
                    elseif (ischar(varargin{1}) || isstring(varargin{1}))
                        count = 1;
                        precision = string(varargin{1});
                    else
                        obj.localizedError('MATLAB:hwsdk:general:IntegerType');
                    end

                  case 3
                    count = varargin{1};
                    precision = varargin{2};
                end

                precision = obj.validatePrecision(precision);
                count = obj.validateCount(count, precision);

                dataOut = obj.readHook(count, precision);

                assert(isnumeric(dataOut));
                assert(size(dataOut, 1) == 1); % row based
            catch e
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj.Parent,e.identifier);
                end
                throwAsCaller(e);
            end
        end

        function dataOut = readRegister(obj, register, varargin)
        %READREGISTER    Read data from I2C device register.
        %
        %   See also READ, WRITE, WRITEREGISTER.
            try
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    % This is needed for data integration
                    dprecision = 'NA';
                    dregister = 'NA';
                    if (nargin == 3)
                        dregister = register;
                        if ~isnumeric(varargin{1})
                            % This is needed for data integration
                            dprecision = varargin{1};
                        end
                    elseif (4 == nargin)
                        dregister = register;
                        if isnumeric(varargin{1})
                            % This is needed for data integration
                            dprecision = varargin{2};
                        end
                    elseif 2 == nargin
                        dregister = register;
                    end
                    % Register on clean up for integrating all data.
                    c = onCleanup(@() integrateData(obj.Parent,'I2C',dprecision, dregister));
                end
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                elseif nargin > 4
                    obj.localizedError('MATLAB:maxrhs');
                end
                % Validate register input
                if ischar(register)
                    register = string(register);
                end

                if ((isstring(register) || isnumeric(register)) && isscalar(register))
                    register = obj.validateRegisterAddress(register);
                else
                    obj.localizedError('MATLAB:hwsdk:general:RegisterType');
                end

                % Validate count and precision input
                if (nargin < 3)
                    count = 1;
                    precision = "uint8";
                elseif (nargin < 4)
                    if isnumeric(varargin{1})
                        count = varargin{1};
                        precision = "uint8";
                        count = obj.validateCount(count, precision);
                    else
                        precision = varargin{1};
                        count = 1;
                        precision = obj.validatePrecision(precision);
                    end
                elseif (4 == nargin)
                    if isnumeric(varargin{1})
                        % varargin1 -> count, varargin2 -> precision
                        count = varargin{1};
                        precision = varargin{2};
                        precision = obj.validatePrecision(precision);
                        count = obj.validateCount(count, precision);
                    elseif isstring(varargin{1}) || ischar(varargin{1})
                        obj.localizedError('MATLAB:maxrhs');
                    end
                end
                dataOut = obj.readRegisterHook(register, count, precision);
                assert(isnumeric(dataOut));
            catch e
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj.Parent,e.identifier);
                end
                throwAsCaller(e);
            end
        end

        function write(obj, dataIn, precision)
        %WRITE   Write data to I2C device.
        %
        %   See also READ, WRITEREGISTER, READREGISTER.
            try
                % This is needed for data integration
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    dprecision = 'NA';
                    ddataIn = 'NA';
                    if (nargin == 2)
                        if isnumeric(dataIn) && isvector(dataIn) && isinteger(dataIn)
                            % This is needed for data integration
                            dprecision = class(dataIn);
                        end
                        ddataIn = dataIn;
                    elseif nargin == 3
                        ddataIn = dataIn;
                        % This is needed for data integration
                        dprecision = precision;
                    end
                    % Register on clean up for integrating all data.
                    c = onCleanup(@() integrateData(obj.Parent,'I2C',dprecision,ddataIn));
                end
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end

                if (nargin < 3)
                    precision = "uint8";
                    if isstring(dataIn) || ischar(dataIn)
                        dataIn = uint8(char(dataIn));
                    end
                    if isnumeric(dataIn) && isvector(dataIn) && isinteger(dataIn)
                        precision = class(dataIn);
                    end
                else
                    precision = obj.validatePrecision(precision);
                end
                dataIn = obj.validateData(dataIn, precision);
                obj.writeHook(dataIn, precision);
            catch e
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj.Parent,e.identifier);
                end
                throwAsCaller(e);
            end
        end

        function writeRegister(obj, register, dataIn, precision)
        %WRITEREGISTER    Write data to I2C device register.
        %
        %   See also READ, WRITE, READREGISTER.
            try
                % This is needed for data integration
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    dprecision = 'NA';
                    dregister = 'NA';
                    ddataIn = 'NA';
                    if nargin == 3
                        if isnumeric(dataIn) && isvector(dataIn) && isinteger(dataIn)
                            dprecision = class(dataIn);
                        end
                        ddataIn = dataIn;
                        dregister = register;
                    elseif nargin == 2
                        dregister = register;
                    elseif nargin == 4
                        dprecision = precision;
                        ddataIn = dataIn;
                        dregister = register;
                    end

                    % Register on clean up for integrating all data.
                    c = onCleanup(@() integrateData(obj.Parent,'I2C',dprecision,dregister,ddataIn));
                end
                if (nargin < 3)
                    obj.localizedError('MATLAB:minrhs');
                end

                % Validate register input
                if ischar(register)
                    register = string(register);
                end
                if ((isstring(register) || isnumeric(register)) && isscalar(register))
                    register = obj.validateRegisterAddress(register);
                else
                    obj.localizedError('MATLAB:hwsdk:general:RegisterType');
                end

                % Validate precision input
                if (nargin < 4)
                    precision = "uint8";
                    if isstring(dataIn) || ischar(dataIn)
                        dataIn = uint8(char(dataIn));
                    end
                    if isnumeric(dataIn) && isvector(dataIn) && isinteger(dataIn)
                        precision = class(dataIn);
                    end
                else
                    precision = obj.validatePrecision(precision);
                end

                dataIn = obj.validateData(dataIn, precision);
                obj.writeRegisterHook(register, dataIn, precision);
            catch e
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj.Parent,e.identifier);
                end
                throwAsCaller(e);
            end
        end
    end

    methods(Access = private)

        function startI2C(obj)
            try
                status = openI2CBus(obj.I2CDriverObj, obj.Parent.Protocol, obj.Parent.getI2CBusInfoHook(obj.Bus), 'I2CFrequency', obj.BitRate);
                throwIOProtocolExceptionsHook(obj.Parent, 'openI2CBus', status);
            catch e
                if strcmpi(e.identifier,'ioserver:general:CFunctionNotFound')
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'I2C');
                else
                    throwAsCaller(e);
                end
            end
        end

        function stopI2C(obj)
            try
                status = closeI2CBus(obj.I2CDriverObj, obj.Parent.Protocol, obj.Parent.getI2CBusInfoHook(obj.Bus));
                throwIOProtocolExceptionsHook(obj.Parent, 'closeI2CBus', status);
            catch e
                throwAsCaller(e)
            end
        end

        function result = validatePrecision(obj, precision)
            try
                if ischar(precision)
                    precision = string(precision);
                end
                result = validatestring(precision, obj.Parent.getAvailableI2CPrecisions(), '', 'precision');
            catch e
                if strcmp(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    % TODO: Make generic error id
                    id = 'MATLAB:hwsdk:general:invalidPrecision';
                    e = MException(id, ...
                                   getString(message(id, char(strjoin(obj.Parent.getAvailableI2CPrecisions, ', ')))));
                end
                throwAsCaller(e);
            end
        end

        function result = validateBitRate(obj, bitRate)
            try
                if isnumeric(bitRate) && isscalar(bitRate)
                    bitRates = obj.Parent.getI2CBitRateLimit(obj.Bus);
                    if ismember(bitRate, bitRates)
                        result = bitRate;
                    else
                        obj.localizedError('MATLAB:hwsdk:general:invalidBitRateValue', 'I2C', matlabshared.hwsdk.internal.renderArrayOfIntsToString(bitRate), matlabshared.hwsdk.internal.renderArrayOfIntsToString(bitRates));
                    end
                else
                    obj.localizedError('MATLAB:hwsdk:general:invalidBitRateType', 'I2C');
                end
            catch e
                throwAsCaller(e);
            end
        end

        function result = validateRegisterAddress(~, address)
            try
                result = matlabshared.hwsdk.internal.validateHexParameterRanged('Register address', ...
                                                                                address, ...
                                                                                0, ...
                                                                                255);
            catch e
                throwAsCaller(e);
            end
        end

        function result = validateCount(obj, count, precision)
            if ~(isnumeric(count) && count > 0 && isscalar(count))
                obj.localizedError('MATLAB:hwsdk:general:IntegerType');
            end
            maxCount = floor(obj.Parent.getMaxI2CReadWriteBufferSize/matlabshared.hwsdk.internal.sizeof(precision));
            try
                result = matlabshared.hwsdk.internal.validateIntParameterRanged('count', ...
                                                                                count, ...
                                                                                1, ...
                                                                                maxCount);
            catch
                obj.localizedError('MATLAB:hwsdk:general:maxI2CData',num2str(maxCount),char(precision));
            end
        end

        function result = validateData(obj, dataIn, precision)
            result = 0;
            try
                if ischar(dataIn) || isstring(dataIn)
                    % Convert characters to ascii decimals
                    dataIn = cast(dataIn, precision);
                end
                if isnumeric(dataIn)
                    try
                        if ~isinteger(dataIn)
                            % Check only double values for the range
                            matlabshared.hwsdk.internal.validateIntArrayParameterRanged('dataIn', ...
                                                                                        dataIn, ...
                                                                                        -2^52, ...
                                                                                        2^52);
                        end
                    catch
                        obj.localizedError('MATLAB:hwsdk:general:DataPrecisionValueMismatch');
                    end
                    result = matlabshared.hwsdk.internal.validateIntArrayParameterRanged('dataIn', ...
                                                                                         dataIn, ...
                                                                                         intmin(precision), ...
                                                                                         intmax(precision));
                end
            catch e
                throwAsCaller(e);
            end
        end
    end

    methods (Access = protected)
        % Custom Display
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);

            obj.Parent.showI2CProperties(obj.Interface, obj.I2CAddress, obj.Bus, obj.SCLPin, obj.SDAPin, obj.BitRate, true);

            footer = matlabshared.hwsdk.internal.footer(inputname(1));

            if ~isempty(footer)
                disp(footer);
            end
            fprintf('\n');
        end

        function pinsWithLabel = getDevicePinWithLabelImpl(obj)
            pinsWithLabel = getDevicePinsWithLabel(obj.Parent.PinValidator, obj.Interface, SCL=obj.SCLPin, SDA=obj.SDAPin);
        end
    end

    methods(Hidden, Access = public)
        function showFunctions(~)
            fprintf('\n');
            fprintf('   read\n');
            fprintf('   readRegister\n');
            fprintf('   write\n');
            fprintf('   writeRegister\n');
            fprintf('\n');
        end
    end
end

% LocalWords:  fullpath arduinoio badsubscript dev SCL SDA CBase CRead
% LocalWords:  CAddress
