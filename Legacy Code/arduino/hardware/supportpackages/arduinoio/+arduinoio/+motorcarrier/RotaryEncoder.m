classdef RotaryEncoder < matlabshared.hwsdk.internal.base & matlab.mixin.CustomDisplay
%RotaryEncoder Create a rotary encoder object
%
%   This file is for internal use only and is subject to change without
%   notice.

%   Copyright 2020-2023 The MathWorks, Inc.

    properties(Hidden,WeakHandle)
        Parent matlabshared.hwsdk.internal.base
    end
    properties(Access = private, Constant = true)
        CREATE_ENCODER        = 0x0A
        RESET_ENCODER_COUNT   = 0x0B
        READ_ENCODER_COUNT    = 0x0C
        READ_ENCODER_SPEED    = 0x0D
        DELETE_ENCODER        = 0x0E
    end

    properties(Access = private)
        ResourceOwner = 'MotorCarrier\Encoder';
        MotorCarrierObj
        IRQPin = 'D6'
        Undo = struct('Pin', {}, 'ResourceOwner', {}, 'PrevPinMode', {});
    end
    properties(SetAccess = immutable)
        Channel
        PulsesPerRevolution = 3
        Encoding  = 'X4'
    end

    properties(Access = private, Constant = true)
        MaxEncoders = 2
    end

    methods(Hidden, Access = public)
        function obj = RotaryEncoder(parentObj,channel,varargin)
            narginchk(2,3);
            obj.Parent = parentObj;
            if strcmpi(class(parentObj),'arduinoio.motorcarrier.PIDMotor')
                obj.MotorCarrierObj = parentObj.Parent;
            else
                obj.MotorCarrierObj = parentObj;
            end
            incrementResourceCount(obj.MotorCarrierObj.Parent,obj.ResourceOwner);
            channel = matlabshared.hwsdk.internal.validateIntParameterRanged( ...
                'Encoder ''Channel''', ...
                channel, ...
                1, ...
                obj. MaxEncoders);
            try
                encoders = getSharedResourceProperty(obj.MotorCarrierObj.Parent, obj.ResourceOwner, 'encoders');
            catch
                locEn = 1; %#ok<NASGU>
                encoders = [obj.MotorCarrierObj.I2CAddress zeros(1, obj.MaxEncoders)];
            end
            carrierEnAddresses = encoders(:, 1);
            [~, locEn] = ismember(obj.MotorCarrierObj.I2CAddress, carrierEnAddresses);
            if locEn == 0
                encoders = [encoders; obj.MotorCarrierObj.I2CAddress zeros(1, obj.MaxEncoders)];
                locEn = size(encoders, 1);
            end

            % Check for resource conflict with Encoders
            if encoders(locEn, channel+1)
                obj.localizedError('MATLAB:arduinoio:general:conflictResourceMC', 'RotaryEncoder', num2str(channel));
            end

            encoders(locEn, channel+1) = 1;
            setSharedResourceProperty(obj.MotorCarrierObj.Parent, obj.ResourceOwner, 'encoders', encoders);
            obj.Channel = channel;
            if(nargin>2)
                obj.PulsesPerRevolution = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                    'MotorCarrier\RotaryEncoder ''PulsesPerRevolution''', ...
                    varargin{1}, ...
                    intmin('int32')/4, ...
                    intmax('int32')/4);
            end
            configureRotaryEncoderPins(obj);
            createEncoder(obj);
        end
    end
    %%
    methods
        function resetCount(obj,count)
        % Reset count of encoder register
        %
        %   Syntax:
        %   resetCount(ENCODEROBJ) resets count of encoder register
        %
        %   resetCount(ENCODEROBJ,COUNT) resets count of encoder
        %   register to COUNT
        %
        %   %   Example:
        %      % Construct an arduino object
        %      a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
        %
        %      % Construct MotorCarrier object
        %      mCObj = motorCarrier(a);
        %
        %      % Construct rotary encoder object
        %      en1 = rotaryEncoder(mCObj,1);
        %
        %      % Reset count of encoder register
        %      resetCount(en1);
        %
        %      % Reset count of encoder register to 256
        %      resetCount(en1,256);
        %
        %  See also readSpeed, readCount
            try
                % This is needed for integrating count parameter
                dCount = "true";

                if nargin < 2
                    count = 0;
                    % This is needed for data integration
                    dCount = "false";
                end

                % Register on clean up for integrating all data
                c = onCleanup(@() integrateData(obj.Parent.Parent,'MotorCarrier_rotaryEncoder',dCount));

                narginchk(1,2);
                commandID = obj.RESET_ENCODER_COUNT;
                if nargin < 2
                    count = 0;
                end
                try
                    validateattributes(count, {'double', 'int32'}, {'scalar', 'real', 'integer', 'finite', 'nonnan', '<=', intmax, '>=', intmin});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidEncoderCount', num2str(intmin), num2str(intmax));
                end
                data = typecast(int32(count), 'uint8');
                params = [obj.Channel-1, data];
                sendCommand(obj,commandID, params);
            catch e
                integrateErrorKey(obj.Parent.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function [count,timestamp] = readCount(obj, varargin)
        % Read current count of encoder register
        %
        %   Syntax:
        %   COUNT = readCount(ENCODEROBJ) returns count of encoder register
        %
        %   [COUNT,TIMESTAMP] = readCount(ENCODEROBJ) returns
        %   count of encoder register and the
        %   timestamp in 'dd-MMM-uuuu HH:mm:ss.SSS' format
        %
        %   COUNT = readCount(ENCODEROBJ,'Reset',true) returns
        %   encoder register count and resets encoder
        %   counter register value to zero after reading count
        %
        %   [COUNT,TIMESTAMP] = readCount(ENCODEROBJ,'Reset',true) returns
        %   encoder register count, the
        %   timestamp in 'dd-MMM-uuuu HH:mm:ss.SSS' format and resets encoder
        %   counter register value to zero after reading count
        %
        %   Example:
        %      % Construct an arduino object
        %      a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
        %
        %      % Construct MotorCarrier object
        %      mCObj = motorCarrier(a);
        %
        %      % Construct rotary encoder object
        %      en1 = rotaryEncoder(mCObj,1);
        %
        %      % Read count of encoder register
        %      count = readCount(en1);
        %
        %      % Read count of encoder register and timestamp
        %      [count,timestamp] = readCount(en1);
        %
        %  See also readSpeed, resetCount

        % Register on clean up for integrating all data
            if ~strcmpi(class(obj.Parent),'arduinoio.motorcarrier.PIDMotor')
                c = onCleanup(@() integrateData(obj.Parent.Parent,'MotorCarrier_rotaryEncoder',varargin{:}));
            end

            try
                narginchk(1,3);
                p = inputParser;
                addParameter(p, 'Reset', false,@(x)validateattributes(x,{'logical','numeric'},{'scalar','binary'}));
                parse(p, varargin{:});
            catch e
                if strcmpi(class(obj.Parent),'arduinoio.MKRPIDMotor')
                    callingMethodName = 'readAngularPosition';
                else
                    callingMethodName = 'readCount';
                end
                switch e.identifier
                  case 'MATLAB:InputParser:ParamMissingValue'
                    % throw valid error if user doesn't provide a
                    % value for parameter
                    message = e.message;
                    index = strfind(message, '''');
                    str = message(index(1)+1:index(2)-1);
                    try
                        validatestring(str,p.Parameters);
                    catch
                        if ~strcmpi(class(obj.Parent),'arduinoio.motorcarrier.PIDMotor')
                            integrateErrorKey(obj.Parent.Parent, 'MATLAB:arduinoio:general:invalidNVPropertyName');
                        end
                        obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                                           callingMethodName, ...
                                           matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                    end
                    if ~strcmpi(class(obj.Parent),'arduinoio.motorcarrier.PIDMotor')
                        integrateErrorKey(obj.Parent.Parent, 'MATLAB:InputParser:ParamMissingValue');
                    end
                    obj.localizedError('MATLAB:InputParser:ParamMissingValue', str);
                  case {'MATLAB:InputParser:UnmatchedParameter','MATLAB:InputParser:ParamMustBeChar'}
                    % throw a valid error if user tries to use invalid
                    % NV pair
                    if ~strcmpi(class(obj.Parent),'arduinoio.motorcarrier.PIDMotor')
                        integrateErrorKey(obj.Parent.Parent, 'MATLAB:arduinoio:general:invalidNVPropertyName');
                    end
                    obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                                       callingMethodName, ...
                                       matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                  otherwise
                    if ~strcmpi(class(obj.Parent),'arduinoio.motorcarrier.PIDMotor')
                        integrateErrorKey(obj.Parent.Parent, e.identifier);
                    end
                    throwAsCaller(e);
                end
            end
            resetFlag = p.Results.Reset;
            commandID = obj.READ_ENCODER_COUNT;
            params = [obj.Channel-1 resetFlag];
            countByte = sendCommand(obj,commandID,params);
            %convert to int32 count
            count = double(typecast(uint8(countByte(1:4)),'int32'));
            timestamp =  datetime('now','Format','dd-MMM-uuuu HH:mm:ss.SSS');
        end

        function [rpm,timestamp] = readSpeed(obj)
        % Measure rotational speed of motor shaft
        %
        %   Syntax:
        %   SPEEDRPM = readSpeed(ENCODEROBJ) returns current rotational
        %   speed of Motor shaft as measured by encoder in revolutions per min(RPM)
        %
        %   [SPEEDRPM,TIMESTAMP] = readSpeed(ENCODEROBJ) returns current
        %   rotational speed of Motor shaft as measured by encoder in
        %   revolutions per min(RPM) and the timestamp in
        %   'dd-MMM-uuuu HH:mm:ss.SSS' format
        %
        %   Example:
        %      % Construct an arduino object
        %      a = arduino('COM7', 'Nano33ioT', 'Libraries', 'MotorCarrier');
        %
        %      % Construct MotorCarrier object
        %      mCObj = motorCarrier(a);
        %
        %      % Construct rotary encoder object
        %      en1 = rotaryEncoder(mCObj,1);
        %
        %      % Read rotational speed of motor shaft
        %      speedRPM = readSpeed(en1);
        %
        %      % Read rotational speed of motor shaft and timestamp
        %      [speedRPM,timestamp] = readSpeed(pid);
        %
        %  See also readCount, resetCount

        % Register on clean up for integrating all data
            if ~strcmpi(class(obj.Parent),'arduinoio.motorcarrier.PIDMotor')
                c = onCleanup(@() integrateData(obj.Parent.Parent,'MotorCarrier_rotaryEncoder'));
            end

            try
                narginchk(1,1);
                commandID = obj.READ_ENCODER_SPEED;
                params = obj.Channel-1;
                countByte = sendCommand(obj,commandID,params);
                countPerCentiSec = double(typecast(uint8(countByte),'int32'));
                countPerSec = countPerCentiSec * 100;
                timestamp =  datetime('now','Format','dd-MMM-uuuu HH:mm:ss.SSS');
                rpm = (countPerSec*60)/(obj.PulsesPerRevolution*4); % converting revolutions per sec to rpm by multiplying with 60
            catch e
                if ~strcmpi(class(obj.Parent),'arduinoio.motorcarrier.PIDMotor')
                    integrateErrorKey(obj.Parent.Parent, e.identifier);
                end
                throwAsCaller(e);
            end
        end
    end

    methods(Access = private)
        function createEncoder(obj)
            commandID = obj.CREATE_ENCODER;
            if strcmpi(obj.Encoding,'X1')
                encoding = 0;
            elseif strcmpi(obj.Encoding , 'X2')
                encoding = 1;
            else
                encoding = 2;
            end
            params = [obj.Channel-1,encoding];
            sendCommand(obj,commandID,params);
        end

        function deleteEncoder(obj)
            commandID = obj.DELETE_ENCODER;
            params = obj.Channel-1;
            sendCommand(obj, commandID, params);
        end

        function configureRotaryEncoderPins(obj)
            arduinoObj = obj.MotorCarrierObj.Parent;
            [~, ~, pinMode, pinResourceOwner] = getPinInfoHook(arduinoObj,obj.IRQPin);
            if ismember(pinMode,{'Unset','Pullup'})
                if strcmpi(pinResourceOwner, '')
                    configurePinInternal(arduinoObj, obj.IRQPin, 'Unset', 'arduinoio.motorcarrier.RotaryEncoder');
                end
                pinStatus = configurePinInternal(arduinoObj, obj.IRQPin, 'Pullup', 'arduinoio.motorcarrier.RotaryEncoder', obj.ResourceOwner);
                iUndo = numel(obj.Undo)+1;
                obj.Undo(iUndo) = pinStatus;
            else
                obj.localizedError('MATLAB:hwsdk:general:reservedPin', ...
                                   obj.IRQPin, pinMode, 'Pullup');
            end
        end
    end


    methods(Access = protected)
        function delete(obj)
            originalState = warning('off','MATLAB:class:DestructorError');
            try
                arduinoObj = obj.MotorCarrierObj.Parent;
                count = decrementResourceCount(arduinoObj,obj.ResourceOwner);
                % Clear the Encoder Motor
                if ~isempty(obj.Channel)
                    encoders = getSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'encoders');
                    carrierEnAddresses = encoders(:, 1);
                    [~, locEn] = ismember(obj.MotorCarrierObj.I2CAddress, carrierEnAddresses);
                    encoders(locEn, obj.Channel+1) = 0;
                    setSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'encoders', encoders);
                end

                if(count == 0)
                    if ~isempty(obj.Undo) % only revert when pin configuration has changed
                        for idx = 1:numel(obj.Undo)
                            prevMode = configurePinResource(arduinoObj, obj.Undo(idx).Pin);
                            if strcmpi(prevMode, 'Pullup')
                                % Since there is an update in the hardware
                                % pins, it needs to use HWSDK API for Unset
                                configurePinInternal(arduinoObj, obj.Undo(idx).Pin, 'Unset', 'arduinoio.motorcarrier.RotaryEncoder', obj.ResourceOwner);
                            end
                        end
                        deleteEncoder(obj);
                    end
                end

            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            warning(originalState.state, 'MATLAB:class:DestructorError');
        end

        function output = sendCommand(obj, commandID, params)
            output = sendCarrierCommand(obj.MotorCarrierObj, commandID, params);
        end
    end
end
