classdef Ultrasonic < matlabshared.addon.LibraryBase & matlab.mixin.CustomDisplay
%ULTRASONIC Create a Ultrasonic Sensor object
%   u = ultrasonic(a, 'D2', 'D3') creates an object to access a 4-Pin
%   ultrasonic sensor
%   u = ultrasonic(a, 'D2') creates an object to access a 3-Pin
%   ultrasonic sensor

%   Copyright 2018-2023 The MathWorks, Inc.

    properties(SetAccess = immutable)
        TriggerPin
        EchoPin
    end

    properties (Access = private)
        ResourceOwner  = 'Ultrasonic'
        ResourceMode  = 'Ultrasonic'
        Resource = 'ultrasonicTerminals'
        DuplicateDevice
        TriggerTerminal
        EchoTerminal
        OutputFormat
        Timeout
    end

    properties(Access = private, Constant = true)
        ULTRASONIC_ADD      = hex2dec('F130')
        ULTRASONIC_REMOVE   = hex2dec('F131')
        ULTRASONIC_READ     = hex2dec('F132')
        DefaultTimeout = 0.03
    end

    properties(Access = protected, Constant = true)
        LibraryName = 'Ultrasonic'
        DependentLibraries = {}
        LibraryHeaderFiles = ''
        CppHeaderFile = ''
        CppClassName = ''
    end

    methods(Hidden, Access = public)
        function obj = Ultrasonic(parentObj, triggerPin, varargin)
            narginchk(2,7);
            obj.Parent = parentObj;

            % Fetch pins
            try
                p = inputParser;
                p.PartialMatching = true;
                p.addRequired('TriggerPin', @(x) ischar(x) || isstring(x));
                p.addOptional('EchoPin', '', @(x) ischar(x) || isstring(x));
                if nargin > 2
                    parse(p, triggerPin, varargin{1});
                elseif nargin <= 2
                    parse(p, triggerPin);
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:InputParser:ArgumentFailedValidation')
                    validPins = obj.Parent.getAvailableDigitalPins();
                    obj.Parent.localizedError('MATLAB:hwsdk:general:invalidPinTypeString', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(validPins)));
                else
                    throwAsCaller(e);
                end
            end

            % Validate pins
            obj.TriggerPin = char(validateDigitalPin(obj.Parent, p.Results.TriggerPin));
            if isempty(char(p.Results.EchoPin))
                % echopin argument not provided
                obj.EchoPin = char(obj.TriggerPin);
            else
                obj.EchoPin = char(validateDigitalPin(obj.Parent, p.Results.EchoPin));
            end

            % Output format and Hidden Timeout Parameters
            try
                p = inputParser;
                p.addParameter('OutputFormat', '', @(x) ((ischar(x) || isstring(x)) && strcmpi(x, 'double')));
                p.addParameter('Timeout', obj.DefaultTimeout,  @(x) isnumeric(x) && ~isnan(x) && ~isinf(x) && x>=0 && x<=1);
                parse(p, varargin{2:end});
            catch e
                if numel(varargin) > 3
                    obj.localizedError('MATLAB:maxrhs');
                end
                switch(e.identifier)
                  case 'MATLAB:InputParser:ParamMustBeChar'
                    % Invalid NV pair parameter name reaches here
                    % u = ultrasonic(a, 'D2', "D3", 1)

                    throwAsCaller(e);

                  case 'MATLAB:InputParser:ParamMissingValue'
                    % Providing no value to NV pair reaches here
                    % u = ultrasonic(a, 'D2', "D3", 'OutputFormat')
                    % u = ultrasonic(a, 'D2', "D3", 'Timeout')

                    message = e.message;
                    % Extract the NV pair parameter name from the
                    % error message
                    index = strfind(message, '''');
                    str = message(index(1)+1:index(2)-1);
                    % Check only against 'OutputFormat'. Because
                    % 'Timeout' is hidden
                    if contains(str, p.Parameters(1))
                        % No value given for 'OutputFormat'
                        throwAsCaller(e);
                    else
                        % No value given for 'Timeout'. However we
                        % don't recognize Timeout parameter when
                        % there is a fault as it is HIDDEN.
                        obj.localizedError('MATLAB:hwsdk:general:invalidParameterName', str, p.Parameters{1});
                    end

                  case {'MATLAB:InputParser:invalidParameterName', 'MATLAB:InputParser:UnmatchedParameter'}
                    % Invalid NV pair parameter name reaches here
                    % u = ultrasonic(a, 'D2', "D3", 'x', 1)

                    message = e.message;
                    % Extract the NV pair parameter name from the
                    % error message
                    index = strfind(message, '''');
                    str = message(index(1)+1:index(2)-1);
                    obj.localizedError('MATLAB:hwsdk:general:invalidParameterName', str, p.Parameters{1});

                  case 'MATLAB:InputParser:ArgumentFailedValidation'
                    message = e.message;
                    index = strfind(message, '''');
                    str = message(index(1)+1:index(2)-1);
                    if contains(str, p.Parameters(1))
                        % Invalid value provided for OutputFormat
                        obj.localizedError('MATLAB:arduinoio:general:invalidOutputFormat');
                    else
                        % Invalid value provided for Timeout.
                        % However we don't recognize Timeout if
                        % there is a fault because it is HIDDEN.
                        for index = 1:numel(varargin)
                            if ischar(varargin{index}) || isstring(varargin{index})
                                if startsWith(varargin{index}, 'T')
                                    % Extract the actual input from
                                    % varargin
                                    str = varargin{index};
                                end
                            end
                        end
                        obj.localizedError('MATLAB:hwsdk:general:invalidParameterName', str, p.Parameters{1});
                    end
                  otherwise
                    % No Design case here. Just throw.
                    throwAsCaller(e);
                end
            end
            obj.OutputFormat = p.Results.OutputFormat;
            obj.Timeout = p.Results.Timeout;

            % Manage Resources
            [~, obj.TriggerTerminal, ~, ~] = getPinInfoHook(obj.Parent, obj.TriggerPin);
            [~, obj.EchoTerminal, ~, ~] = getPinInfoHook(obj.Parent, obj.EchoPin);
            try
                ultrasonicTerminals = getSharedResourceProperty(obj.Parent, obj.ResourceOwner, obj.Resource);
                usedUltrasonicPins = intersect([obj.TriggerTerminal, obj.EchoTerminal], ultrasonicTerminals);
            catch
                ultrasonicTerminals = [];
                usedUltrasonicPins = [];
            end
            if isempty(usedUltrasonicPins)
                ultrasonicTerminals = [ultrasonicTerminals, obj.TriggerTerminal];
                if ~strcmpi(obj.TriggerPin, obj.EchoPin)
                    ultrasonicTerminals = [ultrasonicTerminals, obj.EchoTerminal];
                end
                setSharedResourceProperty(obj.Parent, obj.ResourceOwner, obj.Resource, ultrasonicTerminals);
            else
                obj.DuplicateDevice = 1;
                obj.localizedError('MATLAB:arduinoio:general:reservedResourceUltrasonic', strjoin(obj.Parent.getPinsFromTerminals(usedUltrasonicPins), ', '));
            end

            % Configure pins to Ultrasonic and remember
            iUndo = 0;
            ultrasonicPins = string(obj.TriggerPin);
            if ~strcmpi(obj.TriggerPin, obj.EchoPin)
                ultrasonicPins = [ultrasonicPins, string(obj.EchoPin)];
            end
            try
                for ii = 1:numel(ultrasonicPins)
                    [pin, ~, mode, resourceOwner] = getPinInfoHook(obj.Parent, ultrasonicPins{ii});
                    if strcmp(mode, 'Ultrasonic') && strcmp(resourceOwner, '')
                        % Take resource ownership from Arduino object
                        configurePinInternal(obj.Parent, pin, 'Unset', 'ultrasonic', '');
                    end
                    pinStatus = configurePinInternal(obj.Parent, pin, obj.ResourceMode, 'ultrasonic', obj.ResourceOwner);
                    iUndo = iUndo + 1;
                    obj.Undo(iUndo) = pinStatus;
                end
            catch e
                if strcmpi(e.identifier,'MATLAB:hwsdk:general:invalidResourceownerName') || strcmpi(e.identifier,'MATLAB:hwsdk:general:invalidPin')
                    % throw correct error for MKRZero pin D32. Details in g2052722
                    % Also, invalidPin error is thrown when an ultrasonic object is
                    % created with analogOnly pins on atmega328p boards (Nano3, ProMini328_3V, and ProMini328_5V)
                    throwAsCaller(e);
                else
                    config = configurePin(obj.Parent, ultrasonicPins{ii});
                    obj.localizedError('MATLAB:arduinoio:general:reservedUltrasonicPins', ...
                                       obj.Parent.Board, ultrasonicPins{ii}, config);
                end
            end

            peripheralPayload = [obj.TriggerTerminal, obj.EchoTerminal];
            rawWrite(obj.Parent.Protocol, obj.ULTRASONIC_ADD, peripheralPayload);
        end
    end

    methods (Access=protected)
        function delete(obj)
            try
                % Resource management on object deletion from command line
                if isempty(obj.DuplicateDevice)
                    ultrasonicTerminals = getSharedResourceProperty(obj.Parent, obj.ResourceOwner, obj.Resource);
                    ultrasonicTerminals(ultrasonicTerminals == obj.TriggerTerminal) = [];
                    if ~strcmpi(obj.TriggerPin, obj.EchoPin)
                        ultrasonicTerminals(ultrasonicTerminals == obj.EchoTerminal) = [];
                    end
                    setSharedResourceProperty(obj.Parent, obj.ResourceOwner, obj.Resource, ultrasonicTerminals);
                end

                % Unconfigure Pins only when it was configured. Accidental
                % object deletion will not execute this snippet
                if ~isempty(obj.Undo)
                    % Just to make sure the object has been created
                    % successfully, placing the hardware transaction here
                    peripheralPayload = [obj.TriggerTerminal, obj.EchoTerminal];
                    rawWrite(obj.Parent.Protocol, obj.ULTRASONIC_REMOVE, peripheralPayload);

                    for idx = 1:numel(obj.Undo)
                        prevMode = configurePinResource(obj.Parent, obj.Undo(idx).Pin);
                        if strcmpi(prevMode, 'Ultrasonic')
                            % configurePinInternal needed for Unset as it
                            % involves IOServer calls.
                            configurePinInternal(obj.Parent, obj.Undo(idx).Pin, 'Unset', 'ultrasonic', obj.ResourceOwner);
                        end
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
        end
    end

    methods(Access = public)
        function [distance, timestamp] = readDistance(obj)
        %   Get the sensed distance to the nearest object
        %
        %   Syntax:
        %   readDistance(obj)
        %
        %   Description:
        %   Get the sensed distance to the nearest object, assuming speed of sound is 340m/s
        %
        %   Example:
        %       a = arduino('COM3','Uno','libraries','Ultrasonic');
        %       obj = ultrasonic(a,'D12','D13');
        %       [distance, timestamp] = readDistance(obj);
        %
        %   Input Arguments:
        %   obj - Ultrasonic device connection
        %
        %   Output Arguments:
        %   distance - Sensed distance (m)
        %   timestamp - Timestamp of distance measurement in the format
        %   <DD-MMM-YYYY HH:MM:SS>
        %
        %   See also readEchoTime, ultrasonic

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'Ultrasonic'));

            try
                % Timeout obtained as seconds, passed as microseconds.
                peripheralPayload = [obj.TriggerTerminal, obj.EchoTerminal, typecast(uint32(obj.Timeout*1e6), 'uint8')];
                % uint32 value representing echoTime
                responsePeripheralPayloadSize = 4;
                output = rawRead(obj.Parent.Protocol, obj.ULTRASONIC_READ, peripheralPayload, responsePeripheralPayloadSize);
                % Converting time to distance
                % 1s -> 344m => 10^-6s -> 10^-6*344m => 1us -> 1 / 29.06 cm
                % Calculate for one way travel => /2
                distance = cast(typecast(uint8(output(1:4)), 'uint32'), 'double') / 29 / 2 / 100;
                % Out of range objects
                if 0 == distance
                    distance = Inf;
                end
                timestamp = datetime('now','TimeZone','local');
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end

        function [echoTime, timestamp] = readEchoTime(obj)
        %   Get the time for echo pin to receive echoed back signal
        %
        %   Syntax:
        %   readEchoTime(obj)
        %
        %   Description:
        %   Get the time for echo pin to receive echoed back signal after a signal is sent from send pin
        %
        %   Example:
        %       a = arduino('COM3','Uno','libraries','Ultrasonic');
        %       obj = ultrasonic(a,'D12','D13');
        %       [echoTime, timestamp] = readEchoTime(obj)
        %
        %   Input Arguments:
        %   obj - ultrasonic device
        %
        %   Output Arguments:
        %   echoTime - Duration when echo pin is high (seconds)
        %   timestamp - Timestamp of distance measurement in the format
        %   <DD-MMM-YYYY HH:MM:SS>
        %
        %   See also readDistance, ultrasonic

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'Ultrasonic'));
            try
                peripheralPayload = [obj.TriggerTerminal, obj.EchoTerminal, typecast(uint32(obj.Timeout*1e6), 'uint8')];
                % uint32 value representing echoTime
                responsePeripheralPayloadSize = 4;
                output = rawRead(obj.Parent.Protocol, obj.ULTRASONIC_READ, peripheralPayload, responsePeripheralPayloadSize);
                % microseconds to seconds
                echoTime = cast(typecast(uint8(output(1:4)), 'uint32'), 'double') * 1e-6;
                % Is object out of range?
                if 0 == echoTime
                    echoTime = Inf;
                end
                % Convert double to duration
                if isempty(obj.OutputFormat)
                    echoTime = seconds(echoTime);
                end
                timestamp = datetime('now','TimeZone','local');
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end
    end

    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);

            % Display main options
            fprintf('    TriggerPin: ''%s''\n', obj.TriggerPin);
            fprintf('       EchoPin: ''%s''\n', obj.EchoPin);
            fprintf('\n');

            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end

% LocalWords:  hwsdk
