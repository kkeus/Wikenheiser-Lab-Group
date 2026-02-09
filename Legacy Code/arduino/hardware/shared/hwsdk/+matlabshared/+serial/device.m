classdef device < matlabshared.rawDevice.device & ...
        matlab.mixin.CustomDisplay
% hwsdk device class

%   Copyright 2019-2024 The MathWorks, Inc.
    properties(GetAccess = public, SetAccess = protected)

        % Port - Specifies the serial port for connection
        SerialPort

        % TxPin and RxPin on Hardware
        TxPin
        RxPin

    end

    % gpsHardware class directly accesses SerialDriverObj property. So
    % giving the access to both the child class of serial device class and
    % gpsHardware class
    properties(Access = {?matlabshared.serial.device, ?matlabshared.sensors.internal.Accessor})
        SerialDriverObj = matlabshared.ioclient.peripherals.SCI;
    end

    properties(Access = public)

        % BaudRate - Specifies the baud rate (in bits per second) setting
        % for the serial port
        BaudRate

        % DataBits - Specifies the number of data bits for the serial port
        DataBits


        % StopBits - Specifies the number of stop bits for the serial port.
        % Valid values are 1, 1.5, and 2
        StopBits

        % Parity - Specifies the parity setting for the serial port. Valid
        % values are 'none', 'even', and 'odd'
        Parity

        % Timeout - Specifies the waiting time (in seconds) to complete send
        % and receive operations.
        Timeout = 1
    end

    properties(Access = private)
        DuplicateDevice
        UpdateTimeout logical=false
        IsStarted logical
    end


    properties(Access = protected, Constant = true)
        LibraryName = 'Serial'
        DependentLibraries = {}
        LibraryHeaderFiles = ''
        CppHeaderFile = ''
        CppClassName = 'MW_SCI'
    end

    properties(Access = private, Constant = true)
        START_SERIAL    = hex2dec('01')
        READ            = hex2dec('02')
        WRITE           = hex2dec('03')
        SIZEOF = struct('int8', 1, 'uint8', 1, 'int16', 2, 'uint16', 2, 'int32', 4, 'uint32', 4, 'int64', 8, 'uint64', 8)
    end


    properties (GetAccess = public, SetAccess = private, Dependent)
        % NumBytesAvailable - Number of bytes available to read
        NumBytesAvailable
    end

    properties (Access = private)
        % NumBytesWritten - Specifies the number of bytes sent to the serial
        % port since connection.
        NumBytesWritten = 0
    end

    methods(Access = protected)
        function delete(obj)
            try
                count = getDeviceResourceProperty(obj, obj.ResourceOwner, "Count");
                if isempty(count)
                    % Math operations aren't working on empty double. Wrkarnd.
                    count = 0;
                end
                setDeviceResourceProperty(obj, obj.ResourceOwner, "Count", count-1);
                if (count-1) == 0
                    stopSerial(obj);
                end
                % Construction failed, revert Serial pins back to their original states
                if ~isempty(obj.Undo) % only revert when pin configuration has changed
                    for idx = 1:numel(obj.Undo)
                        prevMode = configurePinInternal(obj.Parent, obj.Undo(idx).Pin);
                        if strcmpi(prevMode, 'Serial') && (count-1) == 0 % only revert when pin has successfully configured to I2C and no more devices present on bus
                            configurePinInternal(obj.Parent, obj.Undo(idx).Pin, 'Unset', 'serial.device', obj.ResourceOwner);
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
            if numBytes > obj.Parent.getMaxSerialReadWriteBufferSize
                obj.localizedError('MATLAB:hwsdk:general:maxDataInterface','Serial', num2str(floor(obj.Parent.getMaxSerialReadWriteBufferSize/obj.SIZEOF.(char(precision)))),char(precision));
            end
            try
                if obj.UpdateTimeout
                    setTimeout(obj);
                end
                [output,status] = sciReceiveBytesInternal(obj.SerialDriverObj, obj.Parent.Protocol, obj.SerialPort, uint32(numBytes));
                if status == 0 % Activelow status: 0 means success
                    dataOut = uint8(output(1:end));
                    dataOut = typecast(dataOut, char(precision));
                    try
                        % Cannot represent int > 2^53 using double
                        matlabshared.hwsdk.internal.validateIntArrayParameterRanged('dataOut', ...
                                                                                    dataOut, ...
                                                                                    -2^52, ...
                                                                                    2^52);
                        dataOut = double(dataOut);
                    catch
                    end
                elseif(status == 32)
                    obj.localizedError('MATLAB:hwsdk:general:unsuccessfulRead',matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(count), char(precision));
                else
                    obj.localizedError('MATLAB:hwsdk:general:unsuccessfulReadPartialDataAvailable',matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(count), char(precision), matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(floor(status/obj.SIZEOF.(char(precision)))));
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                end
                throwAsCaller(e);
            end
        end

        function writeHook(obj, dataIn, precision)
            dataIn = cast(dataIn, char(precision));
            dataIn = typecast(dataIn, 'uint8');
            numBytes = (numel(dataIn));
            if numBytes > obj.Parent.getMaxSerialReadWriteBufferSize
                obj.localizedError('MATLAB:hwsdk:general:maxDataInterface', 'Serial', num2str(floor(obj.Parent.getMaxSerialReadWriteBufferSize/obj.SIZEOF.(char(precision)))),char(precision));
            end
            try
                if obj.UpdateTimeout
                    setTimeout(obj);
                end
                status = sciTransmitBytesInternal(obj.SerialDriverObj, obj.Parent.Protocol, obj.SerialPort, dataIn, uint32(numBytes));
                if status  %Activelow status: 0 means success
                    obj.localizedError('MATLAB:hwsdk:general:unsuccessfulWrite',matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(numBytes), char(precision));
                else
                    obj.NumBytesWritten = numBytes;
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                end
                throwAsCaller(e);
            end
        end
    end

    methods
        function numBytes = get.NumBytesAvailable(obj)
            numBytes = getSCIStatusInternal(obj.SerialDriverObj, obj.Parent.Protocol, obj.SerialPort);
        end

        function set.NumBytesWritten(obj,numBytes)
            obj.NumBytesWritten = numBytes;
        end

        function set.Timeout(obj, timeout)
            try
                obj.Timeout = validateTimeout(obj,timeout);
            catch e
                throwAsCaller(e);
            end
        end

        function set.BaudRate(obj,baudRate)
            try
                obj.BaudRate = validateBaudRate(obj,baudRate);
                setBaudRate(obj);
            catch e
                throwAsCaller(e);
            end
        end

        function set.StopBits(obj,stopbits)
            try
                obj.StopBits = validateStopBits(obj,stopbits);
                setFrameFormat(obj);
            catch e
                throwAsCaller(e);
            end
        end

        function set.Parity(obj,parity)
            try
                obj.Parity = validateParity(obj,parity);
                setFrameFormat(obj);
            catch e
                throwAsCaller(e);
            end
        end

        function set.DataBits(obj,databits)
            try
                obj.DataBits = validateDataBits(obj,databits);
                setFrameFormat(obj);
            catch e
                throwAsCaller(e);
            end
        end
    end


    methods(Sealed, Access = public)
        function dataOut = read(obj,varargin)
            try
                % This is needed for data integration
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
                    c = onCleanup(@() integrateData(obj.Parent,'Serial',dprecision,dcount));
                end
                narginchk(2,3);
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

        function write(obj,dataIn,precision)
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
                    else
                        if (nargin > 2)
                            % This is needed for data integration
                            dprecision = precision;
                            ddataIn = dataIn;
                        end
                    end
                    % Register on clean up for integrating all data.
                    c = onCleanup(@() integrateData(obj.Parent,'Serial',dprecision,ddataIn));
                end
                narginchk(2,3);
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
    end

    methods(Hidden, Access = public)
        function obj = device(varargin)
            obj@matlabshared.rawDevice.device(varargin{:});
            obj.Interface = "Serial";
            narginchk(3,13);
            try
                p = inputParser;
                p.PartialMatching = true;
                addParameter(p, 'SerialPort', []);
                addParameter(p, 'BaudRate', 9600);
                addParameter(p, 'DataBits', 8);
                addParameter(p, 'Parity', 'none');
                addParameter(p, 'StopBits', 1);
                addParameter(p, 'Timeout', []);
                parse(p, varargin{2:end});
            catch e
                parameters = p.Parameters;
                if strcmp(e.identifier, 'MATLAB:InputParser:ParamMustBeChar')
                    nvPairs = cellfun(@ischar, varargin(4:end));
                    nvNames = nvPairs(1:2:end);
                    numericNVNames = find(~nvNames);
                    nonCharNVName = varargin{3+(numericNVNames(1)*2-1)};
                    if isnumeric(nonCharNVName)
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', num2str(nonCharNVName), 'Serial device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
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
                            obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'Serial device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                        end
                        obj.localizedError('MATLAB:InputParser:ParamMissingValue', str);
                      case 'MATLAB:InputParser:UnmatchedParameter'
                        parameters = p.Parameters;
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'Serial device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                      case 'MATLAB:InputParser:AmbiguousParameter'
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'Serial device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                    end
                end
            end
            obj.IsStarted = false;
            output = p.Results;
            % Serial Port is already validated in serial.controller.
            if isnumeric(output.SerialPort)
                obj.SerialPort = output.SerialPort;
            else
                obj.SerialPort = append(output.SerialPort, char(0));
            end
            obj.BaudRate = output.BaudRate;
            obj.Parity = validateParity(obj,output.Parity);
            obj.DataBits = validateDataBits(obj, output.DataBits);
            obj.StopBits = validateStopBits(obj, output.StopBits);
            if ~isempty(output.Timeout)
                % Update timeout only when specified by user. The property
                % already has a default. This setup is required because
                % Raspi doesn't support timeout and setter should be called
                obj.Timeout = validateTimeout(obj, output.Timeout);
            end
            obj.ResourceOwner = char(strcat("Serial",string(obj.SerialPort)));
            currentCount = getDeviceResourceProperty(obj, obj.ResourceOwner, "Count");
            if isempty(currentCount)
                % Math operations aren't working on empty double. Wrkarnd.
                currentCount = 0;
            end
            setDeviceResourceProperty(obj, obj.ResourceOwner, "Count", currentCount+1);
            if currentCount > 0
                if isnumeric(obj.SerialPort)
                    obj.localizedError('MATLAB:hwsdk:general:maxSerial',char(num2str(obj.SerialPort)), obj.Parent.Board);
                else
                    obj.localizedError('MATLAB:hwsdk:general:maxSerial',char(obj.SerialPort), obj.Parent.Board);
                end
            end

            serialPins = getAvailableSerialPins(obj.Parent);
            if isempty(serialPins)
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:notSupportedInterface', 'Serial', parentObj.getBoardNameHook);
            end
            if isnumeric(obj.SerialPort)
                obj.TxPin = serialPins(obj.SerialPort).TxPin{1};
                obj.RxPin = serialPins(obj.SerialPort).RxPin{1};
            else
                obj.TxPin = serialPins(1).TxPin;
                obj.RxPin = serialPins(1).RxPin;
            end
            % Configure Pins to Serial mode
            configurePins(obj, {obj.TxPin, obj.RxPin});
            startSerial(obj);
        end
    end


    methods(Access = private)
        function configurePinSerial(obj)
            iUndo = 0;
            serialPins = {obj.TxPin,obj.RxPin};
            try
                for pin = serialPins
                    [~, ~, pinMode, pinResourceOwner] = getPinInfoHook(obj.Parent, pin{:});
                    if strcmpi(pinMode, 'Serial') || strcmpi(pinMode, 'Unset')
                        if strcmp(pinResourceOwner, '') && strcmp(pinMode, 'Serial')
                            % Take the ownership from arduino if it is
                            % the resourceowner. If not, proceed with
                            % configuration.
                            configurePinInternal(obj.Parent, pin{:}, 'Unset', 'serial.device');
                        end
                        pinStatus = configurePinInternal(obj.Parent, pin{:}, 'Serial', 'serial.device', obj.ResourceOwner);
                        iUndo = iUndo + 1;
                        obj.Undo(iUndo) = pinStatus;
                    else
                        obj.localizedError('MATLAB:hwsdk:general:reservedSerialPins', ...
                                           char(obj.Parent.getHardwareName), obj.Parent.getBoardNameHook, serialPins{1}, serialPins{2}, pin{:}, pinMode, char(num2str(obj.SerialPort)));
                    end
                end
            catch e
                switch(e.identifier)
                  case 'MATLAB:hwsdk:general:serialConfigFailed'
                    obj.localizedError('MATLAB:hwsdk:general:serialConfigFailed');
                  case 'MATLAB:hwsdk:general:reservedSerialPins'
                    throw(e);
                end
            end
        end

        function startSerial(obj)
            try
                status = openSCIBusInternal(obj.SerialDriverObj, obj.Parent.Protocol, obj.SerialPort, getPinNumber(obj.Parent, obj.RxPin), getPinNumber(obj.Parent, obj.TxPin));
                % status is Active low, 0 indicates success
                if ~status
                    obj.IsStarted = true;
                    setBaudRate(obj);
                    if ismember(obj.Parent.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                        pause(1);
                    end
                    setFrameFormat(obj);
                    if obj.UpdateTimeout
                        setTimeout(obj);
                    end
                else
                    if isnumeric(obj.SerialPort)
                        serialDisp = matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(obj.SerialPort);
                    else
                        serialDisp = char(obj.SerialPort);
                    end
                    obj.localizedError('MATLAB:hwsdk:general:serialOpenFailed', char(obj.Parent.Board),serialDisp);
                end
            catch e
                if strcmpi(e.identifier,'ioserver:general:CFunctionNotFound')
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'Serial');
                else
                    throwAsCaller(e);
                end
            end
        end

        function stopSerial(obj)
            try
                status = sciCloseInternal(obj.SerialDriverObj, obj.Parent.Protocol, obj.SerialPort);
                if status ~= 0
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                end
            catch e
                throwAsCaller(e)
            end
        end

        function setBaudRate(obj)
            if obj.IsStarted
                status = setSCIBaudrateInternal(obj.SerialDriverObj, obj.Parent.Protocol, obj.SerialPort, obj.BaudRate);
                if status ~= 0
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                end
            end
        end

        function setFrameFormat(obj)
            if obj.IsStarted
                status = setSCIFrameFormatInternal(obj.SerialDriverObj, obj.Parent.Protocol, obj.SerialPort, obj.DataBits, obj.Parity, obj.StopBits);
                if status ~= 0
                    obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
                end
            end
        end

        function setTimeout(obj)
            status = setSCITimeOutInternal(obj.SerialDriverObj,obj.Parent.Protocol, obj.SerialPort, obj.Timeout*1000);
            if status ~= 0
                obj.localizedError('MATLAB:hwsdk:general:connectionIsLost');
            end
        end

        function result = validatePrecision(obj, precision)
            try
                if ischar(precision)
                    precision = string(precision);
                end
                result = validatestring(precision, obj.Parent.getAvailableSerialPrecisions(), '', 'precision');
            catch e
                if strcmp(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    id = 'MATLAB:hwsdk:general:invalidPrecision';
                    e = MException(id, ...
                                   getString(message(id, char(strjoin(obj.Parent.getAvailableSerialPrecisions, ', ')))));
                end
                throwAsCaller(e);
            end
        end

        function result = validateCount(obj, count, precision)
            if ~(isnumeric(count) && isscalar(count) && count > 0)
                obj.localizedError('MATLAB:hwsdk:general:IntegerType');
            end
            maxCount = floor(obj.Parent.getMaxSerialReadWriteBufferSize/matlabshared.hwsdk.internal.sizeof(precision));
            try
                result = matlabshared.hwsdk.internal.validateIntParameterRanged('count', ...
                                                                                count, ...
                                                                                1, ...
                                                                                maxCount);
            catch e
                switch e.identifier
                  case {'MATLAB:hwsdk:general:invalidIntTypeRanged'}
                    obj.localizedError('MATLAB:hwsdk:general:IntegerType');
                  otherwise
                    obj.localizedError('MATLAB:hwsdk:general:maxDataInterface','Serial', num2str(maxCount),char(precision));
                end
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
                validateattributes(dataIn,{'numeric','char','string'},{'nonempty'},'write','data',2);
            catch e
                throwAsCaller(e);
            end
        end

        function baudRate = validateBaudRate(obj, baudRate)
            try
                validateattributes(baudRate, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidBaudRateType');
            end
            if ~ismember(baudRate, obj.Parent.getSupportedBaudRates)
                obj.localizedError('MATLAB:hwsdk:general:invalidBaudRateValue', matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(baudRate),matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(obj.Parent.getSupportedBaudRates));
            end
        end

        function timeout = validateTimeout(obj,timeout)
            try
                validateattributes(timeout, {'numeric'}, {'scalar', 'real', 'finite', 'nonnan', 'nonnegative'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidTimeOutType');
            end
            timeoutRange = obj.Parent.getSupportedTimeOut;
            if ~(timeoutRange(1)<= timeout && timeout <= timeoutRange(2))
                obj.localizedError('MATLAB:hwsdk:general:invalidTimeOutValue', matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(timeout), matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(timeoutRange(1)), matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(timeoutRange(2)));
            end
            if ~obj.UpdateTimeout
                obj.UpdateTimeout = true;
            end
        end

        function parity = validateParity(obj, parity)
            try
                if isstring(parity)
                    parity = char(parity);
                end
                validateattributes(parity, {'char'}, {'nonempty'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidParityType');
            end

            try
                % Call validate string for partial and case insensitive match
                parity = validatestring(string(parity), obj.Parent.getSupportedParity);
            catch
                % Added error handling here keep the consistent behavior
                % for -ve workflows. See g2685669 for more info.
                if ~ismember(parity, obj.Parent.getSupportedParity)
                    obj.localizedError('MATLAB:hwsdk:general:invalidParityValue', parity, matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(obj.Parent.getSupportedParity,','));
                end
            end
        end

        function dataBits = validateDataBits(obj,dataBits)
            try
                validateattributes(dataBits, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidDataBitsType');
            end
            if ~ismember(dataBits, obj.Parent.getSupportedDataBits)
                obj.localizedError('MATLAB:hwsdk:general:invalidDataBitsValue', matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(dataBits),matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(obj.Parent.getSupportedDataBits));
            end
        end

        function stopBits = validateStopBits(obj, stopBits)
            try
                validateattributes(stopBits, {'numeric'}, {'scalar', 'real', 'finite', 'nonnan', 'nonnegative'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidStopBitsType');
            end
            if ~ismember(stopBits, obj.Parent.getSupportedStopBits)
                obj.localizedError('MATLAB:hwsdk:general:invalidStopBitsValue', num2str(stopBits),strjoin(arrayfun(@num2str, obj.Parent.getSupportedStopBits(), 'UniformOutput', false), ','));
            end
        end
    end

    methods (Access = protected)
        % Custom Display
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);

            obj.showProperties();

            footer = matlabshared.hwsdk.internal.footer(inputname(1));

            if ~isempty(footer)
                disp(footer);
            end
            fprintf('\n');
        end

        function showProperties(obj, showAll)

            if nargin < 2
                showAll = 0;
            end

            fprintf('             Interface: ''%s''\n', obj.Interface);
            fprintf('            SerialPort: %d\n', obj.SerialPort);
            fprintf('                 TxPin: ''%s''\n', obj.TxPin);
            fprintf('                 RxPin: ''%s''\n', obj.RxPin);
            fprintf('              BaudRate: %d (bits/s) \n', obj.BaudRate);
            fprintf('     NumBytesAvailable: %d \n', obj.NumBytesAvailable);

            if showAll
                fprintf('                Parity: ''%s'' \n', obj.Parity);
                fprintf('              StopBits: %d \n', obj.StopBits);
                fprintf('              DataBits: %d \n', obj.DataBits);
                fprintf('               Timeout: %d (s)\n', obj.Timeout);
            end

            fprintf('\n');
        end

        function pinsWithLabel = getDevicePinWithLabelImpl(obj)
            pinsWithLabel = getDevicePinsWithLabel(obj.Parent.PinValidator, obj.Interface, TxPin=obj.TxPin, RxPin=obj.RxPin);
        end
    end

    methods(Hidden, Access = public)

        function showAllProperties(obj)
            fprintf('\n');
            showProperties(obj,1);
        end

        function showFunctions(~)
            fprintf('\n');
            fprintf('   read\n');
            fprintf('   write\n');
            fprintf('\n');
        end
    end
end
