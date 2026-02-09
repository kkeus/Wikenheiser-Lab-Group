classdef (Abstract)ServoMotorBase < matlabshared.addon.LibraryBase

    %   Copyright 2018-2022 The MathWorks, Inc.
    properties(SetAccess = immutable)
        MinPulseDuration
        MaxPulseDuration
    end
    
    properties(Access = private)
        ResourceMode            = 'Servo'
        ResourceOwner           = 'Servo'
        ReservePWMPins          = {}
        CountCutOff 
        MaxServos
        IsServoAttached
        DefaultMinPulseDuration = 544e-6
        DefaultMaxPulseDuration = 2400e-6
        ResourceAllocationSuccessFlag = true
    end
    
    properties(Access = private, Constant = true)
        ATTACH_SERVO    = hex2dec('F100')
        CLEAR_SERVO     = hex2dec('F101')
        READ_POSITION   = hex2dec('F102')
        WRITE_POSITION  = hex2dec('F103')
    end
    
    properties(GetAccess = public, SetAccess = protected)
        Pin
    end
    
    properties(Access = protected, Constant = true)
        LibraryName = 'Servo'
        DependentLibraries = {}
        LibraryHeaderFiles = 'Servo/Servo.h'
        CppHeaderFile = ''
        CppClassName = ''
    end
    
    methods(Access = private)
        function servoPin = validateServoSignalPin(obj, pin)
            servoPin = validateDigitalPin(obj.Parent, pin);
        end
    end
    
    methods
        function obj = ServoMotorBase(parentObj, pin, params)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
            catch e
                throwAsCaller(e);
            end
            obj.Parent = parentObj;
            pin = validateServoSignalPin(obj, pin);
                
            obj.Pin = char(pin);
            obj.IsServoAttached = false;
            
            switch obj.Parent.Board
                % Arduino Servo Library limtation by board type
                % http://arduino.cc/en/reference/servo
                case {'Mega2560', 'MegaADK'}
                    obj.ReservePWMPins = arduinoio.internal.ArduinoConstants.ServoReservedPinsMega;
                    obj.CountCutOff = arduinoio.internal.ArduinoConstants.ServoCountCutOffMega;
                    obj.MaxServos = arduinoio.internal.ArduinoConstants.MaxServosMega;
                case 'Due'
                    % No PWM pin conflict with usage of servo library on
                    % Due. It uses timer1-5 which do not consume any PWM 
                    % pins on Due (D2-D13), see below:
                    % https://github.com/ivanseidel/DueTimer/issues/11
                    %
                    % Though, the maximum number of servos permitted by the
                    % Servo library is 60 for Due board(12 for each of the 
                    % 5 timers), it is limited to the number of available
                    % digital pins here(2:53).
                    obj.MaxServos = arduinoio.internal.ArduinoConstants.MaxServosDue;
                    obj.CountCutOff = arduinoio.internal.ArduinoConstants.ServoCountCutOff;
                case {'MKR1000','MKR1010','MKRZero','Nano33IoT'}
                    % Only one timer is enabled for servo control. Each
                    % timer controls at most 12 servos
                    obj.MaxServos = arduinoio.internal.ArduinoConstants.MaxServos;
                    obj.CountCutOff = arduinoio.internal.ArduinoConstants.ServoCountCutOff;
                case {'Nano33BLE'}
                    % nRF52840 has 32 16 bits timers and each can enable 12
                    % Servo. For Nano 33 BLE MaxServos equal number of
                    % Digital Pins
                    obj.MaxServos = arduinoio.internal.ArduinoConstants.MaxServosNano33BLE;
                    obj.CountCutOff = arduinoio.internal.ArduinoConstants.ServoCountCutOff;
                case {'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
                    obj.MaxServos = arduinoio.internal.ArduinoConstants.MaxServosESP32;
                    obj.CountCutOff = arduinoio.internal.ArduinoConstants.ServoCountCutOffESP32;
                otherwise
                    obj.ReservePWMPins = arduinoio.internal.ArduinoConstants.ServoReservedPins;
                    obj.CountCutOff = arduinoio.internal.ArduinoConstants.ServoCountCutOff;
                    obj.MaxServos = arduinoio.internal.ArduinoConstants.MaxServos;
            end
            
            try
                p = inputParser;
                addParameter(p, 'MinPulseDuration', obj.DefaultMinPulseDuration);
                addParameter(p, 'MaxPulseDuration', obj.DefaultMaxPulseDuration);
                addParameter(p, 'ResourceMode', 'Servo');
                addParameter(p, 'ResourceOwner', 'Servo');
                parse(p, params{:});
            catch e
                parameters = {p.Parameters{1}, p.Parameters{2}};
                if strcmp(e.identifier, 'MATLAB:InputParser:ParamMustBeChar')
                    % Any NV Pair name not being a character reaches here
                    % Get the characters status of Input arguments
                    nvPairs = cellfun(@ischar, params);
                    % Get the NV Pair names index's character status
                    nvNames = nvPairs(1:2:end);
                    % Are there any characters?
                    numericNVNames = find(~nvNames);
                    % Invalid numeric NV Pair name provided in the input
                    nonCharNVName = params{numericNVNames*2 - 1};
                    if isnumeric(nonCharNVName)
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', num2str(nonCharNVName), 'Servo', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                    else
                        % Invalid Non numeric NV pair Name.
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
                                obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'Servo', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                            end
                            obj.localizedError('MATLAB:InputParser:ParamMissingValue', str);
                        case 'MATLAB:InputParser:UnmatchedParameter'
                            obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'Servo', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                        case 'MATLAB:InputParser:AmbiguousParameter'
                            obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'Servo', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                    end
                end
            end
            
            obj.MinPulseDuration = matlabshared.hwsdk.internal.validateDoubleParameterRanged('MinPulseDuration', ...
                                                             p.Results.MinPulseDuration, ...
                                                             0, 4e-3, 's');
                
            obj.MaxPulseDuration = matlabshared.hwsdk.internal.validateDoubleParameterRanged('MaxPulseDuration', ...
                                                             p.Results.MaxPulseDuration, ...
                                                             0, 4e-3, 's');
            
            if (any(ismember(p.UsingDefaults, 'MinPulseDuration')) && ~any(ismember(p.UsingDefaults, 'MaxPulseDuration'))) ||...
               (any(ismember(p.UsingDefaults, 'MaxPulseDuration')) && ~any(ismember(p.UsingDefaults, 'MinPulseDuration')))
                obj.localizedError('MATLAB:hwsdk:general:requiredBothMinMaxPulseDurations');
            end
            obj.ResourceMode = p.Results.ResourceMode;
            obj.ResourceOwner = p.Results.ResourceOwner;
            
            if obj.MinPulseDuration >= obj.MaxPulseDuration
                obj.localizedError('MATLAB:hwsdk:general:invalidMinMaxPulseDurations');
            else
                obj.allocateResource(obj.Pin);
                try
                    attachServo(obj, obj.MinPulseDuration*1e6, obj.MaxPulseDuration*1e6);
                catch e
                    throwAsCaller(e);
                end
            end
        end
    end
    
    methods (Access=protected)
        function delete(obj)
            orig_state = warning('off','MATLAB:class:DestructorError');
            try
                clearServo(obj);
            catch
            end
            
            try
                freeResource(obj);
            catch
            end
            warning(orig_state.state, 'MATLAB:class:DestructorError');
        end
    end
    
        %% Property set/get
     methods (Access = private)
        function writeStatus = attachServo(obj, min, max)
            min = typecast(uint16(min), 'uint8');
            max = typecast(uint16(max), 'uint8');
            try
                peripheralPayload = [getPinNumber(obj.Parent, obj.Pin), min, max];
                writeStatus = rawWrite(obj.Parent.Protocol, obj.ATTACH_SERVO, peripheralPayload);
            catch e
                throwAsCaller(e);
            end
            obj.IsServoAttached = true;
        end
        
        function writeStatus = clearServo(obj)
            if ~obj.IsServoAttached
                return;
            end
            
            try
                peripheralPayload = getPinNumber(obj.Parent, obj.Pin);
                writeStatus = rawWrite(obj.Parent.Protocol, obj.CLEAR_SERVO, peripheralPayload);
            catch e
                throwAsCaller(e);
            end
            obj.IsServoAttached = false;
        end
    end
    
    methods (Access = public)
        function angle = readPosition(obj)
            %   Read the position of servo motor shaft.
            %
            %   Syntax:
            %   value = readPosition(s)
            %
            %   Description:
            %   Measures the position of a standard servo motor shaft as a
            %   ratio of the motor's min/max range, from 0 to 1
            %
            %   Example:
            %       a = arduino();
            %       s = servo(a, 'D9');
            %       pos = readPosition(s);
			%
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       dev = addon(a, 'Adafruit/MotorShieldV2');
            %       s = servo(dev,'D9');
            %       pos = readPosition(s);
			%
            %   Input Arguments:
            %   s       - Servo motor device 
            %
			%   Output Arguments:
            %   value   - Measured motor shaft position (double) 
			%
			%   See also writePosition
            
            % Register on clean up for integrating all data
            if strcmpi(class(obj),'arduinoioaddons.adafruit.Servo')
                c = onCleanup(@() integrateData(obj.Parent,'AdafruitMotorShieldV2_servo'));
            else
                c = onCleanup(@() integrateData(obj.Parent,'Servo'));
            end

            try
                peripheralPayload = getPinNumber(obj.Parent, obj.Pin);
                responsePeripheralPayloadSize = 1;
                % read position in the range 0:180
                value = rawRead(obj.Parent.Protocol, obj.READ_POSITION, peripheralPayload, responsePeripheralPayloadSize);
                % workaround for g2366668 for position 0 until Arduino fixes Mbed driver issue
                if ismember(obj.Parent.Board,{'Nano33BLE'}) && (value > 200)
                    value = 0;
                end
                % convert to 0:1
                angle = double(round(value(1)*100/180)/100);
            catch e
                obj.Parent.throwCustomErrorHook(e);
            end
        end
        
        function writePosition(obj, value)
            %   Set the position of servo motor shaft.
            %
            %   Syntax:
            %   writePosition(s, value)
            %
            %   Description:
            %   Set the position of a standard servo motor shaft as a
            %   ratio of the motor's min/max range, from 0 to 1
            %
            %   Example:
            %       a = arduino();
            %       s = servo(a, 'D9');
            %       writePosition(s, 0.60);
			%
            %   Example:
            %       a = arduino();
            %       dev = addon(a, 'Adafruit/MotorShieldV2');
            %       s = servo(dev,'D9');
            %       writePosition(s, 0.60);
			%
            %   Input Arguments:
            %   s       - Servo motor device 
            %   value   - Motor shaft position (double)
			%
			%   See also readPosition
            
            % Register on clean up for integrating all data
            if strcmpi(class(obj),'arduinoioaddons.adafruit.Servo')
                c = onCleanup(@() integrateData(obj.Parent,'AdafruitMotorShieldV2_servo'));
            else
                c = onCleanup(@() integrateData(obj.Parent,'Servo'));
            end
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                matlabshared.hwsdk.internal.validateDoubleParameterRanged('position', value, 0, 1);
                peripheralPayload = [getPinNumber(obj.Parent, obj.Pin) uint8(180*value)];
                rawWrite(obj.Parent.Protocol, obj.WRITE_POSITION, peripheralPayload);
            catch e
                obj.Parent.throwCustomErrorHook(e);
            end
        end
    end
    
    %% Protected methods
    %
    %
    methods (Access = protected)       
        function disablePWMPins(obj, pins)
            for i = 1:numel(pins)
                terminal = getTerminalsFromPins(obj.Parent, pins{i});
                resourceOwner = getResourceOwner(obj.Parent, terminal);
                if ~strcmp(resourceOwner, 'Servo') 
                    mode = getTerminalMode(obj.Parent, terminal);
                    switch mode
                        case {'Unset', 'DigitalOutput', 'PWM', 'Servo'}
                            % Take resource ownership from Arduino object
                            if ~strcmp(mode, 'Unset')
                                configurePinInternal(obj.Parent, pins{i}, 'Unset', 'servo', '');
                            end
                            configurePinResource(obj.Parent, pins{i}, obj.ResourceOwner, 'Reserved', true);
                        otherwise
                            obj.ResourceAllocationSuccessFlag = false;
                            obj.localizedError('MATLAB:hwsdk:general:reservedServoPins', ...
                                obj.Parent.Board, strjoin(pins, ', '));
                    end
                end
            end
        end
        
        function enablePWMPins(obj, pins)
            for i = 1:numel(pins)
                terminal = getTerminalsFromPins(obj.Parent, pins{i});
                mode = getTerminalMode(obj.Parent, terminal);
                if strcmp(mode, 'Reserved')
                    configurePinInternal(obj.Parent, pins{i}, 'Unset', 'servo', obj.ResourceOwner);
                end
            end
        end
        
        function allocateResource(obj, pin)
            count = incrementResourceCount(obj.Parent, obj.ResourceOwner);
            
            % Possible dead code for now till all digital pins on Mega 2560
            % are supported for servo in the future
            if count > obj.MaxServos
                obj.localizedError('MATLAB:hwsdk:general:maxServos', ...
                    obj.Parent.Board, num2str(obj.MaxServos));
            end
            
            if ~strcmp(obj.Parent.Board, 'Due') % No need to reserve PWM pins for Due board
                if count == obj.CountCutOff + 1
                    obj.disablePWMPins(obj.ReservePWMPins)
                end
            end
            
            terminal = getTerminalsFromPins(obj.Parent, pin);
            mode = getTerminalMode(obj.Parent, terminal);
            resourceOwner = getResourceOwner(obj.Parent, terminal);
            if ismember(mode, {'Servo', 'PWM', 'DigitalOutput'}) ...
                    && strcmp(resourceOwner, '')
                % Take resource ownership from Arduino object
                if ~ismember(obj.Parent.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                    % For pin configuration needing IOServer APIs use
                    % configurePinInternal
                    configurePinInternal(obj.Parent, pin, 'Unset', 'servo', resourceOwner);
                end
                % For software reservation of pin, use configurePinResource
                configurePinResource(obj.Parent, pin, obj.ResourceOwner, obj.ResourceMode, true);
            elseif strcmp(mode, 'Unset') || ...
                   (strcmp(mode, 'Reserved') || matlabshared.hwsdk.internal.endsWith(mode, '\Reserved') && ...
                   (strcmp(resourceOwner, 'Servo') || matlabshared.hwsdk.internal.endsWith(resourceOwner, '\Servo')))
                % We can only acquire unset resources (or resources
                % reserved by servo)
                configurePinResource(obj.Parent, pin, obj.ResourceOwner, obj.ResourceMode, false);
            else
                obj.ResourceAllocationSuccessFlag = false;
                if strcmp(resourceOwner, 'Servo') && contains(mode, 'Servo')
                    obj.localizedError('MATLAB:hwsdk:general:reservedResourceServo', ...
                        char(pin));
                else
                    obj.localizedError('MATLAB:hwsdk:general:reservedPin', ...
                        char(pin), mode, 'Servo');
                end
            end
        end
        
        function freeResource(obj)
            count = decrementResourceCount(obj.Parent, obj.ResourceOwner);
            
            % Re-enable disabled pins if we are below the count cut-off
            if ~strcmp(obj.Parent.Board, 'Due') 
                if count == obj.CountCutOff
                    obj.enablePWMPins(obj.ReservePWMPins)
                end
            end
            
            terminal = getTerminalsFromPins(obj.Parent, obj.Pin);
            resourceOwner = getResourceOwner(obj.Parent, terminal);
            if ~strcmp(resourceOwner, obj.ResourceOwner)
                % If we're in the destructor because we failed to
                % construct (due to a resource conflict), we have no
                % pin configuration to repair...
                %
                return;
            end
            
            if obj.ResourceAllocationSuccessFlag
                % Free the servo pin.
                if count <= obj.CountCutOff || (count > obj.CountCutOff && ~ismember(obj.Pin, obj.ReservePWMPins))
                    if ismember(obj.Parent.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                         configurePinResource(obj.Parent, obj.Pin, '', 'Servo', false);
                    else
                        configurePinInternal(obj.Parent, obj.Pin, 'Unset', 'servo', obj.ResourceOwner);
                    end
                else
                    configurePinResource(obj.Parent, obj.Pin, obj.ResourceOwner, 'Reserved', true);
                end
            end
        end
    end
end
