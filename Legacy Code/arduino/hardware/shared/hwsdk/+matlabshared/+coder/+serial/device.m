classdef device < matlabshared.coder.rawDevice.device
%

% Copyright 2020-2022 The MathWorks, Inc.

%#codegen

    properties(GetAccess = public, SetAccess = protected)
        % Port - Specifies the serial port for connection
        SerialPort uint8

        % TxPin and RxPin on Hardware
        TxPin char
        RxPin char
    end

    properties(Access = public)
        % Timeout - Specifies the waiting time (in seconds) to complete send
        % and receive operations.
        Timeout double
    end

    properties (GetAccess = public, SetAccess = private)
        % NumBytesAvailable - Number of bytes available to read
        NumBytesAvailable uint16
    end

    properties(Access = protected)
        SerialDriverObj
    end

    methods(Hidden, Access = public)
        function obj = device(varargin)
            obj@matlabshared.coder.rawDevice.device(varargin{:});
            parms = struct('SerialPort', uint32(0), 'BaudRate', uint32(0), 'DataBits', uint32(0), ...
                           'Parity', uint32(0), 'StopBits', uint32(0), 'Timeout', uint32(0));
            poptions = struct('CaseSensitivity',false, 'PartialMatching','unique', ...
                              'StructExpand',false);
            pstruct = coder.internal.parseParameterInputs(parms,poptions,varargin{2:end});  % First element is hardware object
            coder.internal.assert(pstruct.SerialPort ~=0, 'MATLAB:InputParser:ParamMissingValue', 'SerialPort');
            tempSerialPort = coder.internal.getParameterValue(pstruct.SerialPort,[],varargin{2:end});
            obj.SerialPort = obj.validateSerialPort(tempSerialPort);
            coder.internal.errorIf(pstruct.BaudRate ~=0, 'MATLAB:hwsdk:general:BaudRateNotSupported');
            coder.internal.errorIf(pstruct.DataBits ~=0, 'MATLAB:hwsdk:general:DataBitsNotSupported');
            coder.internal.errorIf(pstruct.Parity ~=0, 'MATLAB:hwsdk:general:ParityNotSupported');
            coder.internal.errorIf(pstruct.StopBits ~=0, 'MATLAB:hwsdk:general:StopBitsNotSupported');
            % In code generation default value for timeout is 0. In case of
            % IO it is 1.
            obj.Timeout = obj.validateTimeout(coder.internal.getParameterValue(pstruct.Timeout,0,varargin{2:end}));

            serialPins = getAvailableSerialPins(obj.Parent);
            obj.TxPin = serialPins(obj.SerialPort+1).TxPin;
            obj.RxPin = serialPins(obj.SerialPort+1).RxPin;
            obj.SerialDriverObj = getSerialDriverObj(obj.Parent);
            startSerial(obj);
        end
    end

    methods
        function num = get.NumBytesAvailable(obj)
            num = getNumBytesAvailableHook(obj);
        end
    end

    methods(Sealed, Access = public)
        function dataOut = read(obj,varargin)
            coder.internal.assert(nargin>=2, 'MATLAB:minrhs');
            coder.internal.assert(nargin<=3, 'MATLAB:maxrhs');
            if nargin==2
                coder.internal.assert(isnumeric(varargin{1})||ischar(varargin{1})||isstring(varargin{1}),...
                                      'MATLAB:hwsdk:general:IntegerType');
                if isnumeric(varargin{1})
                    count = varargin{1};
                    precision = "uint8";
                else
                    count = 1;
                    precision = varargin{1};
                end
            else  % nargin==3
                count = varargin{1};
                precision = varargin{2};
            end
            precision = obj.validatePrecision(precision);
            count = obj.validateCount(count);
            dataOut = obj.readHook(count, precision);
        end

        function write(obj, dataIn, precision)
            coder.internal.assert(nargin>=2, 'MATLAB:minrhs');
            if nargin<3
                if isnumeric(dataIn) && isvector(dataIn) && isinteger(dataIn)
                    precision = class(dataIn);
                    data = dataIn;
                elseif isstring(dataIn) || ischar(dataIn)
                    data = uint8(char(dataIn));
                    precision = "uint8";
                else
                    data = dataIn;
                    precision = "uint8";
                end
            else
                data = dataIn;
                precision = obj.validatePrecision(precision);
            end
            obj.writeHook(data, precision);
        end
    end

    methods(Access = protected)
        function dataOut = readHook(obj, count, precision)
            numBytes = uint8(count * obj.SIZEOF.(char(precision)));
            output = sciReceiveBytesInternal(obj.SerialDriverObj, obj.SerialPort, numBytes);
            dataOut = uint8(output(1:end));
            dataOut = (typecast(dataOut, char(precision)))';
        end

        function writeHook(obj, dataIn, precision)
        % This validation will be done in compilation time only.
        % Checking is not possible at runtime.
            coder.internal.assert(all(dataIn>=intmin(char(precision))) && all(dataIn<=intmax(char(precision))),...
                                  'MATLAB:hwsdk:general:invalidIntValueRanged', 'Serial data', intmin(char(precision)),...
                                  intmax(char(precision)));
            % At runtime if the data exceeds the bound of the specified data
            % type 'cast' function will clip that.
            dataIn = cast(dataIn, char(precision));
            dataIn = typecast(dataIn, 'uint8');
            numBytes = (numel(dataIn));
            sciTransmitBytesInternal(obj.SerialDriverObj, obj.SerialPort, dataIn, numBytes);
        end

        function num = getNumBytesAvailableHook(obj)
            num = getSCIStatusInternal(obj.SerialDriverObj, obj.SerialPort);
        end
    end

    methods(Access = private)
        function startSerial(obj)
            openSCIBusInternal(obj.SerialDriverObj, obj.SerialPort, obj.RxPin, obj.TxPin);
        end

        function stopSerial(obj)
            sciCloseInternal(obj.SerialDriverObj, obj.SerialPort);
        end

        function result = validatePrecision(obj, precision)

            if isstring(precision)
                precisionChar = char(precision);
            else
                precisionChar = precision;
            end
            result = validatestring(precisionChar, obj.Parent.getAvailableSerialPrecisions(), '', 'precision');

        end

        function count = validateCount(~, count)
            coder.internal.assert(isnumeric(count) && count > 0 && isscalar(count),...
                                  'MATLAB:hwsdk:general:IntegerType');
        end

        function serialPort = validateSerialPort(obj, serialPort)
            validateattributes(serialPort, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
            supportedPorts = obj.Parent.getAvailableSerialPortIDs();
            coder.internal.assert(ismember(serialPort, supportedPorts), 'MATLAB:hwsdk:general:unsupportedPort', serialPort, obj.Parent.getBoardName(), num2str(supportedPorts));
        end

        function timeout = validateTimeout(obj, timeout)
            validateattributes(timeout, {'numeric'}, {'scalar', 'real', 'finite', 'nonnan', 'nonnegative'}, '', 'Serial timeout');
            timeoutRange = obj.Parent.getSupportedTimeOut();
            coder.internal.assert(timeout >= timeoutRange(1) && timeout <= timeoutRange(2), 'MATLAB:hwsdk:general:invalidTimeOutValue',...
                                  timeout, timeoutRange(1), timeoutRange(2));
        end
    end
end
