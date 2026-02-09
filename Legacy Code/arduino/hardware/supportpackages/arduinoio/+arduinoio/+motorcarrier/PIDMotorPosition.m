classdef PIDMotorPosition < arduinoio.motorcarrier.DCMotorBase
    %   PIDMotorPosition Creates PIDMotor for Position Control
    %
    %   This file is for internal use only and is subject to change without
    %   notice.
    
    %   Copyright 2020 The MathWorks, Inc.
    properties(Hidden,WeakHandle)
        Parent arduinoio.motorcarrier.PIDMotor
    end
    properties(Access = private, Constant = true)
        SET_DCM_POSITION = 0x10
    end
    
    properties(Access = private, Constant = true)
        % PID position count range is modified: g2262621
        % Position range values for Nano motor carrier
        MaxCountNanoMC = 2^21 - 1
        MinCountNanoMC = -2^21
        % Position range values for MKR motor carrier
        MaxCountMKRMC  = 2^15 - 1
        MinCountMKRMC  = -2^15
    end
    
    properties(GetAccess = {?arduinoio.motorcarrier.PIDMotor}, Constant = true)
        % default PID gains for position control for Nano Motor Carrier
        KpNanoMC = 0.18
        KiNanoMC = 0.0
        KdNanoMC = 0.01
        % default PID gains for position control for MKR Motor Carrier
        KpMKRMC = 25
        KiMKRMC = 0
        KdMKRMC = 3
    end
    
    methods(Hidden, Access = public)
        function obj = PIDMotorPosition(parentObj)
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
        function writeAngularPosition(obj, position,varargin)
            narginchk(1,3);
            try
                if(nargin>2)
                    positionMode = validateAngularPositionMode(obj, varargin{1});
                else
                    positionMode = 'rel';
                end
                motorObj = obj.Parent.Parent;
                arduinoObj = motorObj.Parent;
                if ismember(arduinoObj.Board, arduinoio.internal.ArduinoConstants.NanoCarrierSupportedBoards)
                    position = matlabshared.hwsdk.internal.validateDoubleParameterRanged(...
                        'PIDMotor Position', position, floor(obj.MinCountNanoMC*2*pi/(4*obj.Parent.PulsesPerRevolution)),floor(obj.MaxCountNanoMC*2*pi/(4*obj.Parent.PulsesPerRevolution)));
                else
                    position = matlabshared.hwsdk.internal.validateDoubleParameterRanged(...
                        'PIDMotor Position', position, floor(obj.MinCountMKRMC*2*pi/(4*obj.Parent.PulsesPerRevolution)),floor(obj.MaxCountMKRMC*2*pi/(4*obj.Parent.PulsesPerRevolution)));
                end
                positionCount = floor(position*(4*obj.Parent.PulsesPerRevolution)/(2*pi));
                setPositionDCMotor(obj, positionCount, positionMode);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods (Access = private)
        function mode = validateAngularPositionMode(~, mode)
            if ischar(mode)
                mode = string(mode);
            end
            mode = validatestring(mode,["abs","rel","absolute","relative"]);
            if strcmpi(mode,"absolute")
                mode = "abs";
            elseif strcmpi(mode, "relative")
                mode = "rel";
            end
        end
        
        function setPositionDCMotor(obj, position, positionMode)
            commandID = obj.SET_DCM_POSITION;
            params = [];
            if strcmpi(positionMode,'rel')
                params = [params 1];
            else
                params = [params 0];
            end
            motorObj = obj.Parent.Parent;
            arduinoObj = motorObj.Parent;
            if ismember(arduinoObj.Board, arduinoio.internal.ArduinoConstants.NanoCarrierSupportedBoards)
                params = [params typecast(int32(position),'uint8')];
            else
                params = [params typecast(int16(position),'uint8')];
            end
            sendCommand(obj, commandID, params');
        end
    end
end