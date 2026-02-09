classdef DCMotor < arduinoio.motorcarrier.DCMotorBase & matlab.mixin.CustomDisplay
%   DCMotor Create a DC motor object

%   Copyright 2020-2023 The MathWorks, Inc.

    properties(Hidden,WeakHandle)
        Parent arduinoio.motorcarrier.MotorCarrier
    end
    properties(Access = public)
        Speed = 0
    end

    properties (Dependent = true, Access = private)
        ConvertedDutyCycle
    end

    properties (SetAccess = private)
        Running = false;
    end

    properties(Access = private)
        MotorNumberNum
        Undo
        M3_AnalogPin
        M4_AnalogPin
    end

    properties(Access = private, Constant = true)
        % MATLAB defined command IDs
        START_DC_MOTOR          = 0x03
        SET_DUTYCYCLE_DC_MOTOR  = 0x05
        M3_IN1 = 'D3'
        M3_IN2 = 'D2'
        M4_IN1 = 'D5'
        M4_IN2 = 'D4'
    end


    %% Constructor
    methods(Hidden, Access = public)
        function obj = DCMotor(parentObj, motorNumber, varargin)
            try
                narginchk(2,4);
                obj.Parent = parentObj;
                obj.MotorCarrierObj = parentObj;
                if isstring(motorNumber) || ischar(motorNumber)
                    if isstring(motorNumber)
                        motorNumber = char(motorNumber);
                    end
                    if strcmpi(motorNumber(1:end-1),'M')
                        motorNumber = str2double(motorNumber(end));
                    else
                        obj.localizedError('MATLAB:arduinoio:general:invalidMCMotorNumber','DC', 'M1', 'M4');
                    end
                elseif ~isnumeric(motorNumber)
                    if iscell(motorNumber)
                        obj.localizedError('MATLAB:arduinoio:general:invalidMCMotorNumberType','DC','M1','M4');
                    else
                        obj.localizedError('MATLAB:arduinoio:general:invalidMCMotorNumber','DC', 'M1', 'M4');
                    end
                end

                % get numeric motorNumber and make motorNumber 'M1','M2'
                % etc to process further
                obj.MotorNumberNum = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                    ['DC ' '''MotorNumber'''], ...
                    motorNumber, ...
                    1, ...
                    obj.MaxDCMotors);
                motorNumber = strcat('M',num2str(motorNumber));
                try
                    p = inputParser;
                    p.PartialMatching = true;
                    addParameter(p, 'Speed', 0);
                    parse(p, varargin{1:end});
                catch e
                    switch e.identifier
                      case 'MATLAB:InputParser:ParamMissingValue'
                        message = e.message;
                        index = strfind(message, '''');
                        str = message(index(1)+1:index(2)-1);
                        % throw valid error if user doesn't provide a
                        % value for parameter
                        try
                            validatestring(str,p.Parameters);
                        catch
                            obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                                               obj.ResourceOwner, ...
                                               matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                        end
                        obj.localizedError('MATLAB:InputParser:ParamMissingValue', str);
                      case 'MATLAB:InputParser:UnmatchedParameter'
                        % throw a valid error if user tries to use invalid
                        % NV pair
                        obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                                           obj.ResourceOwner, ...
                                           matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                      case 'MATLAB:InputParser:ParamMustBeChar'
                        obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                                           obj.ResourceOwner, ...
                                           matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
                      otherwise
                        %do nothing, as error is coming from an unknown
                        %scenario
                    end
                end
                obj.Speed = p.Results.Speed;
                obj.MotorNumber = motorNumber;
                if ~validateDCMotorResourceConflict(obj)
                    obj.DuplicateResource = true;
                    obj.localizedError('MATLAB:arduinoio:general:conflictResourceMC', 'DCMotor', char(strcat('''', motorNumber, '''')));
                end
                obj.Undo = [];
                configureDCMotorPins(obj);
                createDCM(obj);
            catch e
                throwAsCaller(e);
            end
        end
    end

    methods
        function start(obj)
        %   Start the DC motor.
        %
        %   Syntax:
        %   start(dcm) Start the DC motor so that it can rotate if Speed is non-zero
        %
        %   Example:
        %       % Construct an arduino object
        %       a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
        %
        %       % Construct MotorCarrier object
        %       mCObj = motorCarrier(a);
        %
        %       % Construct dcmotor object
        %       dcm = dcmotor(mCObj,'M1');
        %
        %       % start dc motor
        %       start(dcm);
        %
        %   See also stop

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent.Parent, 'MotorCarrier_dcmotor'));

            try
                if obj.Running == false
                    if obj.Speed ~= 0
                        startDCMotor(obj);
                    end
                    obj.Running = true;
                else
                    obj.localizedWarning('MATLAB:arduinoio:general:dcmotorAlreadyRunning', num2str(obj.MotorNumber));
                end
            catch e
                integrateErrorKey(obj.Parent.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function stop(obj)
        %   Stop the DC motor.
        %
        %   Syntax:
        %   stop(cm) Stop the DC motor if it has been started
        %
        %   Example:
        %       % Construct an arduino object
        %       a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
        %
        %       % Construct MotorCarrier object
        %       mCObj = motorCarrier(a);
        %
        %       % Construct dcmotor object
        %       dcm = dcmotor(mCObj,'M1');
        %
        %       % start dc motor
        %       start(dcm);
        %
        %       % stop dc motor
        %       stop(dcm);
        %
        %   See also start

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent.Parent, 'MotorCarrier_dcmotor'));
            try
                if obj.Running == true
                    stopDCM(obj);
                    obj.Running = false;
                end
            catch e
                integrateErrorKey(obj.Parent.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function set.Speed(obj, Speed)
        % Valid Speed range is -1 to 1
            try
                narginchk(2,2);
                Speed = matlabshared.hwsdk.internal.validateDoubleParameterRanged(...
                    'DC Motor Speed', Speed, -1, 1);
                if Speed == -0
                    Speed = 0;
                end
                if obj.Running
                    convertedDutyCycle = round(Speed*100);
                    setDutyCycleDCMotor(obj, convertedDutyCycle);
                end
                obj.Speed = Speed;
            catch e
                throwAsCaller(e);
            end
        end

        function out = get.ConvertedDutyCycle(obj)
        % Convert Speed from range [-1, 1] to [-100 100] as required by motorCarrier
            out = round(obj.Speed * 100);
        end
    end

    methods (Access=protected)
        function delete(obj)
            originalState = warning('off','MATLAB:class:DestructorError');
            try
                % Clear the DC Motor
                if ~obj.DuplicateResource && ~isempty(obj.MotorNumber)
                    stopDCM(obj);
                    freeDCMotorResource(obj);
                end
                if ismember(obj.MotorNumber,{'M3','M4'})
                    arduinoObj = obj.Parent.Parent;
                    if ~isempty(obj.Undo) % only revert when pin configuration has changed
                        for idx = 1:numel(obj.Undo)
                            prevMode = configurePinResource(arduinoObj, obj.Undo(idx).Pin);
                            if strcmpi(prevMode, 'PWM') || strcmpi(prevMode, 'AnalogInput')
                                configurePinResource(arduinoObj, obj.Undo(idx).Pin, obj.ResourceOwner, 'Unset', false);
                            end
                        end
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            warning(originalState.state, 'MATLAB:class:DestructorError');
        end
    end

    methods (Access = private)
        function INPins = getINPins(obj)
            if strcmpi(obj.MotorNumber,'M3')
                INPins{1} = obj.M3_IN1;
                INPins{2} = obj.M3_IN2;
            elseif strcmpi(obj.MotorNumber,'M4')
                INPins{1} = obj.M4_IN1;
                INPins{2} = obj.M4_IN2;
            end
        end

        function analogPin = getAnalogPin(obj)
            motorCarrierObj = obj.Parent;
            arduinoObj = motorCarrierObj.Parent;
            if strcmpi(arduinoObj.Board, 'Nano33IoT')
                % Nano Motor Carrier
                obj.M3_AnalogPin = 'A0';
                obj.M4_AnalogPin = 'A1';
            else
                % MKR Motor Carrier
                obj.M3_AnalogPin = 'A3';
                obj.M4_AnalogPin = 'A4';
            end

            if strcmpi(obj.MotorNumber,'M3')
                analogPin = obj.M3_AnalogPin;
            elseif strcmpi(obj.MotorNumber,'M4')
                analogPin = obj.M4_AnalogPin;
            end
        end

        function startDCMotor(obj)
            commandID = obj.START_DC_MOTOR;
            dutycycle = (obj.ConvertedDutyCycle);
            params = typecast(int16(dutycycle),'uint8');
            sendCommand(obj, commandID, params');
        end

        function setDutyCycleDCMotor(obj, Speed)
            commandID = obj.SET_DUTYCYCLE_DC_MOTOR;
            params = typecast(int16(Speed),'uint8');
            sendCommand(obj, commandID, params');
        end

        function configureDCMotorPins(obj)
            if ismember(obj.MotorNumber,{'M3','M4'})
                arduinoObj = obj.Parent.Parent;
                % configure PWM pins
                INPins = getINPins(obj);
                for i = 1:numel(INPins)
                    [~, ~, pinMode, pinResourceOwner] = getPinInfoHook(arduinoObj,INPins{i});
                    if ismember(pinMode,{'Unset','PWM'})
                        if strcmpi(pinResourceOwner, '')
                            configurePinResource(arduinoObj, INPins{i}, '', 'Unset');
                        end
                        configurePinWithUndo(obj,INPins{i},'PWM', false);
                    else
                        obj.localizedError('MATLAB:hwsdk:general:reservedPWMPin', ...
                                           INPins{i}, pinMode, 'PWM', 'Arduino');
                    end
                end

                % configure Analog pin
                analogPin = getAnalogPin(obj);
                [~, ~, pinMode, pinResourceOwner] = getPinInfoHook(arduinoObj,analogPin);
                if ismember(pinMode,{'Unset','AnalogInput'})
                    if strcmpi(pinResourceOwner, '')
                        configurePinResource(arduinoObj, analogPin, '', 'Unset');
                    end
                    configurePinWithUndo(obj,analogPin, 'AnalogInput', false);
                else
                    obj.localizedError('MATLAB:hwsdk:general:reservedAnalogPin', ...
                                       analogPin, pinMode, 'AnalogInput', 'Arduino');
                end
            end
        end

        function configurePinWithUndo(obj, pin, pinMode, forceConfig)
            arduinoObj = obj.Parent.Parent;
            resourceOwner = obj.ResourceOwner;
            prevMode = configurePinResource(arduinoObj, pin);
            terminal = getTerminalsFromPins(arduinoObj, pin);
            prevResourceOwner = getResourceOwner(arduinoObj, terminal);
            iUndo = numel(obj.Undo)+1;
            obj.Undo(iUndo).Pin = pin;
            obj.Undo(iUndo).ResourceOwner = prevResourceOwner;
            obj.Undo(iUndo).PinMode = prevMode;
            configurePinResource(arduinoObj, pin, resourceOwner, pinMode, forceConfig);
        end
    end

    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            % Display main options
            fprintf('    MotorNumber: ''%s''\n', obj.MotorNumber);
            fprintf('        Running: %-15d\n', obj.Running);
            fprintf('          Speed: %-15d\n', obj.Speed);
            fprintf('\n');

            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end
