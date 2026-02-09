classdef (Hidden) device < matlabshared.rawDevice.device & ...
        matlab.mixin.CustomDisplay
%   Create an SPI device object for the target class
%
%   The methods of this class provide the functions to user to read from or write to an SPI device connected to the target
%
%   Syntax:
%
%   Available methods:
%       writeRead

%   Copyright 2017-2023 The MathWorks, Inc.

% Properties set by the constructor
    properties(GetAccess = public, SetAccess = protected)
        SPIChipSelectPin
        SCLPin
        SDIPin
        SDOPin
        ActiveLevel matlabshared.hwsdk.internal.ActiveLevelEnum
    end

    properties(Access = public)
        SPIMode double
        BitOrder
        BitRate
    end

    properties(Hidden, GetAccess = public, SetAccess = protected)
        Bus double
    end

    properties(Access = private)
        BusResourceOwner
        DuplicateDevice
        IsCSPinConfigurable = true
    end

    properties(Access = protected)
        % This property holds the IO Client object
        SPIDriverObj = [];
    end

    properties(Access = private, Constant = true)
        START_SPI      = hex2dec('00')
        STOP_SPI       = hex2dec('01')
        SET_BIT_RATE   = hex2dec('02')
        SET_BIT_ORDER  = hex2dec('03')
        SET_MODE       = hex2dec('04')
        WRITE_READ     = hex2dec('05')
        SIZEOF = struct('int8', 1, 'uint8', 1, 'int16', 2, 'uint16', 2, ...
                        'int32', 4, 'uint32', 4, 'int64', 8, 'uint64', 8)
    end

    % TODO: Addon libraries interface merge into Unified Interfaces
    properties(Access = protected, Constant = true)
        LibraryName = 'SPI'
        DependentLibraries = {}
        LibraryHeaderFiles = 'SPI/SPI.h'
        CppHeaderFile = fullfile(matlabroot,'toolbox\target\shared\svd\include', 'MW_SPI.h')
        CppClassName = 'MW_SPI'
    end

    methods
        function set.SPIMode(obj, mode)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end

                mode = validateSPIMode(obj, mode);

                obj.SPIMode = mode;
            catch e
                throwAsCaller(e);
            end
        end

        function set.BitOrder(obj, bitOrder)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end

                bitOrder = validateBitOrder(obj, bitOrder);

                obj.BitOrder = matlabshared.hwsdk.internal.BitOrderEnum(bitOrder);
            catch e
                throwAsCaller(e);
            end
        end

        function set.BitRate(obj, bitRate)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end

                bitRate = validateBitRate(obj, bitRate);

                obj.BitRate = bitRate;
            catch e
                throwAsCaller(e);
            end
        end

        % HWSDK displays a string array. Some hardware might require a
        % different type of display. Since a Getter cannot be
        % inherited, a trip is provided here which the individual hardware
        % can make use of.
        function csPin = get.SPIChipSelectPin(obj)
            csPin = obj.Parent.getCSPinForPropertyDisplayHook(obj.SPIChipSelectPin);
        end

        function sclPin = get.SCLPin(obj)
            sclPin = obj.Parent.getSPISCLPinForPropertyDisplayHook(obj.SCLPin);
        end

        function sdiPin = get.SDIPin(obj)
            sdiPin = obj.Parent.getSDIPinForPropertyDisplayHook(obj.SDIPin);
        end

        function sdoPin = get.SDOPin(obj)
            sdoPin = obj.Parent.getSDOPinForPropertyDisplayHook(obj.SDOPin);
        end
    end

    methods
        function dataOut = writeRead(obj, varargin)
            try
                % This is required for the data integration
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    dprecision = 'NA';
                    ddata = 'NA';
                    if 3 == nargin
                        % This is needed for data integration
                        dprecision = varargin{2};
                    end
                    if nargin > 1
                        ddata = varargin{1};
                    end

                    % Register on clean up for integrating all data.
                    c = onCleanup(@() integrateData(obj.Parent,'SPI',dprecision, ddata));
                end
                if 3 == nargin
                    obj.validatePrecision(varargin{2});
                end
                dataOut = obj.writeReadHook(varargin{:});
            catch e
                if isa(obj.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj.Parent,e.identifier);
                end
                throwAsCaller(e);
            end
        end
    end

    methods(Access = protected)
        function dataOut = writeReadHook(obj, dataIn, dataPrecision)
            if nargin < 3
                castDataOut = false;
                dataPrecision = 'uint8';
            else
                castDataOut = true;
            end

            switch (string(obj.ActiveLevel))
              case "low"
                isCSPinActiveLow = 1;
              case "high"
                isCSPinActiveLow = 0;
            end
            numBytes = obj.SIZEOF.(char(dataPrecision));
            maxValue = 2^(numBytes*8)-1;

            try
                precision = char(dataPrecision);
                dataIn = matlabshared.hwsdk.internal.validateIntArrayParameterRanged(...
                    'dataIn', dataIn, intmin(precision), intmax(precision));

                dataInLen = size(dataIn,2);
                if dataInLen*numBytes > getMaxSPIReadWriteBufferSize(obj.Parent)
                    obj.localizedError('MATLAB:hwsdk:general:maxSPIData', num2str(floor(getMaxSPIReadWriteBufferSize(obj.Parent)/obj.SIZEOF.(precision))),precision);
                end

                tmp = [];
                for ii = 1:dataInLen
                    val = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                        ['dataIn(' num2str(ii) ')'], ...
                        dataIn(ii), ...
                        0, ...
                        maxValue);
                    val = cast(val, char(dataPrecision));
                    val = typecast(val, 'uint8');
                    tmp = [tmp, val]; %#ok<AGROW>
                end

                [speedMatchFlag, formatMatchFlag] = checkPreviousSettingMatch(obj.Parent, obj.BitRate, obj.BitOrder, obj.SPIMode);
                if ~speedMatchFlag
                    setBusSpeedSPI(obj.SPIDriverObj, obj.Parent.Protocol, obj.Parent.getSPIBusAliasImpl(obj.Bus, obj.SPIChipSelectPin), obj.BitRate);
                end
                if ~formatMatchFlag
                    % formatMatchFlag has both Mode and BitOrder
                    SPIRegisterSize = 8;
                    setFormatSPI(obj.SPIDriverObj, obj.Parent.Protocol, obj.Parent.getSPIBusAliasImpl(obj.Bus, obj.SPIChipSelectPin), SPIRegisterSize, obj.SPIMode, obj.BitOrder);
                end
                [returnedData, status] = writeReadSPI(obj.SPIDriverObj, obj.Parent.Protocol, obj.Parent.getSPIBusAliasImpl(obj.Bus, obj.SPIChipSelectPin), obj.Parent.getPinNumber(obj.SPIChipSelectPin), isCSPinActiveLow, uint32(dataInLen*numBytes), tmp);
                throwIOProtocolExceptionsHook(obj.Parent, 'writeReadSPI', status);
                % IOClient returns data as a column vector
                dataOutLen = size(returnedData,1)/numBytes;
                if castDataOut
                    availablePrecisions = obj.Parent.getAvailableSPIPrecisions();
                    % Handle for precision
                    precisionHandle = str2func((availablePrecisions{log2(obj.SIZEOF.(char(precision)))+1}));
                    dataOut = precisionHandle(zeros(1, dataOutLen));
                else
                    dataOut = zeros(1, dataOutLen);
                end
                for ii = 1:dataOutLen
                    returnedDataIdx = ((ii-1)*numBytes)+1;
                    dataInBytes = returnedData(returnedDataIdx : returnedDataIdx+numBytes-1);
                    dataOut(ii) = typecast(uint8(dataInBytes), precision);
                end
            catch e
                throwAsCaller(e);
            end
        end
    end

    methods(Hidden, Access = public)
        function obj = device(varargin)
        %   Connect to the SPI device enabled with a specified Chip Select Pin.
        %
        %   Syntax:
        %   spiDevice = device(obj, 'SPIChipSelectPin', pin)
        %   spiDevice = device(obj, 'SPIChipSelectPin', pin, Name, Value)
        %
        %   Description:
        %   spiDevice = device(obj, 'SPIChipSelectPin', pin)      Connects to an SPI device enabled with a specified Chip Select Pin.
        %
        %   Example:
        %       a = arduino();
        %       eeprom = device(a,'SPIChipSelectPin','D8');
        %
        %   Example:
        %       m = microbit();
        %       eeprom = device(m,'SPIChipSelectPin','P16');
        %   Example:
        %       a = arduino();
        %       eeprom = device(a,'SPIChipSelectPin','D8','BitRate',100000);
        %   Input Arguments:
        %   a       - Arduino object
        %   m       - BBC micro:bit object
        %   pin - Chip Select Pin of device (character vector or string)
        %
        %   Name-Value Pair Input Arguments:
        %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value.
        %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
        %
        %   NV Pair:
        %   'Bus'           - The SPI bus number (numeric, default - 1)
        %   'BitRate'       - The BitRate for the SPI bus(numeric,
        %   default - 4000000 Hz)
        %   'ActiveLevel'   - The active level of the chip select pin
        %   (default - low)
        %   'SPIMode'       - The mode of operation of the SPI device
        %   (default - 0)
        %   'BitOrder'      - The bit order of data transfer (string,
        %   default - 'msbfirst')
        %

            obj@matlabshared.rawDevice.device(varargin{:});
            obj.Interface = "SPI";
            obj.ResourceOwner = "SPI";
            if nargin < 2
                obj.localizedError('MATLAB:minrhs');
            end
            if nargin > 13
                obj.localizedError('MATLAB:maxrhs');
            end
            try
                p = inputParser;
                addParameter(p, 'SPIChipSelectPin', []);
                addParameter(p, 'Bus', 1);
                addParameter(p, 'ActiveLevel', 'low');
                addParameter(p, 'SPIMode', 0);
                addParameter(p, 'BitOrder', 'msbfirst');
                addParameter(p, 'BitRate', []);
                parse(p, varargin{2:end});
            catch e
                parameters = p.Parameters;
                if strcmp(e.identifier, 'MATLAB:InputParser:ParamMustBeChar')
                    % Get the character status of all NV pairs
                    nvPairs = cellfun(@ischar, varargin(4:end));
                    % Get the character status of NV pair Names
                    nvNames = nvPairs(1:2:end);
                    numericNVNames = find(~nvNames);
                    nonCharNVName = varargin{3+(numericNVNames(1)*2-1)};
                    if isnumeric(nonCharNVName)
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', num2str(nonCharNVName), 'SPI device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
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
                            obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'SPI device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                        end
                        obj.localizedError('MATLAB:InputParser:ParamMissingValue', str);
                      case 'MATLAB:InputParser:UnmatchedParameter'
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'SPI device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                      case 'MATLAB:InputParser:AmbiguousParameter'
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'SPI device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                    end
                end
            end
            spiPins = obj.Parent.getAvailableSPIPins();
            if isempty(spiPins)
                % SPITerminals empty => Unsupported interface or
                % Unmultiplexed pins. When the pins are not multiplexed, no
                % configuration is required.
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:notSupportedInterface', 'SPI', obj.Parent.Board);
            end
            % SPI Chip select is already validated in spi.controller.
            spiChipSelectPin = p.Results.SPIChipSelectPin;

            obj.Bus = obj.validateBus(p.Results.Bus);
            obj.BusResourceOwner = strcat("SPIBus",string(obj.Bus));
            currentCount = getDeviceResourceProperty(obj, obj.BusResourceOwner, "Count");
            if isempty(currentCount)
                % Math operations aren't working on empty double. Wrkarnd.
                currentCount = 0;
            end
            setDeviceResourceProperty(obj, obj.BusResourceOwner, "Count", currentCount+1);

            obj.ActiveLevel = obj.validateActiveLevel(p.Results.ActiveLevel);

            obj.SPIMode = obj.validateSPIMode(p.Results.SPIMode);

            obj.BitOrder = obj.validateBitOrder(p.Results.BitOrder);

            if isempty(p.Results.BitRate)
                obj.BitRate = obj.Parent.getSPIDefaultBitRate(obj.Bus);
            else
                obj.BitRate = obj.validateBitRate(p.Results.BitRate);
            end
            % Fill PreviousSetting in matlabshared.spi.controller with right values
            checkPreviousSettingMatch(obj.Parent, obj.BitRate, obj.BitOrder, obj.SPIMode);

            % Check for CS pin conflict
            sclPin = spiPins(obj.Bus).SCLPin;
            sdiPin = spiPins(obj.Bus).SDIPin;
            sdoPin = spiPins(obj.Bus).SDOPin;
            % Set pin properties so that other functions can access them.
            obj.SCLPin = sclPin;
            obj.SDIPin = sdiPin;
            obj.SDOPin = sdoPin;
            obj.SPIChipSelectPin = spiChipSelectPin;
            if isstruct(spiPins)
                % string array
                pins = [sclPin sdiPin sdoPin];
            end
            try
                spiPinsUsed = getDeviceResourceProperty(obj, obj.BusResourceOwner, "spiPinsUsed");
            catch
            end
            % First SPI device creation
            if isempty(spiPinsUsed)
                % Store pins as resource only if they are configurable.
                if ~isempty(spiPins) && isPinConfigurableHook(obj.Parent, Interface = obj.Interface)
                    spiPinsUsed = pins;
                else
                    spiPinsUsed = string.empty;
                end
            end
            pinIsUsed = find(ismember(spiChipSelectPin,spiPinsUsed),1);
            if ~isempty(pinIsUsed)
                obj.DuplicateDevice = 1;
                obj.localizedError('MATLAB:hwsdk:general:conflictSPIPinsCS', char(spiChipSelectPin), char(string(obj.Bus)));
            end

            % Block pins to the resource
            spiPinsUsed = [spiPinsUsed spiChipSelectPin];
            setDeviceResourceProperty(obj, obj.BusResourceOwner, "spiPinsUsed", spiPinsUsed);

            % Configure Pins to SPI mode
            configurePins(obj, {sclPin, sdiPin, sdoPin});

            iUndo = length(obj.Undo);
            obj.IsCSPinConfigurable = isPinConfigurableHook(obj.Parent, Interface="SPI", Pin=spiChipSelectPin);
            if obj.IsCSPinConfigurable
                try
                    % Configure CS pin to digital output and then change its
                    % resource owner to SPI
                    prevMode = configurePinInternal(obj.Parent, spiChipSelectPin);
                    if strcmp(prevMode, 'SPI') || strcmp(prevMode, 'Unset')
                        pinStatus = configurePinInternal(obj.Parent, spiChipSelectPin, 'DigitalOutput', 'spi.device', obj.ResourceOwner);
                        iUndo = iUndo + 1;
                        obj.Undo(iUndo) = pinStatus;
                    else
                        % Throw if CS pin is used in any mode other than SPI
                        obj.localizedError('MATLAB:hwsdk:general:reservedPin', char(spiChipSelectPin), char(prevMode), 'SPI');
                    end
                catch e
                    throwAsCaller(e);
                end
            end
            % Get the SPI driver object from the hardware object. This
            % driver object will be used to communicate with hardware in IO
            % mode.
            obj.SPIDriverObj = getSPIDriverObj(obj.Parent, obj.Bus);
            startSPI(obj);
        end
    end

    methods (Access=protected)
        function delete(obj)
            try
                % Get the available resource count for respective resource owner
                count = getDeviceResourceProperty(obj, obj.BusResourceOwner, "Count");
                if ~isempty(count) && count~=0
                    setDeviceResourceProperty(obj, obj.BusResourceOwner, "Count", count-1);
                    count = count - 1;
                end
                if (count == 0)
                    % All SPI objects have been deleted.
                    try
                        stopSPI(obj);
                    catch
                    end
                    unconfigure();
                elseif isempty(obj.DuplicateDevice)
                    spiPinsUsed = getDeviceResourceProperty(obj, obj.BusResourceOwner, "spiPinsUsed");
                    spiPinsUsed(spiPinsUsed == obj.SPIChipSelectPin) = [];
                    setDeviceResourceProperty(obj, obj.BusResourceOwner, "spiPinsUsed", spiPinsUsed);
                    if obj.IsCSPinConfigurable
                        [~, ~, csPinMode, csPinResource] = getPinInfoHook(obj.Parent, obj.SPIChipSelectPin);
                        if strcmpi(csPinMode, 'SPI') && strcmp(csPinResource, obj.ResourceOwner)
                            configurePinInternal(obj.Parent, obj.SPIChipSelectPin, 'Unset', 'spi.device', obj.ResourceOwner);
                        end
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            function unconfigure()
                if(~isempty(obj.Bus) && ~isempty(obj.SDOPin) && ~isempty(obj.SDIPin) && ~isempty(obj.SCLPin) && ~isempty(obj.SPIChipSelectPin))
                    try
                        spiPinsUsed = getDeviceResourceProperty(obj, obj.BusResourceOwner, "spiPinsUsed");
                        spiPinsUsed(spiPinsUsed == obj.SPIChipSelectPin) = [];
                        setDeviceResourceProperty(obj, obj.BusResourceOwner, "spiPinsUsed", spiPinsUsed);
                    catch

                    end
                end
                % Construction failed, revert SPI pins back to their original states
                % We don't need the condition of isPinConfigurable here
                % because configuration is restricted during construction.
                if ~isempty(obj.Undo)
                    for idx = 1:numel(obj.Undo)
                        [~, ~, prevMode, prevResource] = getPinInfoHook(obj.Parent, obj.Undo(idx).Pin);
                        if strcmpi(prevMode, 'SPI') && strcmp(prevResource, obj.ResourceOwner)% only revert when pin has successfully configured to SPI
                            configurePinInternal(obj.Parent, obj.Undo(idx).Pin, 'Unset', 'spi.device', obj.ResourceOwner);
                        end
                    end
                end
            end
        end
    end

    methods(Hidden, Sealed, Access = public)
        function dataOut = read(obj, varargin)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                precision = 'uint8';
                dataIn = validateData(obj, varargin{1}, precision);

                dataOut = obj.writeReadHook(dataIn, precision);

                assert(isnumeric(dataOut));
                assert(size(dataOut, 1) == 1); % row based
            catch e
                throwAsCaller(e);
            end
        end

        function write(obj, dataIn, precision)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end

                if (nargin < 3)
                    precision = "uint8";
                    if isnumeric(dataIn) && isvector(dataIn) && isinteger(dataIn)
                        precision = class(dataIn);
                    end
                else
                    precision = obj.validatePrecision(precision);
                end

                dataIn = obj.validateData(dataIn, precision);

                obj.writeReadHook(dataIn, precision);
            catch e
                throwAsCaller(e);
            end
        end

        function writeRegister(~, varargin)
        end

        function data = readRegister(~, varargin)
            data = 0;
        end
    end

    methods(Access = private)
        function result = validatePrecision(obj, precision)
            try
                if ischar(precision)
                    precision = string(precision);
                end
                result = validatestring(precision, obj.Parent.getAvailableSPIPrecisions(), '', 'precision');
            catch e
                if strcmp(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    id = 'MATLAB:hwsdk:general:invalidPrecision';
                    e = MException(id, ...
                                   getString(message(id, char(strjoin(obj.Parent.getAvailableSPIPrecisions(), ', ')))));
                end
                throwAsCaller(e);
            end
        end

        function result = validateCount(obj, count, precision)
            if ~(isnumeric(count) && count > 0 && isscalar(count))
                obj.localizedError('MATLAB:hwsdk:general:IntegerType');
            end
            maxCount = floor(obj.Parent.getMaxSPIReadWriteBufferSize/matlabshared.hwsdk.internal.sizeof(precision));
            try
                result = matlabshared.hwsdk.internal.validateIntParameterRanged('count', ...
                                                                                count, ...
                                                                                1, ...
                                                                                maxCount);
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

        function result = validateData(obj, dataIn, precision)
            result = 0;
            try
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
                elseif ischar(dataIn) || isstring(dataIn)
                    result = matlabshared.hwsdk.internal.validateHexParameterRanged('dataIn', ...
                                                                                    dataIn, ...
                                                                                    0, ...
                                                                                    2^(8*matlabshared.hwsdk.internal.sizeof(precision))-1);
                end
            catch e
                throwAsCaller(e);
            end
        end

        function busNum = validateBus(obj, bus)
            buses = matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.Parent.AvailableSPIBusIDs);
            try
                if ~(isnumeric(bus) && isreal(bus) && isscalar(bus) && ~isinteger(bus) && bus>=0)
                    obj.localizedError('MATLAB:hwsdk:general:invalidBusTypeNumeric', 'SPI', buses);
                elseif ~ismember(bus, obj.Parent.AvailableSPIBusIDs)
                    obj.localizedError('MATLAB:hwsdk:general:invalidBusValue', 'SPI', buses);
                end
            catch e
                throwAsCaller(e);
            end
            busNum = bus;
        end

        function result = validateActiveLevel(obj, level)
            try
                activeLevelValues = ["low", "high"];

                if isstring(level)
                    level = char(level);
                end
                if ~ischar(level)
                    obj.localizedError('MATLAB:hwsdk:general:invalidActiveLevelType', 'SPI', 'string', char(matlabshared.hwsdk.internal.renderArrayOfStringsToString(activeLevelValues)));
                end

                result = validatestring(string(level), activeLevelValues);
            catch e
                throwAsCaller(e);
            end
        end

        function result = validateSPIMode(~, mode)
            try
                result = matlabshared.hwsdk.internal.validateIntParameterRanged('SPI mode', mode, 0, 3);
            catch e
                throwAsCaller(e);
            end
        end

        function result = validateBitOrder(obj, bitOrder)
            try
                bitOrderValues = ["msbfirst", "lsbfirst"];

                if isa(bitOrder, 'matlabshared.hwsdk.internal.BitOrderEnum')
                    bitOrder = string(bitOrder);
                end
                if isstring(bitOrder)
                    bitOrder = char(bitOrder);
                end
                if ~ischar(bitOrder)
                    obj.localizedError('MATLAB:hwsdk:general:invalidBitOrderType', 'SPI', 'string', char(matlabshared.hwsdk.internal.renderArrayOfStringsToString(bitOrderValues)));
                end

                result = validatestring(string(bitOrder), bitOrderValues);
            catch e
                switch(e.identifier)
                  case 'MATLAB:unrecognizedStringChoice'
                    obj.localizedError('MATLAB:hwsdk:general:invalidBitOrderValue', 'SPI', 'string', char(matlabshared.hwsdk.internal.renderArrayOfStringsToString(bitOrderValues)));
                  otherwise
                    throwAsCaller(e);
                end
            end
        end

        function result = validateBitRate(obj, bitRate)
            try
                validateattributes(bitRate, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidBitRateType', 'SPI');
            end
            supportedBitRates = getSPIBitRates(obj.Parent, obj.Bus);
            if ismember(bitRate, supportedBitRates)
                result = bitRate;
            else
                if numel(supportedBitRates) > 20
                    supportedBitRates = supportedBitRates(1);
                end

                obj.localizedError('MATLAB:hwsdk:general:invalidBitRateValue', 'SPI', num2str(bitRate), char(matlabshared.hwsdk.internal.renderArrayOfIntsToString(supportedBitRates)));
            end
        end
    end

    methods (Access = private)
        function startSPI(obj)
            try
                controller = 0;
                SPIRegisterSize = 8;

                status = openSPI(obj.SPIDriverObj, ...
                                 obj.Parent.Protocol, ...
                                 obj.Parent.getSPIBusAliasImpl(obj.Bus, obj.SPIChipSelectPin), ...
                                 obj.Parent.getPinNumber(obj.SDOPin), ...
                                 obj.Parent.getPinNumber(obj.SDIPin), ...
                                 obj.Parent.getPinNumber(obj.SCLPin), ...
                                 obj.Parent.getPinNumber(obj.SPIChipSelectPin), ...
                                 obj.BitRate, ...
                                 obj.ActiveLevel, ...
                                 controller, ...
                                 SPIRegisterSize, ...
                                 obj.SPIMode, ...
                                 obj.BitOrder);
                throwIOProtocolExceptionsHook(obj.Parent, 'openSPI', status);
            catch e
                if strcmpi(e.identifier,'ioserver:general:CFunctionNotFound')
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'SPI');
                else
                    throwAsCaller(e);
                end
            end
        end

        function stopSPI(obj)
            try
                status = closeSPI(obj.SPIDriverObj, ...
                                  obj.Parent.Protocol, ...
                                  obj.Parent.getSPIBusAliasImpl(obj.Bus, obj.SPIChipSelectPin), ...
                                  obj.Parent.getPinNumber(obj.SDOPin), ...
                                  obj.Parent.getPinNumber(obj.SDIPin), ...
                                  obj.Parent.getPinNumber(obj.SCLPin), ...
                                  obj.Parent.getPinNumber(obj.SPIChipSelectPin));
                throwIOProtocolExceptionsHook(obj.Parent, 'closeSPI', status);
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

            obj.Parent.showSPIProperties(obj.Interface, obj.SPIChipSelectPin, obj.SCLPin, obj.SDIPin, obj.SDOPin, obj.SPIMode, obj.ActiveLevel, obj.BitOrder, obj.BitRate, false);

            footer = matlabshared.hwsdk.internal.footer(inputname(1));

            if ~isempty(footer)
                disp(footer);
            end
            fprintf('\n');
        end

        function pinsWithLabel = getDevicePinWithLabelImpl(obj)
            pinsWithLabel = getDevicePinsWithLabel(obj.Parent.PinValidator, obj.Interface, SCL=obj.SCLPin, SDI=obj.SDIPin, SDO=obj.SDOPin);
        end
    end

    methods(Hidden, Access = public)
        function showAllProperties(obj)
            fprintf('\n');
            obj.Parent.showSPIProperties(obj.Interface, obj.SPIChipSelectPin, obj.SCLPin, obj.SDIPin, obj.SDOPin, obj.SPIMode, obj.ActiveLevel, obj.BitOrder, obj.BitRate, true);
        end

        function showFunctions(~)
            fprintf('\n');
            fprintf('   writeRead\n');
            fprintf('\n');
        end
    end
end

% LocalWords:  SPI Addon fullpath msbfirst lsbfirst arduinoio spi dev MCU's
% LocalWords:  SCL SDI SDO
