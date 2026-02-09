classdef device < matlabshared.coder.rawDevice.device
%

% Copyright 2019-2023 The MathWorks, Inc.

%#codegen

    properties(GetAccess = public, SetAccess = protected)
        % Avoiding double in code generation as it creates a floating point
        % number in generated C code, which makes the processing of such
        % data difficult on the hardware
        I2CAddress uint8
        Bus uint8
    end

    properties(Access = {?matlabshared.coder.hwsdk.controller})
        I2CDriverObj
    end

    methods
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
        %       tmp102 = device(a,'I2CAddress','0x25','Bus',1);
        %   Input Arguments:
        %   a       - Arduino object
        %   address - I2C address of device (numeric or character vector or string)
        %
        %   Name-Value Pair Input Arguments:
        %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value.
        %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
        %
        %   NV Pair:
        %   'bus'     - The I2C bus (numeric, default 1)
        %

            obj@matlabshared.coder.rawDevice.device(varargin{:});
            % varargin{2}  is 'I2CAddress'. Validate with parser
            parms = struct('I2CAddress', uint32(0), 'Bus', uint32(0), 'BitRate', uint32(0));
            poptions = struct('CaseSensitivity',false, 'PartialMatching','unique', ...
                              'StructExpand',false);
            pstruct = coder.internal.parseParameterInputs(parms,poptions,varargin{2:end});  % First element is hardware object
            coder.internal.assert(pstruct.I2CAddress ~= 0,'MATLAB:InputParser:ParamMissingValue', 'I2CAddress');
            tempI2CAddress = coder.internal.getParameterValue(pstruct.I2CAddress,[],varargin{2:end});
            obj.I2CAddress = validateI2CAddress(obj, tempI2CAddress);
            tempBus = coder.internal.getParameterValue(pstruct.Bus, obj.Parent.getHwsdkDefaultI2CBusIDHook(),varargin{2:end});
            obj.Bus = obj.validateI2CBus(tempBus);
            coder.internal.errorIf(pstruct.BitRate ~=0, 'MATLAB:hwsdk:general:I2CBitRateNotSupportedForNVPair')
            obj.I2CDriverObj = getI2CDriverObj(obj.Parent, obj.Bus);
            startI2C(obj);
        end
    end

    methods(Access = public)
        function data = read(obj, varargin)
            coder.internal.errorIf(nargin<2, 'MATLAB:minrhs');
            coder.internal.errorIf(nargin>3, 'MATLAB:maxrhs');
            if(nargin == 2)
                if(isnumeric(varargin{1}))
                    count = varargin{1};
                    precision = "uint8";
                elseif(ischar(varargin{1})||isstring(varargin{1}))
                    count = 1;
                    precision = string(varargin{1});
                end
            else  % nargin == 3
                coder.internal.errorIf( ~isnumeric(varargin{1}), 'MATLAB:hwsdk:general:IntegerType');
                count = varargin{1};
                precision = varargin{2};
            end
            precision = obj.validatePrecision(precision);
            data = obj.readHook(count, precision);
        end

        function write(obj, dataIn, precision)
            coder.internal.errorIf(nargin<2, 'MATLAB:minrhs');
            coder.internal.errorIf(nargin>3, 'MATLAB:maxrhs');
            if(nargin < 3)
                if isnumeric(dataIn) && isvector(dataIn) && isinteger(dataIn)
                    precision = string(class(dataIn));
                    data = dataIn;
                else
                    precision = "uint8";
                    if isstring(dataIn)||ischar(dataIn)
                        data = uint8(char(dataIn));
                    else
                        data = dataIn;
                    end
                end
            else
                data = dataIn;
            end
            precision = obj.validatePrecision(precision);
            %TODO validate the data
            obj.writeHook(data, precision);
        end

        function data = readRegister(obj, register, varargin)
            coder.internal.errorIf(nargin<2, 'MATLAB:minrhs');
            coder.internal.errorIf(nargin>4, 'MATLAB:maxrhs');
            validatedRegister = obj.validateRegisterAddress(register);
            if nargin<3
                count = 1;
                precision = "uint8";
            elseif nargin <4
                if isnumeric(varargin{1})
                    count = varargin{1};
                    precision = "uint8";
                else
                    count = 1;
                    precision = varargin{1};
                end
            elseif(nargin == 4)
                coder.internal.errorIf(isstring(varargin{1}) || ischar(varargin{1}), 'MATLAB:maxrhs');
                if isnumeric(varargin{1})
                    % varargin1 -> count, varargin2 -> precision
                    count = varargin{1};
                    precision = varargin{2};
                    %                     count = obj.validateCount(count, precision);
                end
            end
            precision = obj.validatePrecision(precision);
            data = obj.readRegisterHook(validatedRegister, count, precision);
        end

        function writeRegister(obj, register, dataIn, precision)
            coder.internal.errorIf(nargin<3, 'MATLAB:minrhs');
            coder.internal.errorIf(nargin>4, 'MATLAB:maxrhs');
            validatedRegister = obj.validateRegisterAddress(register);
            if nargin < 4
                if isnumeric(dataIn) && isvector(dataIn) && isinteger(dataIn)
                    precision = string(class(dataIn));
                    data = dataIn;
                else
                    if isstring(dataIn) || ischar(dataIn)
                        data = uint8(char(dataIn));
                        precision = "uint8";
                    else
                        data = dataIn;
                        precision = "uint8";
                    end
                end
            else
                data = dataIn;
            end
            precision = obj.validatePrecision(precision);
            %TODO validate data
            obj.writeRegisterHook(validatedRegister, data, precision);
        end
    end

    methods(Access = protected)
        function startI2C(obj)
            openI2CBus(obj.I2CDriverObj, obj.Parent.getI2CBusInfo(obj.Bus));
        end

        function stopI2C(obj)
            closeI2CBus(obj.I2CDriverObj);
        end

        function data = readHook(obj, count, precision)
            numBytes = uint8(count * obj.SIZEOF.(char(precision)));
            data = rawI2CRead(obj.I2CDriverObj, obj.I2CAddress, numBytes);
            data = typecast(data, char(precision));
            data = data';
        end

        function writeHook(obj, dataIn, precision)
            dataIn = cast(dataIn, char(precision));
            dataIn = typecast(dataIn, 'uint8');
            %TODO check if the length of data exceeds I2CBuffer size
            rawI2CWrite(obj.I2CDriverObj, obj.I2CAddress, dataIn);
        end

        function data = readRegisterHook(obj, registerAddress, count, precision)
            numBytes = uint8(count * obj.SIZEOF.(char(precision)));
            output = registerI2CRead(obj.I2CDriverObj, obj.I2CAddress, registerAddress, numBytes);
            output = typecast(output, char(precision));
            data = output';
        end

        function writeRegisterHook(obj, registerAddress, dataIn, precision)
            dataIn = cast(dataIn, char(precision));
            dataIn = typecast(dataIn, 'uint8');
            registerI2CWrite(obj.I2CDriverObj, obj.I2CAddress, registerAddress, dataIn);
        end
    end

    methods(Access = private)

        function result = validateI2CAddress(obj, I2CAddress)
            coder.internal.assert(isnumeric(I2CAddress)&&isscalar(I2CAddress)&&isreal(I2CAddress) || isstring(I2CAddress) || ischar(I2CAddress), 'MATLAB:hwsdk:general:invalidAddressValueCodegen', num2str(I2CAddress));
            if(ischar(I2CAddress)||isstring(I2CAddress))
                tmpI2CAddress = char(I2CAddress);
                if ((length(tmpI2CAddress)>2) && strcmpi(tmpI2CAddress(1:2), '0x'))
                    tmp1 = tmpI2CAddress(3:end);
                else
                    tmp1 = tmpI2CAddress;
                end
                if strcmpi(tmp1(end), 'h')
                    result = hex2dec(tmp1(1:end-1));
                else
                    result = hex2dec(tmp1);
                end
            else
                result = I2CAddress;
            end
            coder.internal.errorIf((result < obj.Parent.getMinI2CAddress)||(result > obj.Parent.getMaxI2CAddress), 'MATLAB:hwsdk:general:invalidIntValueRanged', 'I2C device address', num2str(obj.Parent.getMinI2CAddress), num2str(obj.Parent.getMaxI2CAddress));
        end

        function validatedRegisterAddress = validateRegisterAddress(~, registerAddress)
        % Register address could be numeric or hexadecimal in string or
        % character value
            coder.internal.assert(isnumeric(registerAddress)&&isscalar(registerAddress)&&isreal(registerAddress)...
                                  || isstring(registerAddress) || ischar(registerAddress), ...
                                  'MATLAB:hwsdk:general:invalidAddressValueCodegen', num2str(registerAddress));
            if(ischar(registerAddress)||isstring(registerAddress))
                tmpRegisterAddress = char(registerAddress);
                if ((length(tmpRegisterAddress)>2) && strcmpi(tmpRegisterAddress(1:2), '0x'))
                    tmp1 = tmpRegisterAddress(3:end);
                else
                    tmp1 = tmpRegisterAddress;
                end
                if strcmpi(tmp1(end), 'h')
                    result = hex2dec(tmp1(1:end-1));
                else
                    result = hex2dec(tmp1);
                end
            else
                result = registerAddress;
            end
            % Register address should be within the range [0, 255]
            coder.internal.errorIf(result < 0 || result > 255, 'MATLAB:hwsdk:general:invalidIntValueRanged', 'I2C register address', 0, 255);
            validatedRegisterAddress = uint8(result);
        end

        function result = validatePrecision(obj, precision)
            if isstring(precision)
                precisionChar = char(precision);
            else
                precisionChar = precision;
            end
            result = validatestring(precisionChar, obj.Parent.getAvailableI2CPrecisions(), '', 'precision');
        end

        function bus = validateI2CBus(obj, bus)
            buses = coder.const(obj.Parent.getAvailableI2CBusIDs());
            coder.internal.assert(isnumeric(bus) && isscalar(bus) && isreal(bus) &&  bus>=0 && floor(bus)==bus , ...
                                  'MATLAB:hwsdk:general:invalidBusTypeNumeric', 'I2C', num2str(buses));
            coder.internal.assert(ismember(bus, buses), 'MATLAB:hwsdk:general:invalidBusValue', 'I2C', num2str(buses));
        end
    end
end
