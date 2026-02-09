classdef DCMotorBase < arduinoio.MotorBase
    % DCMotorBase DC motor base class
    %
    %   This file is for internal use only and is subject to change without
    %   notice.
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties(Access = protected, Constant = true)
        ResourceOwner = 'MotorCarrier\DCMotor';
        PWMFrequency = 100
        MaxDCMotors = 4
    end
    properties(Access = protected)
        DuplicateResource = false
        MotorCarrierObj
    end
    
    properties(Access = private, Constant = true)
        % MATLAB defined command IDs
        CREATE_DC_MOTOR         = 0x02
        STOP_DC_MOTOR           = 0x04
    end
    
    methods(Access = {?arduinoio.motorcarrier.PIDMotorSpeed,?arduinoio.motorcarrier.PIDMotorPosition,?arduinoio.motorcarrier.DCMotor})
        function status = validateDCMotorResourceConflict(obj)
            arduinoObj = obj.MotorCarrierObj.Parent;
            try
                dcmotors = getSharedResourceProperty(arduinoObj, obj.ResourceOwner , 'dcmotors');
            catch
                dcmotors = [obj.MotorCarrierObj.I2CAddress zeros(1, obj.MaxDCMotors)];
            end
            carrierDCAddresses = dcmotors(:, 1);
            [~, locDC] = ismember(obj.MotorCarrierObj.I2CAddress, carrierDCAddresses);
            if locDC == 0
                dcmotors = [dcmotors; obj.MotorCarrierObj.I2CAddress zeros(1, obj.MaxDCMotors)];
                locDC = size(dcmotors, 1);
            end
            if ischar(obj.MotorNumber)
                motorNumber = str2double(obj.MotorNumber(2:end));
            else
                motorNumber = obj.MotorNumber;
            end
            if dcmotors(locDC,motorNumber+1)
                status= false;
            else
                dcmotors(locDC,motorNumber+1) = 1;
                setSharedResourceProperty(arduinoObj, obj.ResourceOwner , 'dcmotors', dcmotors);
                status = true;
            end
        end
        
        function freeDCMotorResource(obj)
            arduinoObj = obj.MotorCarrierObj.Parent;
            dcmotors = getSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'dcmotors');
            carrierDCAddresses = dcmotors(:, 1);
            [~, locDC] = ismember(obj.MotorCarrierObj.I2CAddress, carrierDCAddresses);
            if ischar(obj.MotorNumber)
                motorNumber = str2double(obj.MotorNumber(2:end));
            else
                motorNumber = obj.MotorNumber;
            end
            dcmotors(locDC, motorNumber+1) = 0;
            setSharedResourceProperty(arduinoObj, obj.ResourceOwner, 'dcmotors', dcmotors);
        end
        
        function output = sendCommand(obj, commandID, params)
            if ischar(obj.MotorNumber)
                motorNumber = str2double(obj.MotorNumber(2:end));
            else
                motorNumber = obj.MotorNumber;
            end
            params = [motorNumber - 1; params];
            output = sendCarrierCommand(obj.MotorCarrierObj, commandID, params);
        end
        
        function resourceOwner = getResourceOwner(obj)
            resourceOwner = obj.ResourceOwner;
        end
        
        function PWMFrequency = getPWMFrequency(obj)
            PWMFrequency = obj.PWMFrequency;
        end
        
        function createDCM(obj)
            createDCMotor(obj);
        end
        
        function stopDCM(obj)
            stopDCMotor(obj);
        end
    end
    
    methods(Access = private)
        function createDCMotor(obj)
            commandID = obj.CREATE_DC_MOTOR;
            params = [obj.PWMFrequency];
            sendCommand(obj, commandID, params);
        end
        
        function stopDCMotor(obj)
            commandID = obj.STOP_DC_MOTOR;
            params = [];
            sendCommand(obj, commandID, params);
        end
    end
end