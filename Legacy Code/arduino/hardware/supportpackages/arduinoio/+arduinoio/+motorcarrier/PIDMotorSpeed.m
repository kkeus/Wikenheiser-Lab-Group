classdef PIDMotorSpeed < arduinoio.motorcarrier.DCMotorBase
    % PIDMotorSpeed Creates PIDMotor for Speed Control
    %
    %   This file is for internal use only and is subject to change without
    %   notice.
    
    %   Copyright 2020 The MathWorks, Inc.
    properties(Hidden,WeakHandle)
        Parent arduinoio.motorcarrier.PIDMotor
    end
    properties(Access = private, Constant = true)
        MaxSpeed =  25000; %RPM
        MinSpeed = -25000; %RPM
    end
    
    properties(Access = private, Constant = true)
        SET_DCM_VELOCITY  = 0x0F
    end
    
    properties(GetAccess = {?arduinoio.motorcarrier.PIDMotor}, Constant = true)
        % default PID gains for speed control for Nano Motor Carrier
        KpNanoMC = 5.2
        KiNanoMC = 0.3
        KdNanoMC = 0.0
        % default PID gains for speed control for MKR Motor Carrier
        KpMKRMC = 2000
        KiMKRMC = 200
        KdMKRMC = 0
    end
    
    methods(Hidden, Access = public)
        function obj = PIDMotorSpeed(parentObj)
            obj.Parent = parentObj;
            obj.MotorCarrierObj = parentObj.Parent;
            obj.MotorNumber = parentObj.PIDNumber;
            if ~validateDCMotorResourceConflict(obj)
                obj.DuplicateResource = true;
                matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:conflictResourceMC', 'PID Motor', char(strcat({''''},'M', num2str(obj.MotorNumber), {''''})));
            end
            createDCM(obj);
        end
    end
    
    methods(Access = protected)
        function delete(obj)
            try
                if ~obj.DuplicateResource
                    freeDCMotorResource(obj);
                    stopDCM(obj);
                end
            catch
            end
        end
    end
    
    methods
        function writeSpeed(obj, speed)
            try
                narginchk(1,2);
                speed = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                    'PIDMotor Speed', speed, obj.MinSpeed,obj.MaxSpeed); % raw values supported only between -50 and 50
                speed = (speed * obj.Parent.PulsesPerRevolution*4)/(100*60); % convert RPM to counts per centisecond. obj.PulsesPerRevolution*4 is the number of pulses pulse per rev of the encoder shaft for X4 encoding
                setSpeedDCMotor(obj,speed);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods (Access = private)
        function setSpeedDCMotor(obj, speed)
            commandID = obj.SET_DCM_VELOCITY;
            params = typecast(int16(speed),'uint8');
            sendCommand(obj, commandID, params');
        end
    end
end