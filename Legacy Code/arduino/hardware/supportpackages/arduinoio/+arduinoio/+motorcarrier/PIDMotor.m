classdef PIDMotor <  matlabshared.hwsdk.internal.base & ...
        matlab.mixin.CustomDisplay
    % PIDMotor Create a PID motor device object
    
    % Copyright 2020 The MathWorks, Inc.
    properties(Hidden,WeakHandle)
        Parent arduinoio.motorcarrier.MotorCarrier
    end
    properties(GetAccess = public, SetAccess =immutable)
        PulsesPerRevolution = 3
        PIDNumber
    end
    
    properties(Access= public)
        ControlMode
        Kp
        Ki
        Kd
    end
    
    properties(GetAccess = public, SetAccess = private)
        MaxSpeed        %RPM
        MaxAcceleration %rad/s^2
    end
    
    properties(Access = private, Constant = true)
        SET_PIDGAINS                 = 0x11
        SET_MAX_ACCELERATION         = 0x12
        SET_MAX_SPEED                = 0x13
    end
    
    properties(Access = private, Constant = true)
        MaxPIDMotors = 2
        DefaultMaxAcceleration = 2.0944e+09
        DefaultMaxSpeed = 25000
    end
    
    properties(SetAccess = private, Hidden)
        DCMotorObj
        RotaryEncoderObj
    end
    
    methods(Hidden, Access = public)
        function obj = PIDMotor(parentObj, pidNumber, varargin)
            try
                narginchk(2,5); %make it 9 when allowing MaxSpeed and MaxAcceleration setting
                obj.Parent = parentObj;
                % to be uncommented for V2
                %             try
                %                p = inputParser;
                %                p.PartialMatching = true;
                %                p.KeepUnmatched = false;
                %                addParameter(p,'MaxAcceleration',2.0944e+09);
                %                addParameter(p,'MaxSpeed',25000);
                %             catch e
                %                 throwAscaller(e);
                %             end
                obj.MaxAcceleration = obj.DefaultMaxAcceleration;
                obj.MaxSpeed = obj.DefaultMaxSpeed;
                
                obj.PIDNumber = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                    ['''PIDNumber'''], ...
                    pidNumber, ...
                    1, ...
                    obj.MaxPIDMotors);
                
                if (nargin>2)
                    obj.ControlMode = varargin{1};
                else
                    obj.ControlMode = 'speed';
                end
                
                if(nargin>3)
                    obj.PulsesPerRevolution = matlabshared.hwsdk.internal.validateIntParameterRanged(...
                        ['''PulsesPerRevolution'''], ...
                        varargin{2}, ...
                        0, ...
                        intmax('int32')/4);
                end
                
                pidGains =[];
                
                if(nargin>4)
                    pidGains = varargin{3};
                end
                
                switch(obj.ControlMode)
                    case 'speed'
                        obj.DCMotorObj = arduinoio.motorcarrier.PIDMotorSpeed(obj);
                    case 'position'
                        obj.DCMotorObj = arduinoio.motorcarrier.PIDMotorPosition(obj);
                end
                
                configurePIDGains(obj,pidGains);
                configurePIDParameters(obj);
                
                obj.RotaryEncoderObj = arduinoio.motorcarrier.RotaryEncoder(obj,obj.PIDNumber,obj.PulsesPerRevolution);
            catch e
                throwAsCaller(e);
            end
            
        end
    end
    
    methods
        function set.ControlMode(obj,controlMode)
            try
                if ~isempty(obj.ControlMode)
                    matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:notSupportedControlModeSet');
                end
            catch e
                throwAsCaller(e);
            end
            try
                controlMode = validatestring(controlMode,{'speed','position','Speed','Position'});
                obj.ControlMode = lower(controlMode);
            catch
                matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:invalidPIDControlMode');
            end
        end
        
        function set.Kp(obj,Kp)
            try
                arduinoObj = obj.Parent.Parent;
                if strcmpi(arduinoObj.Board, 'Nano33IoT')
                    obj.Kp = matlabshared.hwsdk.internal.validateDoubleParameterRanged(...
                        'Kp',...
                        Kp,...
                        double(intmin('int16')), ...
                        double(intmax('int16')));
                else
                    obj.Kp =  matlabshared.hwsdk.internal.validateIntParameterRanged(...
                        'Kp', ...
                        Kp, ...
                        intmin('int16'), ...
                        intmax('int16'));
                end
                setPIDGains(obj);
            catch e
                throwAsCaller(e);
            end
        end
        
        function set.Ki(obj,Ki)
            try
                arduinoObj = obj.Parent.Parent;
                if strcmpi(arduinoObj.Board, 'Nano33IoT')
                    obj.Ki = matlabshared.hwsdk.internal.validateDoubleParameterRanged(...
                        'Ki',...
                        Ki,...
                        double(intmin('int16')), ...
                        double(intmax('int16')));
                else
                    obj.Ki =  matlabshared.hwsdk.internal.validateIntParameterRanged(...
                        'Ki', ...
                        Ki, ...
                        intmin('int16'), ...
                        intmax('int16'));
                end
                setPIDGains(obj);
            catch e
                throwAsCaller(e);
            end
        end
        
        function set.Kd(obj,Kd)
            try
                arduinoObj = obj.Parent.Parent;
                if strcmpi(arduinoObj.Board, 'Nano33IoT')
                    obj.Kd = matlabshared.hwsdk.internal.validateDoubleParameterRanged(...
                        'Kd',...
                        Kd,...
                        double(intmin('int16')), ...
                        double(intmax('int16')));
                else
                    obj.Kd =  matlabshared.hwsdk.internal.validateIntParameterRanged(...
                        'Kd', ...
                        Kd, ...
                        intmin('int16'), ...
                        intmax('int16'));
                end
                setPIDGains(obj);
            catch e
                throwAsCaller(e);
            end
        end
        
        function writeAngularPosition(obj, position,varargin)
            % Write angular position of pid motor shaft
            %
            %   Syntax:
            %   writeAngularPosition(PIDMOTOROBJ, ANGULARPOS) Rotates motor
            %   shaft of motor connected to PIDMOTOROBJ by ANGULARPOS radians
            %   writeAngularPosition(PIDMOTOROBJ, ANGULARPOS, 'rel') Rotates
            %   motor shaft of motor connected to PIDMOTOROBJ by ANGULARPOS radians
            %   writeAngularPosition(PIDMOTOROBJ, ANGULARPOS, 'abs') Rotates
            %   motor shaft of motor connected to PIDMOTOROBJ to absolute position
            %   ANGULARPOS radians with reference to position at the time of pid object creation
            %
            %    Example:
            %       % Construct an arduino object
            %       a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
            %
            %       % Construct MotorCarrier object
            %       mCObj = motorCarrier(a);
            %
            %       % Construct pidMotor object
            %       pid = pidMotor(mCObj, 1);
            %
            %       % Rotate motor shaft by 2pi radians from current position
            %       writeAngularPosition(pid, 2*pi);
            %
            %       % Rotate motor shaft by 2pi radians from current position
            %       writeAngularPosition(pid, 2*pi, 'rel');
            %
            %       % Rotate motor shaft to absolute pi radians
            %       writeAngularPosition(pid, pi, 'abs');
            %
            %   See also writeSpeed, readAngularPosition, readSpeed
            
            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent.Parent, 'MotorCarrier_pidmotor', varargin{:}));

            try
                writeAngularPosition(obj.DCMotorObj,position, varargin{:});
            catch e
                integrateErrorKey(obj.Parent.Parent, e.identifier);
                throwAsCaller(e);
            end
        end
        
        function writeSpeed(obj, speed)
            % Write speead of pidMotor
            %
            %   Syntax:
            %   writeSpeed(PIDMOTOROBJ, SPEEDVAL) Rotates motor shaft of
            %   motor connected to PIDMOTOROBJ at SPEEDVAL revolutions per minute (RPM)
            %
            %   Example:
            %      % Construct an arduino object
            %      a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
            %
            %      % Construct MotorCarrier object
            %      mCObj = motorCarrier(a);
            %
            %      % Construct pidMotor object
            %      pid = pidMotor(mCObj, 1);
            %
            %      % Rotate motor shaft at 3000 RPM
            %      writeSpeed(pid,3000);
            %
            %   See also writeAngularPosition, readAngularPosition, readSpeed
            
            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent.Parent,'MotorCarrier_pidmotor'));

            try
                writeSpeed(obj.DCMotorObj,speed);
            catch e
                integrateErrorKey(obj.Parent.Parent, e.identifier);
                throwAsCaller(e);
            end
        end
        
        function [rpm,timestamp] = readSpeed(obj)
            % Measure rotational speed of motor shaft
            %
            %   Syntax:
            %   SPEEDRPM = readSpeed(PIDMOTOROBJ) returns current rotational
            %   speed of Motor shaft as measured by encoder in revolutions per min(RPM)
            %
            %   [SPEEDRPM,TIMESTAMP] = readSpeed(PIDMOTOROBJ) returns current
            %   rotational speed of Motor shaft as measured by encoder in
            %   revolutions per min(RPM) and the timestamp in
            %   'dd-MMM-uuuu HH:mm:ss.SSS' format
            %
            %   Example:
            %      % Construct an arduino object
            %      a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
            %
            %      % Construct MotorCarrier object
            %      mCObj = motorCarrier(a);
            %
            %      % Construct pidMotor object
            %      pid = pidMotor(mkrMCObj,1);
            %
            %      % Rotate motor shaft at 3000 RPM
            %      writeSpeed(pid,3000);
            %
            %      % Read rotation speed of motor shaft
            %      speedRPM = readSpeed(pid);
            %      [speedRPM,timestamp] = readSpeed(pid);
            %
            %  See also writeSpeed, writeAngularPosition, readAngularPosition
            
            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent.Parent,'MotorCarrier_pidmotor'));
            try
                [rpm,timestamp] = readSpeed(obj.RotaryEncoderObj);
            catch e
                integrateErrorKey(obj.Parent.Parent, e.identifier);
                throwAsCaller(e);
            end
        end
        
        function [position,timestamp] = readAngularPosition(obj,varargin)
            % Measure current position of motor shaft
            %
            %   Syntax:
            %   ANGULARPOS = readAngularPosition(PIDMOTOROBJ) returns
            %   angular position of motor in radians
            %
            %   [ANGULARPOS,TIMESTAMP] = readAngularPosition(PIDMOTOROBJ) returns
            %   angular position of motor in radians and the
            %   timestamp in 'dd-MMM-uuuu HH:mm:ss.SSS' format
            %
            %   ANGULARPOS = readAngularPosition(PIDMOTOROBJ,'Reset',true) returns
            %   angular position of motor in radians and resets encoder
            %   counter register value to zero after reading count
            %
            %   [ANGULARPOS,TIMESTAMP] = readAngularPosition(PIDMOTOROBJ,'Reset',true) returns
            %   angular position of motor in radians, the
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
            %      % Construct pidMotor object
            %      pid = pidMotor(mkrMCObj,1);
            %
            %      % Rotate motor shaft at 3000 RPM
            %      writeSpeed(pid,3000);
            %
            %      % Read angular position of motor shaft
            %      angularPos = readAngularPosition(pid);
            %      [angularPos,timestamp] = readAngularPosition(pid);
            %
            %  See also writeSpeed, writeAngularPosition, readSpeed

            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent.Parent, 'MotorCarrier_pidmotor', varargin{:}));
            try
                narginchk(1,3);
                [count,timestamp] = readCount(obj.RotaryEncoderObj,varargin{:});
                % convert count to angle in radians. Since this is an X4
                % encoder dividing counts by 4*ppr
                position = count*2*pi/(obj.PulsesPerRevolution*4);
            catch e
                integrateErrorKey(obj.Parent.Parent, e.identifier);
                throwAsCaller(e);
            end
        end
    end
    
    %% Destructor
    methods(Access = protected)
        function delete(obj)
            originalState = warning('off','MATLAB:class:DestructorError');
            try
                delete(obj.DCMotorObj);
                delete(obj.RotaryEncoderObj);
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            warning(originalState.state, 'MATLAB:class:DestructorError');
        end
    end
    
    %% Private methods
    methods (Access = private)
        function configurePIDGains(obj,pidGains)
            if isempty(pidGains)
                arduinoObj = obj.Parent.Parent;
                if ismember(arduinoObj.Board, arduinoio.internal.ArduinoConstants.NanoCarrierSupportedBoards)
                    obj.Kp = obj.DCMotorObj.KpNanoMC;
                    obj.Ki = obj.DCMotorObj.KiNanoMC;
                    obj.Kd = obj.DCMotorObj.KdNanoMC;
                else
                    % For boards MKR1000, MKR1010, or MKRZero
                    obj.Kp = obj.DCMotorObj.KpMKRMC;
                    obj.Ki = obj.DCMotorObj.KiMKRMC;
                    obj.Kd = obj.DCMotorObj.KdMKRMC;
                end
                
            else
                if(size(pidGains,2)~=3)
                    matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:invalidPIDGainsFormat');
                end
                obj.Kp = pidGains(1);
                obj.Ki = pidGains(2);
                obj.Kd = pidGains(3);
            end
        end
        
        function configurePIDParameters(obj)
            setMaxAcceleration(obj);
            % uncomment when MaxSpeed is implemented by Arduino
            % setMaxSpeed(obj);
        end
        
        function setPIDGains(obj)
            if ~isempty(obj.Kp) && ~isempty(obj.Ki) && ~isempty(obj.Kd)
                arduinoObj = obj.Parent.Parent;
                if strcmpi(arduinoObj.Board, 'Nano33IoT')
                    % Send 4 bytes each of floating point gain values
                    gains = typecast( [cast(obj.Kp, 'single'), ...
                        cast(obj.Ki, 'single'), ...
                        cast(obj.Kd, 'single')], 'uint8');
                else
                    % For boards MKR1000, MKR1010, or MKRZero
                    % Send 2 bytes each of int16 gain values
                    gains = typecast([cast(obj.Kp,'int16'), ...
                        cast(obj.Ki,'int16'), ...
                        cast(obj.Kd,'int16')],'uint8');
                end
                sendCommand(obj,obj.SET_PIDGAINS,gains');
            end
        end
        
        function setMaxAcceleration(obj)
            % convert Acceleration to counts/(millisecond)^2
            convertedAccel = cast((obj.MaxAcceleration*4*obj.PulsesPerRevolution)/(2*pi*10^6),'int16');
            if ~isempty(obj.DCMotorObj)
                sendCommand(obj,obj.SET_MAX_ACCELERATION, typecast(convertedAccel,'uint8')');
            end
        end
        
        function setMaxSpeed(obj)
            %convert Speed to counts/millisecond
            convertedSpeed = cast(obj.MaxSpeed*4*obj.PulsesPerRevolution/(1000*60),'int16');
            if ~isempty(obj.DCMotorObj)
                sendCommand(obj,obj.SET_MAX_SPEED, typecast(convertedSpeed,'uint8')');
            end
        end
        
        function output = sendCommand(obj, commandID, params)
            params = [obj.PIDNumber - 1; params];
            output = sendCarrierCommand(obj.Parent, commandID, params);
        end
    end
    
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            arduinoObj = obj.Parent.Parent;
            
            % Display main options
            fprintf('             PIDNumber: %d\n', obj.PIDNumber);
            fprintf('           ControlMode:''%s''\n', obj.ControlMode);
            fprintf('   PulsesPerRevolution: %d\n', obj.PulsesPerRevolution);
            if strcmpi(arduinoObj.Board, 'Nano33IoT')
                fprintf('                    Kp: %f\n', obj.Kp);
                fprintf('                    Ki: %f\n', obj.Ki);
                fprintf('                    Kd: %f\n', obj.Kd);
            else
                fprintf('                    Kp: %d\n', obj.Kp);
                fprintf('                    Ki: %d\n', obj.Ki);
                fprintf('                    Kd: %d\n', obj.Kd);
            end
            fprintf('       MaxAcceleration: %ld (rad/s^2)\n', obj.MaxAcceleration);
            fprintf('              MaxSpeed: %d (RPM)\n', obj.MaxSpeed);
            fprintf('\n');
            
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end