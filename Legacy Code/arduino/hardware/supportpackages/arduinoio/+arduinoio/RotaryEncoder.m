classdef RotaryEncoder < matlabshared.addon.LibraryBase & matlab.mixin.CustomDisplay
%ROTARYENCODER Create a quadrature rotary encoder object.
%
% encoder = rotaryEncoder(a, channelA, channelB, ...) creates a quadrature rotary encoder object.

% Copyright 2018-2023 The MathWorks, Inc.

    properties(Access = private, Constant = true)
        ATTACH_ENCODER           = hex2dec('F120')
        DETACH_ENCODER           = hex2dec('F121')
        CHANGE_DELAY             = hex2dec('F122')
        READ_ENCODER_COUNT       = hex2dec('F123')
        READ_ENCODER_SPEED       = hex2dec('F124')
        WRITE_ENCODER_COUNT      = hex2dec('F125')
    end

    properties(Access = protected, Constant = true)
        LibraryName = 'RotaryEncoder'
        DependentLibraries = ''
        LibraryHeaderFiles = ''
        CppHeaderFile = ''
        CppClassName = ''
    end

    properties(SetAccess = immutable)
        ChannelA
        ChannelB
        PulsesPerRevolution
    end

    properties(Constant, Access = private)
        DecodingType = 'X4'
        % Set measurement interval to be 20ms such that the slowest
        % quadrature signal it can detect at least generates an edge per
        % 20ms on either channel A or B, e.g frequency of 1/0.02=50Hz.
        % Since it is X4 decoding, the slowest frequency of signal on A or
        % B is 50/4=12.5Hz.
        SpeedMeasureInterval = 0.02
        ResourceOwner = 'RotaryEncoder'
        ResourceMode = 'Interrupt'
    end

    properties(Access = private)
        IsAttached = false
        ID
        OutputFormat
    end

    methods(Hidden, Access = public)
        function obj = RotaryEncoder(parentObj, chA, chB, ppr)
            narginchk(3, 4);
            obj.Parent = parentObj;

            % Validate A and B channels
            try
                validatePin(obj.Parent, chA, 'Interrupt');
                validatePin(obj.Parent, chB, 'Interrupt');
            catch e
                throwAsCaller(e);
            end
            % Error on Duplicate Channels
            if strcmpi(chA, chB)
                obj.localizedError('MATLAB:arduinoio:general:invalidEncoderChannelPinDuplicate');
            end

            % Validate A and B are not already used by an existing encoder
            pins = {chA, chB};
            for index = 1:2
                [~, ~, ~, resourceOwner] = getPinInfoHook(obj.Parent, pins{index});
                if strcmp(resourceOwner, obj.ResourceOwner)
                    obj.localizedError('MATLAB:arduinoio:general:reuseEncoderChannelPin', pins{index});
                end
            end

            % validate pulse per revolution value
            if nargin > 3
                try
                    validateattributes(ppr, {'double'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'positive'});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidEncoderPPRValue')
                end
                obj.PulsesPerRevolution = ppr;
            end

            % Get the next free encoder. ID corresponds to an index in the
            % server side. So ID starts with 1 in host, with 0 on the
            % server side.
            obj.ID = getFreeResourceSlot(obj.Parent, obj.ResourceOwner);
            if ismember(obj.Parent.Board, {'Mega2560','MegaADK','Due'})
                maxEncoders = 2;
            else
                maxEncoders = 1;
            end
            if obj.ID > maxEncoders
                obj.localizedError('MATLAB:arduinoio:general:maxEncoders', obj.Parent.Board, num2str(maxEncoders));
            end

            % Configure pin resources
            iUndo = 0;
            try
                configurePinWithUndo(chA, obj.ResourceOwner, obj.ResourceMode);
            catch
                obj.localizedError('MATLAB:hwsdk:general:reservedPin', char(chA), configurePin(obj.Parent, chA), obj.ResourceMode);
            end
            try
                configurePinWithUndo(chB, obj.ResourceOwner, obj.ResourceMode);
            catch
                obj.localizedError('MATLAB:hwsdk:general:reservedPin', char(chB), configurePin(obj.Parent, chB), obj.ResourceMode);
            end
            obj.ChannelA = char(chA);
            obj.ChannelB = char(chB);

            % Nested function that configure pin and also allow reverting
            % them back in case configuration fails
            function configurePinWithUndo(pin, resourceOwner, pinMode)
                [~, ~, prevMode, prevResourceOwner] = getPinInfoHook(obj.Parent, pin);
                iUndo = iUndo + 1;
                obj.Undo(iUndo).Pin = pin;
                obj.Undo(iUndo).ResourceOwner = prevResourceOwner;
                obj.Undo(iUndo).PrevPinMode = prevMode;

                if strcmp(prevMode, 'Interrupt') && strcmp(prevResourceOwner, '')
                    % Take resource ownership from Arduino object
                    % configurePinInternal is needed for Unset as it
                    % involves IOServer calls.
                    configurePinInternal(obj.Parent, pin, 'Unset', 'rotaryEncoder', prevResourceOwner);
                    configurePinResource(obj.Parent, pin, resourceOwner, pinMode, true);
                elseif strcmp(prevMode, 'Unset')
                    % We can only acquire unset resources
                    configurePinResource(obj.Parent, pin, resourceOwner, pinMode, false);
                else
                    obj.localizedError('MATLAB:hwsdk:general:reservedPin', pin, prevMode, pinMode);
                end
            end

            % Attach encoders to interrupt pins
            attachEncoder(obj);
            obj.IsAttached = true;
        end
    end

    methods(Access = protected)
        function delete(obj)
            try
                parentObj = obj.Parent;
                if ~isempty(obj.ID)
                    clearResourceSlot(parentObj, obj.ResourceOwner, obj.ID);
                end
                if obj.IsAttached
                    detachEncoder(obj);
                end
                if isempty(obj.Undo)
                    % do nothing since constructor fails before configuring
                    % the pins
                else
                    % Construction failed, revert pins back to their
                    % original states
                    for idx = 1:numel(obj.Undo)
                        % obj.ResourceOwner might be holding the pin.
                        % Configuring to 'Unset' with obj.ResourceOwner
                        % will make Arduino the owner of the pin.
                        configurePinInternal(parentObj, obj.Undo(idx).Pin, 'Unset', 'rotaryEncoder', obj.ResourceOwner);
                        % After Arduino becomes the owner, configure it to
                        % the previous state with the previous resource.
                        configurePinResource(parentObj, obj.Undo(idx).Pin, obj.Undo(idx).ResourceOwner, obj.Undo(idx).PrevPinMode, true);
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
        end
    end

    methods(Access = private)
        function attachEncoder(obj)
            peripheralPayload = [obj.ID-1, getPinNumber(obj.Parent, obj.ChannelA), getPinNumber(obj.Parent, obj.ChannelB)];
            rawWrite(obj.Parent.Protocol, obj.ATTACH_ENCODER, peripheralPayload);
        end

        function detachEncoder(obj)
            peripheralPayload = [obj.ID-1, getPinNumber(obj.Parent, obj.ChannelA), getPinNumber(obj.Parent, obj.ChannelB)];
            rawWrite(obj.Parent.Protocol, obj.DETACH_ENCODER, peripheralPayload);
        end
    end

    methods(Access = public)
        function [count, time] = readCount(obj, varargin)
        %   Read current count from the encoder with X4 decoding.
        %
        %   Syntax:
        %   [count,time] = readCount(encoder)
        %   [count,time] = readCount(encoder,Name,Value)
        %
        %   Description:
        %   Read current count from the quadrature rotary encoder.
        %
        %   Example:
        %       a = arduino();
        %       encoder = rotaryEncoder(a,'D2','D3');
        %       [count,time] = readCount(encoder);
        %
        %   Example:
        %       a = arduino();
        %       encoder = rotaryEncoder(a,'D2','D3');
        %       [count,time] = readCount(encoder,'reset',true);
        %
        %   Input Arguments:
        %   obj   - Quadrature rotary encoder object
        %
        %   Name-Value Pair Input Arguments:
        %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value.
        %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
        %
        %   NV Pair:
        %   'reset' - Flag indicating whether to reset count to 0 after reading it from encoder (boolean)
        %   'OutputFormat' - Type of time output (duration)
        %
        %   Output Argument:
        %   count  - Current encoder count
        %   time   - Time elapsed in seconds since Arduino server starts running (double / duration if OutputFormat is specified)
        %
        %   See also readSpeed, resetCount

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent,'RotaryEncoder'));

            try
                narginchk(1, 5);
                try
                    p = inputParser;
                    addParameter(p, 'reset', false, @islogical);
                    addParameter(p, 'OutputFormat', '', @(x) ((ischar(x) || isstring(x)) && strcmpi(x, 'duration')));
                    parse(p, varargin{:});
                catch e
                    st = dbstack;
                    % First index gives immediate method's name.
                    methodName = extractAfter(st(1).name, '.');
                    switch e.identifier
                      case 'MATLAB:InputParser:ArgumentFailedValidation'
                        message = e.message;
                        index = strfind(message, '''');
                        str = message(index(1)+1:index(2)-1);
                        if contains(str, p.Parameters(1))
                            obj.localizedError('MATLAB:arduinoio:general:invalidCountOutputFormatValue');
                        else
                            obj.localizedError('MATLAB:arduinoio:general:invalidCountResetValue');
                        end
                      case 'MATLAB:InputParser:ParamMissingValue'
                        message = e.message;
                        index = strfind(message, '''');
                        str = message(index(1)+1:index(2)-1);
                        try
                            validatestring(str, p.Parameters);
                        catch
                            obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName', methodName, matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                        end
                        throwAsCaller(e);
                      otherwise
                        obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName', methodName, matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                    end
                end
                obj.OutputFormat = p.Results.OutputFormat;
                resetFlag = p.Results.reset;
                peripheralPayload = [obj.ID-1, resetFlag];
                % 32 bit values of count and time with 1 byte overflow
                responsePeripheralPayloadSize = 9;
                output = rawRead(obj.Parent.Protocol, obj.READ_ENCODER_COUNT, peripheralPayload, responsePeripheralPayloadSize);

                % convert to int32 count
                count = typecast(uint8(output(1:4)), 'int32');
                % convert to int8 overflow
                overflow = double(typecast(uint8(output(9)), 'int8'));
                if overflow == 0
                    count = double(count);
                elseif overflow > 0
                    obj.localizedWarning('MATLAB:arduinoio:general:encoderCountOverflow');
                    count = overflow*(int64(intmax)+1)+int64(count);
                else % overflow < 0
                    obj.localizedWarning('MATLAB:arduinoio:general:encoderCountOverflow');
                    count = int64(count)-overflow*(int64(intmin)-1);
                end
                % convert to uint32 time
                time = typecast(uint8(output(5:8)), 'uint32');
                time = double(time)/1000;% unsigned long time convert to double and convert to second
                                         % Convert double to duration
                if ~isempty(obj.OutputFormat)
                    time = seconds(time);
                end
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function rpm = readSpeed(obj)
        %   Read current rotational speed measured by the encoder(s).
        %
        %   Syntax:
        %   rpm = readSpeed(encoder)
        %
        %   Description:
        %   Read current rotational speed measured by the quadrature rotary encoder(s).
        %
        %   Example:
        %       a = arduino();
        %       encoder = rotaryEncoder(a,'D2','D3');
        %       rpm = readSpeed(encoder);
        %
        %   Example:
        %       a = arduino();
        %       encoder1 = rotaryEncoder(a,'D2','D3');
        %       encoder2 = rotaryEncoder(a,'D18','D19');
        %       rpm = readSpeed([encoder1,encoder2]);
        %
        %   Input Arguments:
        %   obj   - Single or vector of quadrature rotary encoder object(s)
        %
        %   Output Argument:
        %   rpm   - Rotational speed in revolution per minute (double or vector of double)
        %
        %   See also readCount, resetCount

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj(1).Parent,'RotaryEncoder'));

            try
                numEncoders = numel(obj);
                data = zeros(1, numEncoders+1);
                data(1) = numEncoders; % start with number of encoder objects to read
                for index = 1:numEncoders
                    if isempty(obj(index).PulsesPerRevolution)
                        obj.localizedError('MATLAB:arduinoio:general:encoderPPRNotSpecified');
                    end
                    % Check if the connection type is BLE
                    if isequal(obj(index).Parent.ConnectionType,matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE)
                        if ~strcmp(obj(index).Parent.Address, obj(1).Parent.Address)
                            obj.localizedError('MATLAB:arduinoio:general:encoderNotSameParent');
                        end
                    % Check if the connection type is WiFi or Bluetooth    
                    elseif isequal(obj(index).Parent.ConnectionType,matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi) || ...
                            isequal(obj(index).Parent.ConnectionType,matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth)
                        if ~strcmp(obj(index).Parent.DeviceAddress, obj(1).Parent.DeviceAddress)
                            obj.localizedError('MATLAB:arduinoio:general:encoderNotSameParent');
                        end
                    else
                        if ~strcmp(obj(index).Parent.Port, obj(1).Parent.Port)
                            obj.localizedError('MATLAB:arduinoio:general:encoderNotSameParent');
                        end
                    end
                    data(index+1) = obj(index).ID-1;
                end

                peripheralPayload = data;
                % [1 byte of overflow info; 2 bytes of count (speed) info]
                % for each encoder will be returned from server..
                responsePeripheralPayloadSize = 3*numEncoders;
                output = rawRead(obj(index).Parent.Protocol, obj(index).READ_ENCODER_SPEED, peripheralPayload, responsePeripheralPayloadSize);

                rpm = zeros(1, numEncoders);
                for index = 1:numEncoders
                    value = typecast(uint8(output(3*(index-1)+1)), 'int8');
                    overflowDiff = double(value);
                    value = typecast(uint8(output(3*(index-1)+(2:3))), 'int16');
                    countDiff = double(value);
                    if overflowDiff == 0
                        count = countDiff;
                    elseif overflowDiff < 0
                        count = int64(countDiff)-overflowDiff*(int64(intmin)-1);
                    else % overflowDiff > 0
                        count = overflowDiff*(int64(intmax)+1)+int64(countDiff);
                    end
                    value = double(count)/obj(index).SpeedMeasureInterval/(obj(index).PulsesPerRevolution*4)*60;
                    rpm(index) = value;
                end
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function resetCount(obj, count)
        %   Reset count value on the encoder.
        %
        %   Syntax:
        %   resetCount(encoder)
        %   resetCount(encoder,count)
        %
        %   Description:
        %   Reset count value on the quadrature rotary encoder.
        %
        %   Example:
        %       a = arduino();
        %       encoder = rotaryEncoder(a,'D2','D3');
        %       resetCount(encoder);
        %       resetCount(encoder,10);
        %
        %   Input Arguments:
        %   obj   - Quadrature rotary encoder object
        %   count - Value to reset encoder count to.(optional, double, default 0)
        %
        %   See also readCount, readSpeed

            try
                % This is needed for data integration
                dCount = "true";

                if nargin < 2
                    count = 0;
                    % This is needed for data integration
                    dCount = "false";
                end

                % Register on clean up for integrating all data
                c = onCleanup(@() integrateData(obj.Parent,'RotaryEncoder',dCount));

                try
                    validateattributes(count, {'double', 'int32'}, {'scalar', 'real', 'integer', 'finite', 'nonnan', '<=', intmax, '>=', intmin});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidEncoderCount', num2str(intmin), num2str(intmax));
                end

                data = typecast(int32(count), 'uint8');

                peripheralPayload = [obj.ID-1, data];
                rawWrite(obj.Parent.Protocol, obj.WRITE_ENCODER_COUNT, peripheralPayload);
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end
    end

    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);

            % Display main options
            fprintf('           ChannelA: ''%s''\n', obj.ChannelA);
            fprintf('           ChannelB: ''%s''\n', obj.ChannelB);
            if isempty(obj.PulsesPerRevolution)
                fprintf('PulsesPerRevolution:  []\n');
            else
                fprintf('PulsesPerRevolution: %d\n', obj.PulsesPerRevolution);
            end
            fprintf('\n');

            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end
