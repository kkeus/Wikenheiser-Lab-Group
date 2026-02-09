classdef device < matlabshared.coder.rawDevice.device
%

% Copyright 2019-2023 The MathWorks, Inc.

%#codegen

    properties(Hidden, GetAccess = public, SetAccess = protected)
        Bus uint8
    end

    properties(GetAccess = public, SetAccess = protected)
        SPIChipSelectPin   % This property holds the string passes by the user
        ActiveLevel
    end

    properties(Access = protected)
        SCLPin = matlabshared.coder.internal.CodegenID.PinNotFound;
        SDIPin = matlabshared.coder.internal.CodegenID.PinNotFound;
        SDOPin = matlabshared.coder.internal.CodegenID.PinNotFound;
        SPIChipSelectPinInternal  % Holds the numeric value of the pin
    end

    properties(Access = private, Constant)
        % The values could be calculated from the SIZEOF structure above.
        % But that will be a costly operation on target.
        MAXVAL = struct('int8', 2^8-1, 'uint8', 2^8-1, 'int16', 2^16-1, 'uint16', 2^16-1, ...
                        'int32', 2^32-1, 'uint32', 2^32-1, 'int64', 2^64-1, 'uint64', 2^64-1)
    end

    properties(Access = protected)
        SPIDriverObj
    end

    methods(Access = public)
        function obj = device(varargin)
            obj@matlabshared.coder.rawDevice.device(varargin{:});
            parms = struct('SPIChipSelectPin', uint32(0), 'Bus', uint32(0), 'ActiveLevel', uint32(0), ...
                           'SPIMode', uint32(0), 'BitOrder', uint32(0), 'BitRate', uint32(0));
            poptions = struct('CaseSensitivity',false, 'PartialMatching','unique', ...
                              'StructExpand',false);
            pstruct = coder.internal.parseParameterInputs(parms,poptions,varargin{2:end});  % First element is hardware object
            coder.internal.assert(pstruct.SPIChipSelectPin ~=0, 'MATLAB:InputParser:ParamMissingValue', 'SPIChipSelectPin');
            chipSelectPinTemp = coder.internal.getParameterValue(pstruct.SPIChipSelectPin, [], varargin{2:end});
            obj.SPIChipSelectPin = chipSelectPinTemp;
            obj.SPIChipSelectPinInternal = obj.validateSPIChipSelectPin(chipSelectPinTemp);
            configurePin(obj.Parent, chipSelectPinTemp, "DigitalOutput");
            obj.Bus = validateSPIBus(obj, coder.internal.getParameterValue(pstruct.Bus, 1, varargin{2:end}));
            obj.ActiveLevel = coder.internal.getParameterValue(pstruct.ActiveLevel, 'low', varargin{2:end});
            % For code generation BitRate, SPIMode and BitOrder, the values
            % are picked up from model configuration settings
            coder.internal.errorIf(pstruct.BitRate ~=0, 'MATLAB:hwsdk:general:BitRateNotSupportedForNVPair');
            coder.internal.errorIf(pstruct.SPIMode ~=0, 'MATLAB:hwsdk:general:SPIModeNotSupportedForNVPair');
            coder.internal.errorIf(pstruct.BitOrder ~=0, 'MATLAB:hwsdk:general:BitOrderNotSupportedForNVPair');
            obj.SPIDriverObj = getSPIDriverObj(obj.Parent, obj.Bus);
            startSPI(obj);
        end
    end

    methods(Access = public)
        function data = read(~, varargin)
            data = 0;
        end

        function write(varargin)
        end

        function dataOut = writeRead(obj, varargin)
            coder.internal.narginchk(2, 3, nargin);
            if nargin ==3
                dataIn = varargin{1};
                precision = obj.validatePrecision(varargin{2});
            else
                % string input cannot be converted to a numeric by
                % typecasting. Convert it to a character first and then to
                % uint8.
                if isstring(varargin{1}) || ischar(varargin{1})
                    dataIn = uint8(char(varargin{1}));
                else
                    dataIn = varargin{1};
                end
                precision = 'uint8';
            end

            maxValue = obj.MAXVAL.(char(precision));
            % Check if the data is in the range for the given data type
            coder.internal.assert(all(dataIn >= 0) && all(dataIn <= maxValue), ...
                                  'MATLAB:hwsdk:general:invalidIntValueRanged', 'SPI data', 0, maxValue);
            dataOut = writeReadHook(obj, dataIn, precision);
        end
    end

    methods(Access = protected)
        function dataOut = writeReadHook(obj, dataIn, precision)
        % In run-time it is not possible to throw any error. In that
        % case clip the data in the range [0, maxValue]
            castData = cast(dataIn, char(precision));
            dataTowrite = typecast(castData, 'uint8');
            returnedData = coder.nullcopy(uint8(zeros(size(dataTowrite))));
            % Pull the chip select pin to low/high based on the Active
            % level
            if strcmpi(obj.ActiveLevel, "low")
                writeDigitalPinInternal(obj.Parent.DigitalIODriverObj, obj.SPIChipSelectPinInternal, 0);
            else
                writeDigitalPinInternal(obj.Parent.DigitalIODriverObj, obj.SPIChipSelectPinInternal, 1);
            end
            % writeReadSPI will always return uint8 data.
            writeReadSPI(obj.SPIDriverObj, dataTowrite, returnedData);
            % Pull the chip select pin back to high/low based on the Active
            % level
            if strcmpi(obj.ActiveLevel, "low")
                writeDigitalPinInternal(obj.Parent.DigitalIODriverObj, obj.SPIChipSelectPinInternal, 1);
            else
                writeDigitalPinInternal(obj.Parent.DigitalIODriverObj, obj.SPIChipSelectPinInternal, 0);
            end
            if strcmpi(char(precision), 'uint8')
                % For uint8 data type no swapping or typecasting is
                % required
                dataOut = returnedData;
            else
                dataOut = typecast(returnedData, precision);
            end
        end

        function f = getSPIClockFreq(obj)
            f = obj.Parent.getSPIClockFrequency();
        end
    end

    methods(Access = private)

        function startSPI(obj)
            openSPI(obj.SPIDriverObj, obj.Parent.getSPIBusAlias(obj.Bus), obj.SDOPin, obj.SDIPin, obj.SCLPin, obj.SPIChipSelectPinInternal);
        end

        function stopSPI(obj)
            closeSPI(obj.SPIDriverObj, obj.SDOPin, obj.SDIPin, obj.SCLPin, obj.SPIChipSelectPinInternal);
        end

        function result = validateSPIChipSelectPin(obj, pin)
            result = obj.Parent.validateDigitalPinNumberHook(pin);
            coder.internal.errorIf(result == matlabshared.coder.internal.CodegenID.PinNotFound,...
                                   'MATLAB:hwsdk:general:invalidDigitalPinNumberCodegen', pin);
        end

        function busNum = validateBus(obj, bus)
            coder.internal.assert(isnumeric(bus) && isreal(bus) && isscalar(bus) && ~isinteger(bus) && bus>=0,...
                                  'MATLAB:hwsdk:general:invalidBusTypeNumeric', 'SPI', 'AvailableSPIBuses');
            busNum = matlabshared.coder.internal.CodegenID.BusIDNotFound;
            availableBuses = obj.Parent.AvailableSPIBusIDs;
            for iterator = 1:numel(availableBuses)
                if(bus == availableBuses(iterator))
                    busNum = uint8(bus);
                    break;
                end
            end
            coder.internal.errorIf(busIdFound == matlabshared.coder.internal.CodegenID.BusIDNotFound, ...
                                   'MATLAB:hwsdk:general:invalidBusValue', 'SPI', 'AvailableSPIBuses');
        end

        function result = validateActiveLevel(~, level)
            activeLevels = {'low', 'high'};
            if isstring(level)
                levelChar = char(level);
            else
                levelChar = level;
            end
            coder.internal.assert(ischar(levelChar), 'MATLAB:hwsdk:general:invalidActiveLevelType', 'SPI', 'string', "low, high");
            result = validatestring(level, activeLevels, '', 'ActiveLevel');
        end

        function result = validateSPIMode(~, mode)
            validateattributes(mode, {'double', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}, ...
                               {'scalar', 'integer', 'real', 'finite', 'nonnan'},'', 'SPIMode')
            min = 0;
            max = 3;
            coder.internal.assert(mode>=min && mode<=max, 'MATLAB:hwsdk:general:invalidIntValueRanged', ...
                                  'SPIMode', num2str(min), num2str(max));
            result = mode;
        end

        function result = validateBitOrder(~, order)
            validBitOrder = {'msbfirst', 'lsbfirst'};
            if isstring(order)
                orderChar = char(order);
            else
                orderChar = order;
            end
            coder.internal.assert(ischar(orderChar), 'MATLAB:hwsdk:general:invalidBitOrderType', 'SPI', 'string', "msbfirst, lsbfirst");
            result = validatestring(order, validBitOrder, '', 'BitOrder');
        end

        function result = validateBitRate(~, bitRate)
            coder.internal.assert(isnumeric(bitRate) && isscalar(bitRate) && isreal(bitRate) && isfinite(bitRate) ...
                                  && ~isnan(bitRate) && (bitRate>0), 'MATLAB:hwsdk:general:invalidBitRateType', 'SPI');
            result = bitRate;
        end

        function result = validatePrecision(obj, precision)
            if isstring(precision)
                precisionChar = char(precision);
            else
                precisionChar = precision;
            end
            % Should the argument number be provided as the user can cal as
            % obj.methodName( ...) or methodName(obj, ...)
            result = validatestring(precisionChar, obj.Parent.getAvailableSPIPrecisions(), '', 'precision', 3);
        end
    end

    methods(Access = private)
        function result = validateSPIBus(obj, bus)
            buses = coder.const(obj.Parent.getAvailableSPIBusIDs());
            coder.internal.assert(isnumeric(bus) && isscalar(bus) && isreal(bus) &&  bus>=0 && floor(bus)==bus , ...
                                  'MATLAB:hwsdk:general:invalidBusTypeNumeric', 'SPI', num2str(buses));
            coder.internal.assert(ismember(bus, buses), 'MATLAB:hwsdk:general:invalidBusValue', 'SPI', num2str(buses));
            result = uint8(bus);
        end
    end
end
