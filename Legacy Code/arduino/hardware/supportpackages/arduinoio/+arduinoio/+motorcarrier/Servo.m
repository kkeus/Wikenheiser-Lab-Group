classdef Servo < arduinoio.MotorBase & matlab.mixin.CustomDisplay
    %Servo Create a Servo object.
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties(Hidden,WeakHandle)
        Parent arduinoio.motorcarrier.MotorCarrier
    end

    properties(Access = private)
        ResourceOwner = 'MotorCarrier\Servo';
    end
    
    properties(Access = private, Constant = true)
        % MATLAB defined command IDs
        CREATE_SERVO_MOTOR     = 0x06
        CLEAR_SERVO_MOTOR      = 0x07
        READ_SERVO_POSITION    = 0x08
        WRITE_SERVO_POSITION   = 0x09
    end
    
    properties(Access = private, Constant = true)
        MaxServoMotors = 4
        PWMFrequency = 50
    end
    
    %% Constructor
    methods(Hidden, Access = public)
        function obj = Servo(parentObj, motorNumber)
            obj.Parent = parentObj;
            arduinoObj = parentObj.Parent;
            narginchk(2,2);
            try
                if isnumeric(motorNumber)
                    motorNumber = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                        ['Servo ''MotorNumber'''], ...
                        motorNumber, ...
                        1, ...
                        obj.MaxServoMotors);
                else
                    if strcmpi(motorNumber(1:end-1),'servo')
                        motorNumber = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                            [obj.ResourceOwner 'MotorNumber'], ...
                            str2double(motorNumber(end)), ...
                            1, ...
                            obj.MaxServoMotors);
                    else
                        obj.localizedError('MATLAB:arduinoio:general:invalidMCMotorNumber', 'Servo', '1', num2str(obj.MaxServoMotors));
                    end
                end
            catch e
                if isnumeric(motorNumber)
                    throwAsCaller(e);
                else
                    obj.localizedError('MATLAB:arduinoio:general:invalidMCMotorNumber', 'Servo', '1', num2str(obj.MaxServoMotors));
                end
            end
           
            try
                servos = getSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'servos');
            catch
                servos = [parentObj.I2CAddress zeros(1, obj.MaxServoMotors)];
            end
            shieldSCAddresses = servos(:, 1);
            [~, locSC] = ismember(parentObj.I2CAddress, shieldSCAddresses);
            if locSC == 0
                servos = [servos; parentObj.I2CAddress zeros(1, obj.MaxServoMotors)];
                locSC = size(servos, 1);
            end
            
            % Check for resource conflict with Servo Motors
            if servos(locSC, motorNumber+1)
                obj.localizedError('MATLAB:arduinoio:general:conflictResourceMC', 'Servo', num2str(motorNumber));
            end
            % No conflicts
            servos(locSC, motorNumber+1) = 1;
            setSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'servos', servos);
            obj.MotorNumber = motorNumber;
            createServoMotor(obj);
        end
    end
    
    methods
        function writePosition(obj,value)
            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent.Parent,'MotorCarrier_servo'));

            try
                narginchk(2,2);
                matlabshared.hwsdk.internal.validateDoubleParameterRanged('position', value, 0, 1);
                writeServoPosition(obj,value);
            catch e
                integrateErrorKey(obj.Parent.Parent, e.identifier);
                throwAsCaller(e);
            end
        end
    end
    
    
    
    %% Destructor
    methods (Access=protected)
        function delete(obj)
            originalState = warning('off','MATLAB:class:DestructorError');
            try
                parentObj = obj.Parent;
                arduinoObj = parentObj.Parent;
                
                % Clear the Servo Motor
                if ~isempty(obj.MotorNumber)
                    clearServoMotor(obj);
                end
                servos = getSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'servos');
                shieldSCAddresses = servos(:, 1);
                [~, locSC] = ismember(parentObj.I2CAddress, shieldSCAddresses);
                servos(locSC, obj.MotorNumber+1) = 0;
                setSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'servos', servos);
                
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            warning(originalState.state, 'MATLAB:class:DestructorError');
        end
    end
    
    methods (Access = private)
        function createServoMotor(obj)
            commandID = obj.CREATE_SERVO_MOTOR;
            params = [obj.PWMFrequency];
            sendCommand(obj, commandID, params);
        end
        
        function writeServoPosition(obj,value)
            commandID = obj.WRITE_SERVO_POSITION;
            params = [uint8(180*value)];
            sendCommand(obj, commandID, params);
        end
        
        function clearServoMotor(obj)
            commandID = obj.CLEAR_SERVO_MOTOR;
            params = [];
            sendCommand(obj, commandID, params);
        end
    end
    
    methods(Access = protected)
        function output = sendCommand(obj, commandID, params)
            params = [obj.MotorNumber - 1; params];
            output = sendCarrierCommand(obj.Parent, commandID, params);
        end
    end
    
    %% Protected methods
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            
            % Display main options
            fprintf('    MotorNumber: %d (Servo%d)\n', obj.MotorNumber,obj.MotorNumber);
            fprintf('\n');
            
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end