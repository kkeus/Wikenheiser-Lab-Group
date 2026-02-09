classdef MotorCarrier < matlabshared.addon.LibraryBase & matlab.mixin.CustomDisplay
%MotorCarrier Create an Arduino motor carrier object
%
%   MotorCarrier methods:
%       dcmotor       - Attach a DC motor to the specified port on MKR or Nano Motor Carrier
%       servo         - Attach a servo motor to the specified port on MKR or Nano Motor Carrier
%       rotaryEncoder - Attach a rotary encoder to the specified port on MKR or Nano Motor Carrier
%       pidMotor      - Attach a PID motor to the specified port on MKR or Nano Motor Carrier
%

%   Copyright 2020-2023 The MathWorks, Inc.

    properties(Access = private, Constant = true)
        CREATE_MOTOR_CARRIER = 0x00
        DELETE_MOTOR_CARRIER = 0x01
    end

    properties(Access = private, Constant = true)
        Bus = 0
        ResourceOwner    = 'I2C';    % Resource owner of I2C devices changes to I2C
        BusResourceOwner = 'I2CBus0';
    end

    properties(Access = private)
        DuplicateObj = 0
    end

    properties(GetAccess = public, Constant = true)
        I2CAddress = hex2dec('66');
    end

    properties(Access = protected, Constant = true)
        LibraryName = 'MotorCarrier'
        DependentLibraries = ''
        LibraryHeaderFiles = 'ArduinoMotorCarrier/ArduinoMotorCarrier.h'
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'MotorCarrierBase.h')
        CppClassName = 'MotorCarrierBase'

    end

    % AlternateLibraryHeaders
    properties(Access = protected)
        AlternateLibraryHeaderFiles = 'MKRMotorCarrier/MKRMotorCarrier.h'
    end

    properties(GetAccess = public, SetAccess = protected)
        SCLPin
        SDAPin
    end


    %% Constructor
    methods(Hidden, Access = public)
        function obj = MotorCarrier(parentObj, varargin)
            try
                narginchk(1,1);
                obj.Parent = parentObj;
                try
                    i2cAddresses = getSharedResourceProperty(parentObj, obj.BusResourceOwner, 'i2cAddresses');
                catch
                    i2cAddresses = [];
                end
                if ismember(obj.I2CAddress,i2cAddresses)
                    obj.DuplicateObj =1 ;
                    obj.localizedError('MATLAB:arduinoio:general:conflictI2CAddress', ...
                                       num2str(obj.I2CAddress),...
                                       dec2hex(obj.I2CAddress));
                end
                i2cAddresses = [i2cAddresses obj.I2CAddress];
                setSharedResourceProperty(obj.Parent, obj.BusResourceOwner, 'i2cAddresses', i2cAddresses);
                configureI2C(obj);
                incrementResourceCount(obj.Parent, obj.BusResourceOwner);
                createMotorCarrier(obj);
                setSharedResourceProperty(parentObj, 'I2C', 'I2CIsUsed', true);
            catch e
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
                % Get the available resource count for respective resource owner
                count = getResourceCount(obj.Parent, obj.BusResourceOwner);
                % Dont decrement further if resource count is already zero
                if (count~=0)
                    count = decrementResourceCount(obj.Parent, obj.BusResourceOwner);
                end
                i2cAddresses = getSharedResourceProperty(parentObj, obj.BusResourceOwner, 'i2cAddresses');
                if(~obj.DuplicateObj)
                    if ~isempty(i2cAddresses)
                        i2cAddresses(i2cAddresses==obj.I2CAddress) = [];
                    end
                    setSharedResourceProperty(parentObj,obj.BusResourceOwner, 'i2cAddresses', i2cAddresses);
                    %unconfigure I2C Pins
                    I2CTerminals = parentObj.getI2CTerminals();
                    sda = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+1));
                    sda = sda{1};
                    scl = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+2));
                    scl = scl{1};
                    deleteMotorCarrier(obj);
                    if(count == 0)
                        configurePinResource(parentObj, sda, obj.ResourceOwner, 'Unset', false);
                        configurePinResource(parentObj, scl, obj.ResourceOwner, 'Unset', false);
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
            warning(originalState.state, 'MATLAB:class:DestructorError');
        end
    end

    %% Public methods
    methods (Access = public)
        function servoObj = servo(obj, motornum)
        %   Attach a servo motor to the specified port on MKR or Nano Motor Carrier
        %
        %   [SERVOOBJ] = servo(mCObj, MOTORNUM) Creates a servo motor
        %   object connected to the specified port on the MKR or Nano motor carrier
        %
        %   Example:
        %       % Construct an arduino object
        %       a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
        %
        %       % Construct MotorCarrier object
        %       mCObj = motorCarrier(a);
        %
        %       % Construct servo motor object
        %       s = servo(mCObj,1);
        %
        %   See also dcmotor, pidMotor, rotaryEncoder

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'MotorCarrier_servo'));
            try
                servoObj = arduinoio.motorcarrier.Servo(obj, motornum);
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function dcmotorObj = dcmotor(obj, motornum, varargin)
        %   Attach a DC motor to the specified port on MKR or Nano Motor Carrier
        %
        %   Syntax:
        %   [DCMOBJ] = dcmotor(mCObj, MOTORNUM) Creates a dcmotor motor object connected to the specified port on the MKR motor carrier
        %   [DCMOBJ] = dcmotor(mCObj, MOTORNUM, 'NAME', 'VALUE') Creates a dcmotor motor object with additional options specified by one or more Name-Value pair arguments
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
        %       % Construct dcmotor object with initial Speed 0.2
        %       dcm = dcmotor(mCObj,'M1','Speed',0.2);
        %
        %   See also servo, pidMotor, rotaryEncoder

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'MotorCarrier_dcmotor',varargin{:}));
            try
                dcmotorObj = arduinoio.motorcarrier.DCMotor(obj, motornum, varargin{:});
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function rotaryEncoderObj = rotaryEncoder(obj, channel, varargin)
        %   Attach a rotary encoder to the specified channel on MKR or Nano Motor Carrier
        %
        %   Syntax:
        %   [ROTARYENCODEROBJ] = rotaryEncoder(mCObj, CHANNEL) Creates a rotary encoder
        %   object connected to the specified channel on the MKR or Nano motor carrier
        %
        %   [ROTARYENCODEROBJ] = rotaryEncoder(mCObj, CHANNEL, PULSESPERREVOLUTION) Creates a rotary encoder
        %   object with additional options specified
        %
        %   Example:
        %       % Construct an arduino object
        %       a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
        %
        %       % Construct MotorCarrier object
        %       mCObj = motorCarrier(a);
        %
        %       % Construct rotary encoder object at channel  1
        %       en1 = rotaryEncoder(mCObj, 1);
        %
        %       % Construct rotary encoder object at channel 1 with pulses per revolution 10
        %       en1 = rotaryEncoder(mCObj, 1, 10);
        %
        %   See also servo, dcmotor, pidMotor

        % This is needed for integrating ppr parameter
            if nargin> 2
                dppr = 'true';
            else
                dppr = 'false';
            end

            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'MotorCarrier_rotaryEncoder',dppr));
            try
                rotaryEncoderObj = arduinoio.motorcarrier.RotaryEncoder(obj, channel, varargin{:});
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function PIDObj = pidMotor(obj,pidNumber,varargin)
        %   Attach a PID motor to the specified port on MKR or Nano Motor Carrier
        %
        %   Syntax:
        %   [PIDM] = pidMotor(mCObj, MOTORNUM) Creates a pid motor
        %   object connected to the specified port on the MKR motor
        %   carrier in Speed control mode
        %
        %   [PIDM] = pidmotor(mCObj, MOTORNUM, CONTROLMODE,
        %   PULSESPERREVOLUTION,PIDGAINS) Creates a pid motor object
        %   with additional options specified
        %
        %   Example:
        %       % Construct an arduino object
        %       a = arduino('COM7', 'Nano33IoT', 'Libraries', 'MotorCarrier');
        %
        %       % Construct MotorCarrier object
        %       mCObj = motorCarrier(a);
        %
        %       % Construct pidMotor object
        %       pid = pidMotor(mCObj, 1);
        %
        %       % Construct pidMotor object with control mode position
        %       pid = pidMotor(mCObj, 1, 'Position');
        %
        %       % Construct pidMotor object  with control mode speed, pulses per revolution 10 and Kp, Ki, Kd 200, 20, 1
        %       respectively
        %       pid = pidMotor(mCObj, 1, 'Speed', 10, [200,20,1]);
        %
        %   See also servo, dcmotor, rotaryEncoder

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'MotorCarrier_pidMotor', varargin{:}));

            try
                PIDObj = arduinoio.motorcarrier.PIDMotor(obj, pidNumber, varargin{:});
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

    end

    methods (Access = private)
        function createMotorCarrier(obj)
            commandID = obj.CREATE_MOTOR_CARRIER;
            data = uint8(obj.I2CAddress);
            sendCommandCustom(obj, obj.LibraryName, commandID, data);
        end

        function deleteMotorCarrier(obj)
            commandID = obj.DELETE_MOTOR_CARRIER;
            params = [];
            sendCommandCustom(obj, obj.LibraryName, commandID, params);
        end
    end

    methods (Access = {?arduinoio.motorcarrier.Servo, ...
                       ?arduinoio.motorcarrier.DCMotorBase, ...
                       ?arduinoio.motorcarrier.PIDMotor,...
                       ?arduinoio.motorcarrier.RotaryEncoder})
        function output = sendCarrierCommand(obj, commandID, inputs, timeout)
            switch nargin
              case 3
                output = sendCommandCustom(obj, obj.LibraryName, commandID, inputs);
              case 4
                output = sendCommandCustom(obj, obj.LibraryName, commandID, inputs, timeout);
              otherwise
            end
        end
    end

    methods(Access = private)
        function configureI2C(obj)
            parentObj = obj.Parent;
            I2CTerminals = parentObj.getI2CTerminals();
            sda = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+1));
            sda = sda{1};
            [~, ~, pinMode, pinResourceOwner] = getPinInfoHook(obj.Parent, sda);
            % Proceed only if the I2C pins are Unset or
            % configured to I2C
            if (strcmp(pinMode, 'I2C') || strcmp(pinMode, 'Unset')) && strcmp(pinResourceOwner, '')
                % Take the ownership from arduino if it is
                % the resourceowner. If not, proceed with
                % configuration.
                configurePinInternal(obj.Parent, sda, 'Unset', 'arduinoio.motorcarrier.MotorCarrier');
            end
            configurePinInternal(obj.Parent, sda, 'I2C', 'arduinoio.motorcarrier.MotorCarrier', obj.ResourceOwner);
            scl = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+2));
            scl = scl{1};
            [~, ~, pinMode, pinResourceOwner] = getPinInfoHook(obj.Parent, scl);
            % Proceed only if the I2C pins are Unset or
            % configured to I2C
            if (strcmp(pinMode, 'I2C') || strcmp(pinMode, 'Unset')) && strcmp(pinResourceOwner, '')
                % Take the ownership from arduino if it is
                % the resourceowner. If not, proceed with
                % configuration.
                configurePinInternal(obj.Parent, scl, 'Unset', 'arduinoio.motorcarrier.MotorCarrier');
            end
            configurePinInternal(obj.Parent, scl, 'I2C', 'arduinoio.motorcarrier.MotorCarrier', obj.ResourceOwner);
            obj.SCLPin = scl;
            obj.SDAPin = sda;
        end
    end

    methods(Access = protected)
        function output = sendCommandCustom(obj, libName, commandID, inputs, timeout)
            if nargin > 4
                [output, ~] = sendCommand(obj, libName, commandID, inputs, timeout);
            else
                [output, ~] = sendCommand(obj, libName, commandID, inputs);
            end
        end

        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);

            % Display main options
            fprintf('          SCLPin: ''%s''\n', obj.SCLPin);
            fprintf('          SDAPin: ''%s''\n', obj.SDAPin);
            fprintf('      I2CAddress: %-1d (''0x%02s'')\n', obj.I2CAddress, dec2hex(obj.I2CAddress));
            fprintf('\n');

            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end
