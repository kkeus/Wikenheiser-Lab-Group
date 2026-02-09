classdef (Hidden) ArduinoMCP2515 < arduinoio.MCP2515
    %ArduinoMCP2515 Provides hardware specific route for MCP2515

    %   Copyright 2019-2020 The MathWorks, Inc.
    
    properties(Access = protected, Constant = true)
        LibraryName = 'CAN'
        DependentLibraries = {'SPI'}
        LibraryHeaderFiles = 'ACAN2515/src/ACAN2515.h'
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'MCP2515Base.h')
        CppClassName = 'MCP2515Base'
    end
    
    properties(Access = private, Constant = true)
        ATTACH      = hex2dec('00')
        DETACH      = hex2dec('01')
        READ        = hex2dec('02')
        WRITE       = hex2dec('03')
    end
    
    properties(Constant, Access = protected)
        OscillatorFrequencies = arduinoio.internal.ArduinoConstants.OscillatorFrequenciesMCP2515;
        BusSpeeds = arduinoio.internal.ArduinoConstants.BusSpeedsMCP2515;
    end
    
    properties(Constant, Access = private)
        ExtendedMax = 2^29 - 1;
        StandardMax = 2^11 - 1;
        CANMaxDataLength = 8;
        ExtendedIndexInFrame = 1;
        IDStartIndexInFrame = 2;
        IDEndIndexInFrame = 5;
        RTRIndexInFrame = 6;
        LengthIndexInFrame = 7;
        DataStartIndexInFrame = 8;
    end
    
    methods
        function result = connect(obj, varargin)
            % varargin{1} = ChipSelectPinNumber
            % varargin{2} = InterruptPinNumber
            narginchk(3,3);
            payload = [varargin{:}, typecast(uint32(obj.OscillatorFrequency), 'uint8'), ...
                                typecast(uint32(obj.BusSpeed), 'uint8')];
            result = sendCommand(obj, obj.LibraryName, obj.ATTACH, payload);
            % IOClient returns values in a column vector.
            if 4 == size(result,1)
                obj.BusSpeed = cast(typecast(uint8([result(1), result(2), result(3), result(4)]), 'uint32'), 'double');
            else
                % Error condition
                switch result
                    case 1
                        obj.localizedError('MATLAB:arduinoio:can:noMCP2515', 'MCP2515');
                    otherwise
                        obj.localizedError('MATLAB:arduinoio:can:MCPinitializationFailure', result);
                end
            end
        end
        
        function disconnect(obj, varargin)
            narginchk(2, 2);
            payload = varargin{1};
            sendCommand(obj, obj.LibraryName, obj.DETACH, payload);
        end
        
        function tt = read(obj, varargin)
            narginchk(1,2);
            p = inputParser;
            % Non floating point finite numeric scalar
            addOptional(p, 'MaxMessages', 1, @(x) (isnumeric(x) && ~any(isnan(x)) && ~any(isinf(x)) && all(floor(x) == x) && all(ceil(x) == x) && (isscalar(x))));
            try
                parse(p, varargin{:});
            catch e
                switch e.identifier
                    case 'MATLAB:InputParser:ArgumentFailedValidation'
                        obj.localizedError('MATLAB:hwsdk:can:invalidmaxMessagesType', 'maxMessages');
                    otherwise
                        throwAsCaller(e);
                end
            end
            maxMessages = p.Results.MaxMessages;
            peripheralPayload = [];
            tt = [];
            % Implementing maxMessages in the host because it makes the
            % timetable creating easy.
            for index = 1:maxMessages
                result = sendCommand(obj, obj.LibraryName, obj.READ, peripheralPayload);
                if ~any(result)
                    if isempty(tt)
                        % Return an empty timetable if there is no message
                        % in the buffer
                        tt = timetable;
                    end
                    % Receive only until there is a message in the buffer
                    break;
                end
                % Parse the frame
                if result(obj.ExtendedIndexInFrame) == 1
                    Extended = true;
                else
                    Extended = false;
                end
                ID = typecast(uint8(result(obj.IDStartIndexInFrame:obj.IDEndIndexInFrame)), 'uint32');
                if result(obj.RTRIndexInFrame) == 1
                    Remote = true;
                else
                    Remote = false;
                end
                Length = uint8(result(obj.LengthIndexInFrame));
                if Length > 1
                    DataEndIndexInFrame = obj.DataStartIndexInFrame+Length-1;
                    Data = {uint8(result(obj.DataStartIndexInFrame:DataEndIndexInFrame)')};
                elseif Length == 1
                    Data = {uint8(result(obj.DataStartIndexInFrame))};
                else % Length == 0
                    Data = {uint8(0)};
                end
                Name = {char.empty};
                Signals = {struct.empty};
                Error = false;
                % Update table in every transaction
                Time = datetime('now', 'TimeZone', 'local', 'Format', 'dd-MMM-yyyy HH:mm:ss.SSS');
                if isempty(tt)
                    tt = timetable(Time, ID, Extended, Name, Data, Length, Signals, Error, Remote);
                else
                    tt = [tt; timetable(Time, ID, Extended, Name, Data, Length, Signals, Error, Remote)];
                end
            end
        end
        
        function write(obj, varargin)
            try
                narginchk(2,4);
                if isa(varargin{1}, 'can.Message')
                    canm = varargin{1};
                    try
                        identifier = canm.ID;
                        isExtended = canm.Extended;
                        dataArray = canm.Data;
                        % VNT is installed
                        % Accept only 2 arguments
                        narginchk(2,2);
                    catch e
                        switch e.identifier
                            case 'MATLAB:noSuchMethodOrField'
                                obj.localizedError('MATLAB:hwsdk:can:invalidCANIdentifierType');
                            otherwise
                                throwAsCaller(e);
                        end
                    end
                else
                    narginchk(4,4);
                    p = inputParser;
                    % Non floating point finite numeric scalar
                    addRequired(p, 'Identifier', @(x) (isnumeric(x) && ~any(isnan(x)) && ~any(isinf(x)) && all(floor(x) == x) && all(ceil(x) == x) && isscalar(x)));
                    try
                        parse(p, varargin{1});
                    catch
                        obj.localizedError('MATLAB:hwsdk:can:invalidCANIdentifierType');
                    end
                    identifier = p.Results.Identifier;
                    
                    addRequired(p, 'IsExtended', @islogical);
                    try
                        parse(p, varargin{1:2});
                    catch
                        obj.localizedError('MATLAB:hwsdk:can:invalidLogicalValue', 'isExtended');
                    end
                    isExtended = p.Results.IsExtended;
                    
                    if isExtended
                        if ~(identifier >= 0 && identifier <= obj.ExtendedMax)
                            obj.localizedError('MATLAB:hwsdk:can:invalidCANIdentifierValue', matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.ExtendedMax));
                        end
                    else
                        if ~(identifier >= 0 && identifier <= obj.StandardMax)
                            obj.localizedError('MATLAB:hwsdk:can:invalidCANIdentifierValue', matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.StandardMax));
                        end
                    end
                    % Non floating point, non negative, finite numeric vector
                    addRequired(p, 'DataArray', @(x) (isnumeric(x) && ~any(isnan(x)) && ~any(isinf(x)) && all(x >= 0) && all(floor(x) == x) && all(ceil(x) == x) && (isscalar(x) || isvector(x))));
                    try
                        parse(p, varargin{:});
                    catch
                        obj.localizedError('MATLAB:hwsdk:can:invalidCANDataType');
                    end
                    if numel(p.Results.DataArray) <= obj.CANMaxDataLength
                        dataArray = uint8(p.Results.DataArray);
                    else
                        obj.localizedError('MATLAB:hwsdk:can:invaidCANDataLength');
                    end
                end

                peripheralPayload = [typecast(uint32(identifier), 'uint8'), uint8(isExtended), size(dataArray, 2), dataArray];
                status = sendCommand(obj, obj.LibraryName, obj.WRITE, peripheralPayload);
                if 0 == status
                    % Write Failed because transmit buffers are full.
                    obj.localizedError('MATLAB:hwsdk:can:writeFailure');
                end
            catch e
                throwAsCaller(e);
            end
        end
    end
end
