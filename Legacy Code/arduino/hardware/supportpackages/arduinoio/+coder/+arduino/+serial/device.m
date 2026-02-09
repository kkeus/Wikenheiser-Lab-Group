classdef device < matlabshared.coder.serial.device
    
    %#codegen
    
    % Copyright 2020 The MathWorks, Inc.
    
    methods
        function obj = device(varargin)
            % The parser below checks if 'BaudRate', 'Parity', 'StopBits'
            % or 'DataBits' are passed as a parameter and throws
            % appropriate error at the compile time. These error messages
            % are different from the ones thrown in its superclass due to
            % same validation.
            parms = struct('SerialPort', uint32(0), 'BaudRate', uint32(0), 'DataBits', uint32(0), ...
                'Parity', uint32(0), 'StopBits', uint32(0), 'Timeout', uint32(0));
            poptions = struct('CaseSensitivity',false, 'PartialMatching','unique', ...
                'StructExpand',false);
            pstruct = coder.internal.parseParameterInputs(parms,poptions,varargin{2:end});  % First element is hardware object            
            coder.internal.errorIf(pstruct.BaudRate ~=0, 'MATLAB:arduinoio:general:BaudRateNotSupported');
            coder.internal.errorIf(pstruct.DataBits ~=0, 'MATLAB:arduinoio:general:DataBitsNotSupported');
            coder.internal.errorIf(pstruct.Parity ~=0, 'MATLAB:arduinoio:general:ParityNotSupported');
            coder.internal.errorIf(pstruct.StopBits ~=0, 'MATLAB:arduinoio:general:StopBitsNotSupported');
            % Send the arguments to its superlcass constructor for
            % validation and setting appropriate properties.
            obj@matlabshared.coder.serial.device(varargin{:});
        end
    end
    
    
    methods(Access = protected)
        function dataOut = readHook(obj, count, precision)
            numBytes = uint8(count * obj.SIZEOF.(char(precision)));
            if obj.Timeout ~= 0
                startTime = obj.getCurrentTime();
                while( obj.NumBytesAvailable < numBytes && obj.timeLapsedSince(startTime) < obj.Timeout*1000)
                    % Stay in loop till required amount of data is
                    % available or timeout.
                end
                % Return numBytes bytes of data if available. Else return
                % zeros.
                if obj.NumBytesAvailable >= numBytes
                    data = sciReceiveBytesInternal(obj.SerialDriverObj, obj.SerialPort,...
                        numBytes, numBytes, "uint8");
                else
                    data = uint8(zeros(numBytes, 1));
                end
            else
                data = sciReceiveBytesInternal(obj.SerialDriverObj, obj.SerialPort,...
                    numBytes, numBytes, "uint8");
            end
            dataOut = (typecast(data, precision))';
        end
        
        function writeHook(obj, dataIn, precision)
            % This validation will be done in compilation time only.
            % Checking is not possible at runtime.
            coder.internal.assert(all(dataIn>=intmin(char(precision))) && all(dataIn<=intmax(char(precision))),...
                'MATLAB:hwsdk:general:invalidIntValueRanged', 'Serial data', intmin(char(precision)),...
                intmax(char(precision)));
            % At runtime if the data exceeds the bound of the secified data
            % type 'cast' function will clip that.
            dataIn = cast(dataIn, char(precision));
            dataIn = typecast(dataIn, 'uint8');
            sciTransmitBytesInternal(obj.SerialDriverObj, obj.SerialPort, dataIn);
        end
        
        function result = getNumBytesAvailableHook(obj)
            result = coder.nullcopy(0);
            result = coder.ceval('getNumbytesAvailable', obj.SerialPort);
        end
    end
    
    methods(Access = private)
        function time = getCurrentTime(~)
            % Returns time since the beginning of program execution in
            % milliseconds.
            time = coder.nullcopy(uint32(0));
            time = coder.ceval('getCurrentTime');
        end
        
        function res = timeLapsedSince(obj, startTime)
            % Finds the difference between current time and startTime in
            % milliseconds.
            res = obj.getCurrentTime() - startTime;
        end
    end
end