classdef (Sealed) arduino < matlabshared.hwsdk.controller &...
        matlabshared.dio.controller &...
        matlabshared.i2c.controller &...
        matlabshared.serial.controller &...
        matlabshared.addon.controller &...
        matlabshared.adc.controller &...
        matlabshared.pwm.controller &...
        matlabshared.spi.controller & ...
        matlabshared.can.Node & ...
        matlabshared.sensors.MultiStreamingUtilities &....
        matlabshared.sensors.GPSUtilities &...
        arduinoio.internal.ArduinoDataUtilityHelper &...
        matlabshared.hwsdk.ForegroundAcquisitionUtility
        
%arduino Connect to an ArduinoÂ®.
%
%   Syntax:
%       [ARDUINOOBBJ] = arduino                               Creates a serial connection to an Arduino hardware.
%       [ARDUINOOBBJ] = arduino(PORT)                         Creates a serial connection to an Arduino hardware on the specified port.
%       [ARDUINOOBBJ] = arduino(PORT,BOARD,NAME,VALUE)        Creates a serial connection to the Arduino hardware on the specified port and board with additional Name-Value options.
%       [ARDUINOOBBJ] = arduino(IPADDRESS,BOARD)              Creates a WiFi connection to the Arduino hardware at the specified IP address.
%       [ARDUINOOBBJ] = arduino(IPADDRESS,BOARD,TCPIPPORT)    Creates a WiFi connection to the Arduino hardware at the specified IP address and TCP/IP remote port.
%       [ARDUINOOBBJ] = arduino(BTADDRESS,BOARD)              Creates a Bluetooth connection to the Arduino hardware at the specified device address.
%
%   Example:
%      % Connect to an Arduino Uno board on COM port 3 on Windows:
%      a = arduino('com3','uno');
%
%      % Connect to an Arduino Uno board on a serial port on Mac:
%      a = arduino('/dev/tty.usbmodem1421');
%
%      % Connect to an Arduino board and include only I2C library instead of default libraries set (I2C, SPI and Servo)
%      a = arduino('com3','uno','libraries','I2C');
%
%      % Connect to an Arduino Uno board on COM port 3 and 'ForceBuildOn' value true to upload a new server with the specified configuration
%      on the hardware irrespective of the configuration of server present on hardware
%      a = arduino('com3','uno','ForceBuildOn',true);
%
%      % Connect to an Arduino Uno board on COM port 3 and 'TraceOn' value true to display debug trace for commands executed on MATLAB command prompt
%      a = arduino('com9','uno','TraceOn',true);
%
%      % Connect to an Arduino Uno board on COM port 3 and BaudRate 115200 bits per second
%      a = arduino('com3','uno','BaudRate',115200);
%
%      % Connect to an Arduino MKR1000 board at IP address 172.32.45.121
%      a = arduino('172.32.45.121','mkr1000');
%
%      % Connect to an Arduino MKR1000 board at IP address 172.32.45.121 and TCP/IP remote port 8000
%      a = arduino('172.32.45.121','mkr1000',8000);
%
%      % Connect to an Arduino Uno board at device address btspp://98d331fc3af3
%      a = arduino('btspp://98d331fc3af3');
%
%   See also arduinosetup, listArduinoLibraries, writeDigitalPin,
%   readDigitalPin, readVoltage, writePWMVoltage, writePWMDutyCycle,
%   device, addon, motorCarrier, canChannel, apds9960

%   Copyright 2017-2024 The MathWorks, Inc.

%% Properties
% PWMVoltageMax not officially supported, but may be needed for correct PWM
% calculations.
    properties(Hidden)
        PWMVoltageMax
    end

    properties(SetAccess = private, GetAccess = {?matlabshared.hwsdk.internal.base,?matlabshared.hwsdk.controller})
        ResourceManager
    end

    properties(SetAccess = private,GetAccess=public)
        AnalogReference;
        AnalogReferenceMode;
    end

    properties(Access = private)
        Utility
        ResourceOwner
        TonePin = '';
    end

    properties(SetAccess = private, Hidden, GetAccess = {?matlabshared.hwsdk.controller})
        CheckSumEnable = 0;
    end

    properties(Access = private, Constant = true)
        % major release/minor release - 19aMarch
        LibVersion = arduinoio.internal.ArduinoConstants.LibVersion;
    end

    properties(Access = private, Constant = true)
        ArduinoResourceOwner = ''
        % I2C properties
        I2CBitRate = [100000 400000];       % I2C BitRate Range for Arduino 100kHz to 400kHz
                                            % Tone Properties
        DefaultPlayToneFrequency = 1000;    % Hz
        DefaultPlayToneDuration = 1;        % s
        ToneResourceOwner = 'Tone'
        PLAYTONE    = hex2dec('F110')       % Request ID for playTone
    end

    properties(Hidden,Access = ?arduinoio.internal.ArduinoDataUtilityParser)
        % Board name and conection type for data integration
        dBoardConnectionType
    end

    methods (Access = private, Static = true)
        function name = matlabCodegenRedirect(~)
            name = 'coder.arduino';
        end
    end


    %% CTOR/DTOR
    methods(Access = public, Hidden)
        function obj = arduino(varargin)

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj,varargin{:}));

            try
                narginchk(0,14);
                initUtility(obj);
                obj.CheckSumEnable = 1;
                obj.IsDebugObjectRequired = 1;
                if isdeployed()
                    % Dynamic property ArduinoCLIPath
                    p = addprop(obj, 'ArduinoCLIPath');
                    p.Access = 'private';
                    % fetchConfigurationDetailsFromInputs is used to
                    % eliminate UI. Only for testing purposes.
                    % arduino(<port>, <board>, 'ArduinoCLIPath', <loc>)
                    % eliminates UI from appearing.
                    arduinoCLIPath = fetchConfigurationDetailsFromInputs(obj, varargin{:});
                    if isempty(arduinoCLIPath)
                        [port, board, arduinoCLIPath] = fetchConfigurationDetailsFromUser(obj, varargin);
                        varargin{1} = port;
                        varargin{2} = board;
                        varargin{end+1} = 'ArduinoCLIPath';
                        varargin{end+1} = arduinoCLIPath;
                    end
                end
                obj.initHardware(varargin{:});
                switch obj.ConnectionType
                  case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                    obj.dBoardConnectionType = [obj.Board '_USB'];
                  case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                    obj.dBoardConnectionType = [obj.Board '_Bluetooth'];
                  case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                    obj.dBoardConnectionType = [obj.Board '_WiFi'];
                  case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                    obj.dBoardConnectionType = [obj.Board '_BLE'];
                end
                % All IO Client calls will be made through this object.
                obj.DigitalIODriverObj = arduinodriver.ArduinoDigitalIO;
                storeBoardConnection(obj.ConnectionController, obj, obj.Board);
            catch e
                 obj.throwCustomErrorHook(e);
            end
        end
    end

    methods(Access = public)
        function servoObj = servo(obj, pin, varargin)
        %   Attach a servo motor to specified pin on hardware.
        %
        %   Syntax:
        %   s = servo(a,pin)
        %   s = servo(a,pin,Name,Value)
        %
        %   Description:
        %   s = servo(a,pin)            Creates a servo motor object connected to the specified pin on hardware.
        %   s = servo(a,pin,Name,Value) Creates a servo motor object with additional options specified by one or more Name-Value pair arguments.
        %
        %   Example:
        %       a = arduino();
        %       s = servo(a,'D3');
        %
        %   Example:
        %       a = arduino();
        %       s = servo(a,'D3','MinPulseDuration',1e-3,'MaxPulseDuration',2e-3);
        %
        %   Input Arguments:
        %   a   - Arduino
        %   pin - Digital pin number (character vector or string)
        %
        %   Name-Value Pair Input Arguments:
        %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value.
        %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
        %
        %   NV Pair:
        %   'MinPulseDuration' - The pulse duration for the servo at its minimum position (numeric,
        %                     default 5.44e-4 seconds.
        %   'MaxPulseDuration' - The pulse duration for the servo at its maximum position (numeric,
        %                     default 2.4e-3 seconds.
        %
        %   See also device, addon

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj,'Servo',varargin{:}));
            try
                if(any(ismember(obj.Libraries, 'Servo')))
                    servoObj = arduinoio.Servo(obj, pin, varargin{:});
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'Servo');
                end
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end

        function playTone(obj, pin, varargin)
        %   Play a tone on piezo speaker
        %
        %   Syntax:
        %   playTone(a,pin)                    Plays a 1000Hz, 1s tone on a piezo speaker attached to
        %                                      the Arduino hardware at a specified pin.
        %   playTone(a,pin,frequency)          Plays a 1s tone at specified frequency.
        %   playTone(a,pin,frequency,duration) Plays a tone at specified frequency and duration.
        %
        %   Example:
        %   Play a tone connected to pin 5 on the Arduino for 30 seconds at 2400Hz.
        %       a = arduino();
        %       playTone(a,'D5',2400,30);
        %
        %   Example:
        %   Stop playing tone.
        %       a = arduino();
        %       playTone(a,'D5',0,0);
        %
        %   Input Arguments:
        %   a         - Arduino
        %   pin       - Digital pin number (character vector or string)
        %   frequency - Frequency of tone (numeric, 0 - 32767Hz)
        %   duration  - Duration of tone to be played (numeric, 0 - 60s)

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj,varargin{:}));

            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end

                if nargin > 4
                    obj.localizedError('MATLAB:maxrhs');
                end

                % Arduino tone() not supported on SAM and xtensa architectures
                if ismember(obj.getMCU(),{'cortex-m3','esp32'})
                    obj.localizedError('MATLAB:hwsdk:general:toneUnsupportedOnSAM', obj.Board);
                end

                % Retrieve frequency and duration from input arguments
                p = inputParser;
                addOptional(p, 'Frequency', obj.DefaultPlayToneFrequency, @isnumeric);
                addOptional(p, 'Duration', obj.DefaultPlayToneDuration, @isnumeric);
                parse(p, varargin{:});
                frequency = p.Results.Frequency;
                duration = p.Results.Duration;

                % Validate pin, frequency and duration
                tonePin = validateDigitalPin(obj, pin);
                if ~isempty(obj.TonePin) && ~strcmp(obj.TonePin, tonePin)
                    obj.localizedError('MATLAB:hwsdk:general:toneLibraryUnavailable', obj.Board, char(obj.TonePin), char(pin));
                end
                frequency = matlabshared.hwsdk.internal.validateDoubleParameterRanged('tone frequency', frequency, 0, 32767, 'Hz');
                duration = matlabshared.hwsdk.internal.validateDoubleParameterRanged('tone duration', duration, 0, 60, 's');

                % Reserve pins 3 & 11 on boards other than Mega, SAMD and
                % MBED
                % A special resource owner is required because extra pins
                % have to be reserved.
                if ~ismember(obj.Board, {'Mega2560','MegaADK','Nano33BLE','MKR1000','MKR1010','Nano33IoT','MKRZero'})
                    for i = 1:numel(obj.ResourceManager.NonMegaReservedTonePins)
                        [~, ~, resPWMTerminalMode, resPWMTerminalOwner] = getPinInfo(obj.ResourceManager, obj, obj.ResourceManager.NonMegaReservedTonePins{i});
                        if ~strcmp(resPWMTerminalOwner, 'Tone') && ...
                                ~strcmp(tonePin, obj.ResourceManager.NonMegaReservedTonePins{i})
                            switch resPWMTerminalMode
                              case {'Unset', 'Tone'}
                                % Take resource ownership from Arduino object
                                configurePinResource(obj, obj.ResourceManager.NonMegaReservedTonePins{i}, obj.ArduinoResourceOwner, 'Unset');
                                configurePinResource(obj, obj.ResourceManager.NonMegaReservedTonePins{i}, obj.ToneResourceOwner, 'Reserved', true);
                              otherwise
                                % This pin 'to be reserved' is already
                                % being used by some other mode.
                                % Tone would modify this pin config. So
                                % cannot use Tone library. Hence revert
                                % reservation of rest of the pins.
                                if i > 1
                                    for j = 1:i-1
                                        configurePinResource(obj, obj.ResourceManager.NonMegaReservedTonePins{j}, obj.ToneResourceOwner, 'Unset');
                                    end
                                end
                                obj.localizedError('MATLAB:hwsdk:general:reservedTonePins', ...
                                                   obj.Board, obj.ResourceManager.NonMegaReservedTonePins{i});
                            end
                        end
                    end
                end

                % Configure pin to Tone mode.
                [~, ~, toneTerminalMode, toneResourceOwner] = getPinInfo(obj.ResourceManager, obj, tonePin);
                if (strcmp(toneTerminalMode, 'Tone') && strcmp(toneResourceOwner, obj.ArduinoResourceOwner))
                    % This happens when user manually configures the mode
                    % or when the pin was used for Tone already. Keep using
                    % it.
                elseif (strcmp(toneTerminalMode, 'Reserved') && ~strcmp(toneResourceOwner, obj.ToneResourceOwner))
                    % Some other resource has reserved this pin
                    obj.localizedError('MATLAB:hwsdk:general:resourceReserved', char(obj.Board), char(tonePin), toneResourceOwner);
                elseif ismember(toneTerminalMode, {'Unset', 'PWM', 'DigitalOutput'}) ...
                        || (strcmp(toneTerminalMode, 'Reserved') && strcmp(toneResourceOwner, obj.ToneResourceOwner))
                    % Pin was reserved by Tone. The same pin can be used
                    % for Tone. However now the resource owner should be
                    % Unset so that Arduino can take the ownership

                    % Tone can take over DigitalOutput and PWM
                    configurePinResource(obj, tonePin, toneResourceOwner, 'Unset');
                    configurePinResource(obj, tonePin, obj.ArduinoResourceOwner, 'Tone', false);
                else
                    if  ~ismember(obj.Board, {'Mega2560','MegaADK','Nano33BLE','MKR1000','MKR1010','MKRZero','Nano33IoT'})
                        % Unreserve D3 and D11 reserved by Tone
                        for i = 1:numel(obj.ResourceManager.NonMegaReservedTonePins)
                            configurePinResource(obj, obj.ResourceManager.NonMegaReservedTonePins{i}, obj.ToneResourceOwner, 'Unset');
                        end
                    end
                    obj.localizedError('MATLAB:hwsdk:general:reservedPin', ...
                                       char(tonePin), toneTerminalMode, 'Tone');
                end

                % Issue the command to hardware to play the tone
                peripheralPayload = [obj.getTerminalsFromPins(tonePin), typecast(uint16(round(frequency)), 'uint8'), typecast(uint16(round(duration*1000)), 'uint8')];
                rawWrite(obj.Protocol, obj.PLAYTONE, peripheralPayload);
                obj.TonePin = tonePin;
            catch e
                switch e.identifier
                  case 'MATLAB:InputParser:ArgumentFailedValidation'
                    % parse throws when string is input for expected
                    % numeric properties
                    mes = e.message;
                    index = strfind(mes, '''');
                    str = mes(index(1)+1:index(2)-1);
                    switch str
                      case 'Frequency'
                        property = 'tone frequency';
                        maxLimit = num2str(32767);
                        unit = 'Hz';
                      case 'Duration'
                        property = 'tone duration';
                        maxLimit = num2str(60);
                        unit = 'seconds';
                      otherwise
                    end
                    m = message('MATLAB:hwsdk:general:invalidDoubleTypeRangedUnits', property, num2str(0), maxLimit, unit);
                    e = MException('MATLAB:hwsdk:general:invalidDoubleTypeRangedUnits', m.getString());
                  otherwise
                end
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end

        function register = shiftRegister(obj, model, dataPin, clockPin, varargin)
        %   Attach the shift register with the specified pins on the Arduino hardware.
        %
        %   Syntax:
        %   register = shiftRegister(a,'74HC165', dataPin, clockPin, loadPin, clockEnablePin)
        %   register = shiftRegister(a,'74HC595', dataPin, clockPin, latchPin)
        %   register = shiftRegister(a,'74HC595', dataPin, clockPin, latchPin, resetPin)
        %   register = shiftRegister(a,'74HC164', dataPin, clockPin)
        %   register = shiftRegister(a,'74HC164', dataPin, clockPin, resetPin)
        %
        %   Description:
        %   register = shiftRegister(a,model,datapin,clockpin, ...)
        %
        %   Example:
        %       a = arduino();
        %       register = shiftRegister(a,'74hc595','D3','D4','D7');
        %
        %   Example:
        %       a = arduino();
        %       register = shiftRegister(a,'74hc165','D3','D4','D7','D8');
        %
        %   Example:
        %       a = arduino();
        %       register = shiftRegister(a,'74hc164','D3','D4','D7');
        %
        %   Input Arguments:
        %   a        - Arduino
        %   model    - Shift register model number (character vector or string)
        %   dataPin  - Serial data pin (character vector or string)
        %   clockPin - Shift register clock pin (character vector or string)
        %   latchPin - Storage register clock pin (character vector or string)
        %   loadPin  - Parallel load or shift control pin (character vector or string)
        %   clockEnablePin - Enable shift register clock pin (character vector or string)
        %   resetPin - Controller reset or clear pin (character vector or string)
        %
        %   See also device, servo, addon

        % This is needed for data integration for all input parameters
            dmodel = 'NA';
            ddataPin = 'NA';
            dclockPin = 'NA';
            if nargin==2
                dmodel = model;
            elseif nargin==3
                dmodel = model;
                ddataPin = dataPin;
            elseif nargin>3
                dmodel = model;
                ddataPin = dataPin;
                dclockPin = clockPin;
            end

            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj, dmodel, ddataPin, dclockPin,varargin{:}));

            try
                if(any(ismember(obj.Libraries, 'ShiftRegister')))
                    register = arduinoio.ShiftRegister(obj, model, dataPin, clockPin, varargin{:});
                else
                    id = 'MATLAB:hwsdk:general:libraryNotUploaded';
                    matlabshared.hwsdk.internal.localizedError(id,'ShiftRegister');
                end
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end

        function encoder = rotaryEncoder(obj, channelA, channelB, varargin)
        %   Attach the quadrature rotary encoder connected to the specified pins on the Arduino hardware.
        %
        %   Syntax:
        %   encoder = rotaryEncoder(a,channelA,channelB)
        %   encoder = rotaryEncoder(a,channelA,channelB,ppr)
        %
        %   Description:
        %   encoder = rotaryEncoder(a,channelA,channelB)            Connects to a rotary encoder.
        %   encoder = rotaryEncoder(a,channelA,channelB,ppr)        Connects to a rotary encoder with specified pulses per revolution.
        %
        %   Example:
        %       a = arduino();
        %       encoder = rotaryEncoder(a,'D2','D3');
        %
        %   Example:
        %       a = arduino();
        %       encoder = rotaryEncoder(a,'D2','D3',10);
        %
        %   Input Arguments:
        %   a         - Arduino
        %   ChannelA  - Arduino pin connected to channel A output of encoder (character vector or string)
        %   ChannelB  - Arduino pin connected to channel B output of encoder (character vector or string)
        %   PulsesPerRevolution - Number of pulses generated per rotation revolution (numeric, default []).
        %
        %   See also servo, shiftRegister, addon

        % This is needed for data integration
            if nargin> 3
                dppr = 'true';
            else
                dppr = 'false';
            end
            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj, 'RotaryEncoder',dppr));

            try
                if(~ismember(obj.Board,arduinoio.internal.ArduinoConstants.RotaryEncoderSupportedBoards))
                    obj.localizedError('MATLAB:hwsdk:general:notSupportedLibrary', 'RotaryEncoder', char(obj.Board));
                elseif(any(ismember(obj.Libraries, 'RotaryEncoder')))
                    encoder = arduinoio.RotaryEncoder(obj, channelA, channelB, varargin{:});
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'RotaryEncoder');
                end
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end

        function ultrasonicObj = ultrasonic(obj, triggerPin, varargin)
        %   Attach an Ultrasnic Sensor with Trigger and Echo pin.
        %
        %   Syntax:
        %   u = ultrasonic(a,triggerPin,echoPin)
        %   u = ultrasonic(a,signalPin)
        %
        %   Description:
        %   u = ultrasonic(a,triggerPin,echoPin)    % Connect a 4-Pin Ultrasonic sensor to arduino
        %   u = ultrasonic(a,signalPin)             % Connect a 3-Pin Ultrasonic Sensor to arduino
        %
        %   Example:
        %       a = arduino();
        %       u = ultrasonic(a,'D2','D3');
        %
        %   Example:
        %       a = arduino();
        %       u = ultrasonic(a,'D2');
        %
        %   Input Arguments:
        %   a   - Arduino
        %   triggerPin - Digital pin number (character vector or string)
        %   echoPin- Digital pin number (character vector or string)
        %
        %   See also servo, shiftRegister, rotaryEncoder

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj, 'Ultrasonic',varargin{:}));

            try
                if(any(ismember(obj.Libraries, 'Ultrasonic')))
                    ultrasonicObj = arduinoio.Ultrasonic(obj, triggerPin, varargin{:});
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'Ultrasonic');
                end
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end

        function mcpcan = canChannel(obj, varargin)
        %canChannel    Provides access to CAN Network through a shield / chip
        %connected to Arduino Hardware
        %   ch = canChannel(a, "MKR CAN Shield") is a CAN Channel connected to
        %   Arduino object 'a' where MKR CAN Shield is acting as the CAN
        %   Device. Other values for device input are "Seeed Studio CAN-Bus
        %   Shield V2" and "Sparkfun CAN-Bus Shield"
        %
        %   ch = canChannel(a, "MCP2515", "D3", "D7") is a CAN Channel
        %   connected to Arduino object 'a' where MCP2515 based shields other
        %   than the ones specified above are being used as CAN Device. Specify
        %   the Chip Select Pin (D3) and Interrupt Pin (D7) sequentially.
        %
        %   ch = canChannel(a, "MCP2515", "D3", "D7", "OscillatorFrequency",
        %   10e6)" is a CAN Channel where a custom shield with a 10MHz
        %   Oscillator is used. Since it is different from default of 16MHz,
        %   this NV pair must be used to specify the right frequency.
        %
        %   ch = canChannel(a, "Sparkfun CAN-Bus Shield", "BusSpeed", 100e3) is
        %   a CAN Channel where the desired Bus Speed of the channel is 100KHz.
        %   The default value of BusSpeed is 500KHz.
        %
        %   See also read, write

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj, varargin{:}));

            try
                if(any(ismember(obj.Libraries, 'CAN')))
                    mcpcan = matlabshared.can.Channel(obj, varargin{:});
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'CAN');
                end
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end

        function apds9960Obj = apds9960(obj, varargin)
        %APDS9960   Establish communication with the APDS9960 sensor
        %
        %   [APDS9960OBJ] = apds9960(arduinoObj) returns apds9960 object connected to the Arduino hardware
        %
        %   % Construct an arduino object
        %   a = arduino('COM4', 'Nano33BLE', 'Libraries', 'APDS9960');
        %
        %   % Construct apds9960 object
        %   apds9960Obj = apds9960(a);
        %   apds9960Obj = apds9960(a, 'Bus', 1);
        %   apds9960Obj = apds9960(a, 'BitRate', 100000);
        %   apds9960Obj = apds9960(a, 'Bus', 1, 'BitRate', 100000);
        %
        %   See also readGesture, readProximity, readColor

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj, 'APDS9960', varargin{:}));

            try
                if(any(ismember(obj.Libraries,'APDS9960')))
                    apds9960Obj = arduinoio.sensors.apds9960.APDS9960(obj, varargin{:});
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'APDS9960');
                end
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end

        function mCObj = motorCarrier(obj)
        %   Attach MotorCarrier shield to Arduino hardware
        %
        %   Syntax:
        %   [MCOBJ] = motorCarrier(arduinoObj) returns motorCarrier object connected to the Arduino hardware
        %
        %   Example:
        %       % Construct an arduino object
        %       a = arduino('COM11','Nano33IoT','libraries','MotorCarrier');
        %
        %       % Construct MotorCarrier object
        %       mCObj = motorCarrier(a);
        %
        %   See also dcmotor, servo, pidMotor, rotaryEncoder

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj));

            try
                if(any(ismember(obj.Libraries,'MotorCarrier')))
                    mCObj = arduinoio.motorcarrier.MotorCarrier(obj);
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'MotorCarrier');
                end
            catch e
                integrateErrorKey(obj, e.identifier);
                throwAsCaller(e);
            end
        end
    end

    methods (Access=protected)
        function delete(obj)
        % User delete of Arduino objects is disabled. Use clear
        % instead.
            if ~isempty(obj.Protocol) % Delete the connection object arduino creates
                if obj.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial %TODO
                    try
                        obj.StreamingObjects = {};
                        obj.DigitalIODriverObj.delete(obj.Protocol);
                    catch
                        % not error out
                    end
                end
                delete(obj.Protocol)
                clear obj.Protocol;
                discardBoardStorage(obj.ConnectionController, obj);
            end
        end
    end

    %% GPS utilities

    methods(Access = protected)

        function getBoardSpecificPropertiesGPSImpl(obj,callingObj,serialPort)
            if ismember(obj.Board,{'Mega2560','MegaADK'})
                try
                    validateattributes(serialPort, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:unSupportedSerialPortGPS',num2str(serialPort),'Mega');
                end
                if(double(serialPort) >= 3)
                    obj.localizedError('MATLAB:arduinoio:general:unSupportedSerialPortGPS',num2str(serialPort),'Mega');
                end
            end
            if ismember(obj.Board, {'MKR1000','MKR1010','MKRZero','Nano33IoT','Nano33BLE'})
                callingObj.TargetSerialBufferSize = 256;
            elseif strcmpi(obj.Board, 'Due')
                callingObj.TargetSerialBufferSize = 128;
            else
                callingObj.TargetSerialBufferSize = 64;
            end
        end
    end

    %% hwsdk.controller
    methods(Access = protected)

        function name = getHarwdareNameImpl(~)
            name = "Arduino";
        end

        function baseCode = getSPPKGBaseCodeImpl(~)
            baseCode = "ML_ARDUINO";
        end

        function pins = getAvailablePinsImpl(obj)
            tAnalog = [];
            tDigital = [];
            if isa(obj, 'matlabshared.adc.controller')
                tAnalog = obj.ResourceManager.TerminalsAnalog;
            end
            if isa(obj, 'matlabshared.dio.controller')
                tDigital = obj.ResourceManager.TerminalsDigital;
            end

            pins = obj.getPinsFromTerminals([tDigital, tAnalog]);
        end

        function paramNames = getCustomInputParameterNamesHook(~)
            paramNames = "Board";
        end

        function customParams = parseCustomInputParamsHook(obj, customParams)
            if ~ischar(customParams.Board) && ~isstring(customParams.Board)
                obj.localizedError('MATLAB:arduinoio:general:invalidBoardType');
            end
            %             customParams.Board = string(customParams.Board);
        end

        function customParams = validateCustomInputParamsHook(obj, customParams, prefs)
        % Only given address:
        % Regardless of preference exists or not, always auto-detect based on port if serial communication type
        % If last preference exists, reuse last preference if type and address are the same for wireless
        % If last preference exists but type or address are different, error for wireless
        % If no last preference, error for wireless
            if isempty(customParams.Board)
                if obj.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                    % Attempt to auto-detect with port
                    port = obj.Args.Address;
                    % TODO The RemoteUtilities does not support MATLAB
                    % compiler deployment yet, need to remove the %#exclude
                    % below and isdeployed once g3238819 is resolved
                    %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
                    if isunix && ~ismac && (isdeployed || ~matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW)
                        % Only resolve the symbolic link on Linux for
                        % MATLAB desktop. For MATLAB Online, pseudo terminal
                        % is used at the worker. The port user provides is
                        % on the machine runs MATLAB Connector instead of
                        % the MATLAB Online worker (where the system
                        % command runs on)
                        [~, origPort] = system(['readlink ', port]);
                        if ~isempty(origPort)
                            port = ['/dev/',strtrim(origPort)];
                        end
                    end
                    % Workaround for g1452757 to allow user specify tty port
                    % for auto-detection since the HW connection API only
                    % detect cu port.
                    if ismac
                        port = strrep(port, 'tty', 'cu');
                    end
                    if ~isempty(prefs)
                        customParams.Board = prefs.CustomParams.Board; % Scan below may override.
                    end
                    b = arduinoio.internal.BoardInfo.getInstance();
                    usbdev = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
                    [foundPorts, devinfo] = getSerialPorts(usbdev);
                    iPort = find(port == string(foundPorts));
                    foundFlag = false;
                    if ~isempty(iPort)
                        vid = devinfo(iPort).VendorID;
                        pid = devinfo(iPort).ProductID;
                        % Loop through all boards in boardInfo to find matching vid/pid pair
                        for bCount = 1:numel(b.Boards)
                            if foundFlag
                                break;
                            end
                            theVIDPID = b.Boards(bCount).VIDPID;
                            if ~isempty(theVIDPID)
                                for index = 1:numel(theVIDPID)
                                    testVIDPID = "0x" + vid + "_" + "0x" + pid;
                                    if strcmpi(testVIDPID, string(theVIDPID{index}))
                                        customParams.Board = b.Boards(bCount).Name;
                                        foundFlag = true;
                                        break;
                                    end
                                end
                            end
                        end
                    end
                    if ~foundFlag  % No Arduino board is found at the given port
                        obj.localizedError('MATLAB:hwsdk:general:invalidPort', char(obj.getHarwdareNameImpl), port);
                    end
                else
                    if ~isempty(prefs) && ...
                            obj.ConnectionType == prefs.ConnectionType && ...
                            strcmpi(obj.Args.Address, prefs.Address)
                        % Reuse last preference board for wireless
                        customParams.Board = prefs.CustomParams.Board;
                    else
                        if (obj.ConnectionType ~= matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE && obj.ConnectionType ~= matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth)
                            % No last preference, assume first-time use and error for configure
                            obj.localizedError('MATLAB:arduinoio:general:firstTimeSetup');
                        end
                    end
                end
            end
            p = addprop(obj, 'Board');
            obj.Board = customParams.Board;
            p.SetAccess = 'private';
        end

        function [isValid, boardName] = validateSerialDeviceHook(obj, vid, pid)
            isValid = false;
            b = arduinoio.internal.BoardInfo.getInstance();
            % Loop through all boards in boardInfo to find matching vid/pid pair
            for bCount = 1:numel(b.Boards)
                theVIDPID = b.Boards(bCount).VIDPID;
                if ~isempty(theVIDPID)
                    for index = 1:numel(theVIDPID)
                        testVIDPID = "0x" + vid + "_" + "0x" + pid;
                        if strcmpi(testVIDPID, string(theVIDPID{index}))
                            isValid = true;
                            boardName = b.Boards(bCount).Name;
                            break;
                        end
                    end
                end
            end
            if ~isValid
                obj.localizedError('MATLAB:hwsdk:general:boardNotDetected', char(obj.getHarwdareNameImpl));
            end
        end

        function baudRate = getBaudRateHook(obj)
        % All 3.3V 8MHz boards except for MKR1000 use baud rate 57600bps due to reports of them not being able to reliably support 115200bps.
        % 1. http://forum.arduino.cc/index.php?topic=54623.0
        % 2. https://forum.mysensors.org/topic/1483/trouble-with-115200-baud-on-3-3v-8mhz-arduino-like-serial-gateway-solution-change-baudrate/2
        % 3. http://www.avrfreaks.net/forum/modifying-arduino-nano-v30-crystal-speed
        % All other boards use baud rate 115200bps
            if any(ismember(obj.Board,arduinoio.internal.ArduinoConstants.BaudRateLowBoards))
                baudRate = 57600;
            else
                baudRate = getDefaultBaudRate(obj);
            end
        end

        function modes = getSupportedModesHook(obj)
            modes= unique([obj.ResourceManager.AnalogPinModes obj.ResourceManager.DigitalPinModes]);
        end

        function supportedTransports = getSupportedTransportsHook(~)
        % TODO The RemoteUtilities does not support MATLAB
        % compiler deployment yet, need to remove the %#exclude
        % below once g3238819 is resolved
        %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
            if (isdeployed || matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW) && ~ispref('MATLAB_HARDWARE','HostIOServerEnabled')
                % MATLAB Online and MATLAB Compiler only support Serial
                supportedTransports = matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial;
            else
                % MATLAB desktop (non-deploy mode) supports Serial, WiFi, BLE and Bluetooth
                % HostIOServer supports Serial, WiFi, BLE and Bluetooth in all modes
                supportedTransports = [matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial, ...
                                       matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi, ...
                                       matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE, ...
                                       matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth];
            end
        end

        function val = getIOProtocolTimeoutHook(~)
            val = 10;
        end

        function delayValue = getResetDelayHook(obj)
        % workaround for Arduino Mega on Linux taking longer time to reset, explained in g1638539
            if(obj.ConnectionType==matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial)
                if ispc || ismac
                    delayValue = 2;
                else
                    delayValue = 10;
                end
            else
                %The reset on the DTR line is via Serial only
                delayValue = 0;
            end
        end

        function updateServerImpl(obj)
        % Check if the user has seen the license screen for the
        % current version of support package before. If not, prompt the
        % user to run arduinosetup to review the licenses.
        % TODO The RemoteUtilities does not support MATLAB
        % compiler deployment yet, need to remove the %#exclude and
        % isdeployed condition below once g3238819 is resolved
        %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
            if ~isdeployed && matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
                % validateHWSetupComplete errors out if license setup
                % screen has not been shown with the current spkg version.
                try
                    matlabshared.remoteconnectivity.internal.RemoteUtilities.validateHWSetupComplete(obj.getSPPKGBaseCodeImpl());
                catch
                    obj.localizedError('MATLAB:arduinoio:general:NeedToReview3PLicenseScreen');
                end
            end

            if obj.ConnectionType ~= matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                hardwareName = getHarwdareNameImpl(obj);
                obj.localizedError('MATLAB:hwsdk:general:wlConnectionFailed', char(hardwareName), char(lower(hardwareName)));
            end

            buildInfo = getBuildInfo(obj.ResourceManager);
            buildInfo = obj.prepareBuildInfo(buildInfo);
            % Check if alternate library header files are available for the specified library and board.
            % alternateHeaderSearch is a logical array. A true value means the corresponding library
            % in the obj.Libraries cell array has an alternate library header asociated with it
            alternateHeaderSearch = areAlternateLibraryHeadersAvailableHook(obj, obj.Utility, buildInfo);
            buildInfo.AlternateLibraryHeadersAvailable = alternateHeaderSearch;
            updateServer(obj.Utility, buildInfo);
        end

        function status = validateServerInfoHook(obj, serverInfo)
            if (obj.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE || obj.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth && isempty(obj.Board))
                % For BLE and BT connection type if Board info not
                % available in preferences and user specified the address
                % for creating arduino object it is retreived from board
                % rather than erroring for the user
                obj.Board = serverInfo.BoardName;
            end
            status = strcmpi(serverInfo.BoardName, obj.Board) && validateServerAnalogReferenceInfo(obj,serverInfo);
        end

        function status = validateServerVersionHook(obj,serverInfo, HWSDKVersion)
        % check if Major release(19a) of arduino, HWSDK and IOServer match
            releaseIndex = strfind(obj.LibVersion,'.');
            statusRelease = strncmpi(obj.LibVersion,HWSDKVersion,releaseIndex(end)-1) && strncmpi(obj.LibVersion,serverInfo.ioServerVersion,releaseIndex(end)-1);
            % check if minor release version of Arduino >= HWSDK, IOServer minor release version
            % release (This allows monthly release for Arduino SPPKG without updating HWSDK and IOSERVER)
            statusMinorversion = str2double(extractAfter(obj.LibVersion,releaseIndex(end))) >= str2double(extractAfter(HWSDKVersion,releaseIndex(end))) && str2double(extractAfter(obj.LibVersion,releaseIndex(end))) >= str2double(extractAfter(serverInfo.ioServerVersion,releaseIndex(end)));
            status = statusRelease && statusMinorversion && strcmpi(obj.LibVersion,serverInfo.hwSPPKGVersion);
        end

        function    [flag,serverInfo] = getBuildOnlyServerInfoHook(obj)
        % Get server info for build-only test
            [flag,serverInfo] = arduino.test.tools.getServerInfo(obj);
        end

        function varargout = configurePinImpl(obj, pin, mode, varargin)
        % varargin{1} - caller
        % varargin{2} - resource owner associated with caller

            if nargin > 3
                try
                    validateCaller(obj, varargin{1});
                catch
                    obj.localizedError('MATLAB:TooManyInputs');
                end
            end
            if iscell(pin)
                pin = char(pin);
            end
            try
                pin = obj.validateDigitalPin(pin);
                if nargin == 2
                    % Reading pin configuration
                    varargout = {configurePinResource(obj, pin)};
                    return;
                else
                    % Writing pin configuration
                    resourceOwner = obj.ResourceOwner;
                    if nargin < 4
                        % call came from user through configurePin API.
                        configurePinResource(obj, pin, resourceOwner, mode, true);
                    else
                        % Call came internally from HWSDK
                        % Fetch resource owner
                        if nargin > 4
                            % resource owner associated with caller
                            resourceOwner = varargin{2};
                        end
                        % Configure pin resource
                        if strcmp(mode, 'Unset') || strcmp(resourceOwner, obj.ResourceOwner)
                            % GPIO (DIO, ADC, PWM) operations and Unset
                            if strcmp(varargin{1}, 'spi.device')
                                % SPI CS needs an override to DigitalOutput
                                % from SPI during destruction
                                spipins = obj.getAvailableSPIPins();
                                pins = {char(spipins.SCLPin) char(spipins.SDIPin) char(spipins.SDOPin)};
                                spiTerminals = obj.getSPITerminals();
                                if ~isempty(spiTerminals)
                                    csTerm = spiTerminals(end);
                                else
                                    csTerm = [];
                                end
                                % If pin is not part of spipins then it is
                                % CS. Apply the override when it is not
                                % part of spiterminals.
                                if ~contains(pin, pins) && ~isequal(getTerminalsFromPins(obj, pin), csTerm)
                                    overridePinResource(obj, pin, resourceOwner, 'DigitalOutput');
                                end
                            end
                            configurePinResource(obj, pin, resourceOwner, mode, false);
                            varargout{1} = [];
                        else
                            % peripherals with dedicated object
                            pinStatus = configurePinForPeripheralsWithDedicatedResourceOwner(obj, pin, mode, varargin{1}, resourceOwner);
                            varargout = {pinStatus};
                        end
                    end
                end
            catch e
                throwAsCaller(e);
            end
        end

        function pinNumber = getPinNumberImpl(obj, pin)
            try
                pinNumber = getTerminalsFromPins(obj, pin);
            catch e
                switch e.identifier
                  case 'MATLAB:hwsdk:general:invalidPinTypeString'
                    if any(contains(pin, {'spi', 'icsp'}, "IgnoreCase",true))
                        % Check if they are part of spi / icsp. Need to
                        % send a valid pin number.
                        pinNumber = 0;
                    else
                        throwAsCaller(e);
                    end
                  otherwise
                    throwAsCaller(e);
                end
            end
        end

        function debugObj = getDebugObjectHook(~)
            debugObj = arduinoio.internal.debugMessage;
        end

        function showFailedUploadErrorHook(obj)
            if obj.ConnectionType==matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                % Throw an upload failed error for Serial connection type
                if isdeployed()
                    obj.localizedError('MATLAB:hwsdk:general:failedUpload', char(obj.getBoardNameHook), obj.Port);
                else
                    obj.localizedError('MATLAB:arduinoio:general:failedUpload', char(obj.getBoardNameHook), obj.Port);
                end
            else
                % Throw a wireless connection failed error for WiFi and Bluetooth connection type
                obj.localizedError('MATLAB:hwsdk:general:wlConnectionFailed', 'Arduino', 'arduino');
            end
        end

        function serverTrace = getServerTraceInfoHook(~,CustomData)
            serverTrace = str2double(extractAfter(extractBefore(extractAfter(CustomData,','),','),'  '));
        end

        function availableAnalogPinsHook(obj)
        % See G2288652
        % 'Nano33IoT' is placed inside a cell array as the condition evaluates to true for matching board
        % names like 'Nano3' if the comparison is carried out with a character array
            if ismember(obj.Board, {'Nano33IoT','Nano33BLE'})
                obj.AvailableAnalogPins = setdiff(obj.AvailableAnalogPins, {'A4','A5'});
            end
        end

        function pinType = getPinTerminalTypeImpl(~)
            pinType = 'double';
        end

        function initHardwareHook(obj)
        % Resource Owner (Arduino = '')
            obj.ResourceOwner = obj.ArduinoResourceOwner;

            % Analog reference, for PWM scaling
            initResourceManager(obj, obj.Board);
            obj.Board = obj.ResourceManager.Board;
            %%
            if ismember(obj.Board, arduinoio.internal.ArduinoConstants.AREF3VBoards)
                obj.PWMVoltageMax = 3.3;
            else
                obj.PWMVoltageMax = 5.0;
            end

            if isa(obj, 'matlabshared.addon.controller')
                if ~obj.LibrariesSpecified && obj.ForceBuildOn
                    obj.Libraries = obj.getDefaultLibraries();
                else
                    obj.Libraries = obj.validateLibraries(obj.Libraries); % check existence and completeness of libraries
                    boardName = validateBoard(obj,obj.Board);
                    if ~ismember(boardName,arduinoio.internal.ArduinoConstants.SerialLibrarySupportBoards) && ismember('Serial', obj.Libraries)
                        obj.localizedError('MATLAB:hwsdk:general:notSupportedInterface', 'Serial', char(boardName));
                    elseif ~ismember(boardName,arduinoio.internal.ArduinoConstants.RotaryEncoderSupportedBoards) && ismember('RotaryEncoder',obj.Libraries)
                        obj.localizedError('MATLAB:hwsdk:general:notSupportedLibrary', 'RotaryEncoder', char(boardName));
                    elseif ismember('MotorCarrier',obj.Libraries) && ~ismember(obj.Board, arduinoio.internal.ArduinoConstants.MotorCarrierLibrarySupportedBoards)
                        obj.localizedError('MATLAB:arduinoio:general:unsupportedMCLibrary', char(boardName));
                    end
                end

                % Error out inclusion of both MotorCarrier or Arduino/MKRMotorCarrier libraries
                % in arduino constructor for MKR boards
                % NOTE: No need of a specific check on MKR board as other boards with these
                % libraries will be errored out early except addon Arduino/MKRMotorCarrier
                % library as it doesn't fall under SPPKG.
                % Since MKRMotorCarrier library has been removed from R2021b onward, the
                % libOptions do not contain it anymore (had it till R2021a)
                libOptions = {'MotorCarrier','Arduino/MKRMotorCarrier'};
                % Find out the indices of specified motor carrier libraries
                libIndex = double(ismember(libOptions, obj.Libraries));
                if nnz(libIndex) == 2
                    % If both of the libraries are specified, throw a
                    % conflictingLibrary error
                    libPrint = ['both ', libOptions{1}, ' and ', libOptions{2}];
                    obj.localizedError('MATLAB:arduinoio:general:conflictingLibrary', libPrint);
                end

                obj.LibraryIDs = 0:(numel(obj.Libraries)-1);
            end

            %% Validate and set AnalogReference and AnalogReferenceMode
            validateAnalogReference(obj);
        end

        function throwCustomErrorHook(obj,exception)
            % Hook to throw custom errors specific to arduino hardware
            errID = exception.identifier;
            isCustomError = strcmpi(errID,'transportclients:ioserverblock:writeFailed') || strcmpi(errID,'ioserver:general:UnableToReceiveData');
            if isCustomError
                errID = 'MATLAB:arduinoio:general:connectionIsLost';
            end

            % Integrate Error key
            integrateErrorKey(obj,errID);

            % Call appropriate error caller function
            if isCustomError
                throwAsCaller(MException(errID,getString(message(errID))));
            else
                throwAsCaller(exception);
            end
        end
    end
    %% dio controller
    methods(Access = protected)
        function availableDigitalPins = getAvailableDigitalPinsImpl(obj)
            tDigital = obj.ResourceManager.TerminalsDigital;
            tAnalog = obj.ResourceManager.TerminalsAnalog;
            if ismember(obj.Board, {'Nano3', 'ProMini328_5V', 'ProMini328_3V'})
                pin = 1;
                % Check if the pin supports any Digital Mode and add it to list
                while pin < numel(tAnalog)
                    try
                        validateTerminalSupportsTerminalMode(obj.ResourceManager, tAnalog(pin), 'DigitalOutput');
                        tDigital = [tDigital, tAnalog(pin)]; %#ok<AGROW>
                    catch
                        % Ignore the exception and continue further in the list
                    end
                    pin = pin + 1;
                end
            else
                tDigital = [tDigital, tAnalog];
            end
            availableDigitalPins = string(obj.getPinsFromTerminals(tDigital));
        end
    end

    %% adc controller
    methods(Access = protected)
        function availableAnalogPins = getAvailableAnalogInputVoltagePinsImpl(obj)
            tAnalog = [obj.ResourceManager.TerminalsAnalog, obj.ResourceManager.TerminalsDigitalAndAnalog];
            availableAnalogPins = string(obj.getPinsFromTerminals(tAnalog));
        end

        function referenceVoltage = getReferenceVoltageImpl(obj)
            referenceVoltage = obj.AnalogReference;
        end

        % Overriding getADCResolutionInBitsHook(obj) from
        % matlabshared.adc.controller
        % Changes the ADC resolution for ARM boards
        % Changes made to fix the geck g2027879
        function resolution = getADCResolutionInBitsHook(obj)
            if ismember(obj.Board, {'MKR1000','MKR1010','MKRZero','Due','Nano33IoT','Nano33BLE','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC','UnoR4Minima','UnoR4WiFi'})
                resolution = 12;
            else
                resolution = 10;
            end
        end

        function pinNumber = getADCPinNumberHook(obj, pin)
            if ismember(obj.Board, {'Leonardo', 'Micro', 'ESP32-WROOM-DevKitV1', 'ESP32-WROOM-DevKitC'})
                pinNumber = str2double(extractAfter(pin, 1));
            else
                pinNumber = getTerminalsFromPins(obj, pin);
            end
        end
        function voltage = sampleToVoltageConverterHook(obj,counts,resultDatatype)
            maxCount = power(2, getADCResolutionInBitsHook(obj)) - 1;
            normalizedVoltage = double(typecast(uint8(counts), char(resultDatatype))) / maxCount;
            voltage = normalizedVoltage * obj.AnalogReference;
        end   
        function recordingPreCheckHook(obj)
            % Using isStreaming flag from
            % matlabshared.sensors.MultiStreamingUtilities to detect
            % whether the sensor streaming is already in progress and not
            % allowing Users to use readVoltage with NV Pair when streaming
            % is in progress
            if(obj.isStreaming)
                error(message("MATLAB:arduinoio:general:SensorStreamingWithRecording"));
            end
            % Recording will not be supported with traceOn set to true
            if(obj.TraceOn)
                error(message("MATLAB:arduinoio:general:unSupportedCommandLogs","readVoltage"));
            end
        end
    end

    %% pwm.controller
    methods(Access = protected)
        function availablePWMPins = getAvailablePWMPinsImpl(obj)
            tPWM = obj.ResourceManager.TerminalsPWM;
            availablePWMPins = string(obj.getPinsFromTerminals(tPWM));
        end

        function voltageRange = getPWMVoltageRangeImpl(obj)
            voltageRange = [0 obj.PWMVoltageMax];
        end
    end

    %% i2c.controller
    methods(Access = protected)
        function i2cBitRates = getI2CBitRateLimitHook(obj, ~)
            i2cBitRates = obj.I2CBitRate;
        end

        function buses = getAvailableI2CBusIDsHook(obj)
            if strcmp(obj.getBoardNameHook, 'Due')
                buses = [0 1];
            else
                i2cPinsArray = obj.getAvailableI2CPins();
                buses = [];
                if numel(i2cPinsArray) > 0
                    buses = 0:numel(i2cPinsArray) - 1;
                end
            end
        end

        function addresses = scanI2CBusHook(obj, bus)
            values = scanI2CBus(obj.Protocol,bus);
            if 0 == values
                if ismember(obj.Board,{'Due','Nano33BLE'}) && (bus == 1)
                    obj.localizedError('MATLAB:hwsdk:general:scanI2CBusFailure', char(string(bus)), 'SDA1', 'SCL1');
                else
                    % Default bus is 0. Resource Manager is built to
                    % address 0 as default bus.
                    pinsI2C = obj.getI2CTerminals(bus);
                    sda = obj.getPinsFromTerminals(pinsI2C(1));
                    scl = obj.getPinsFromTerminals(pinsI2C(2));
                    obj.localizedError('MATLAB:hwsdk:general:scanI2CBusFailure', char(string(bus)), sda{1}, scl{1});
                end
            end
            numAddrsFound = numel(values);
            addresses = {};
            if numAddrsFound ~= 0 % devices found
                                  % Creating a cell array of address in hex.
                addresses = cellstr(strcat('0x', dec2hex(uint8(values))));
            end
        end

        function i2cPinsArray = getAvailableI2CPinsImpl(obj)
        % Gather for Bus0
            terminals = obj.getI2CTerminals();
            pins = getPinsFromTerminals(obj, terminals);
            % Gather for Bus1
            terminals1 = [];
            try
                terminals1 = obj.getI2CTerminals(1);
            catch e
                switch e.identifier
                  case 'MATLAB:arduinoio:general:invalidI2CBusNumber'
                    % No Bus 1 for this board
                  otherwise
                    throwAsCaller(e);
                end
            end
            i2cPinsArray = [];
            if ismember(obj.Board,{'Nano33BLE'})
                % For Nano33BLE, there are no real terminals but it has
                % some alternate values for Bus1. So fetch only for Bus0.
                % Fill up those values for Bus1
                i2cPinsArray(2).SDAPin = terminals1(1);
                i2cPinsArray(2).SCLPin = terminals1(2);
            elseif ~isempty(terminals1)
                % Get pins from Bus1 and concatente them.
                pins1 = getPinsFromTerminals(obj, terminals1);
                pins = [pins(:)', pins1(:)'];
            end
            if ~isempty(pins)
                for i = 2:2:numel(pins)
                    i2cPinsArray(i/2).SDAPin = string(pins(i-1)); %#ok<AGROW>
                    i2cPinsArray(i/2).SCLPin = string(pins(i)); %#ok<AGROW>
                end
            end
        end

        function validateAddressTypeHook(~, ~)
        % ValidateAddressTypeHook(obj, addresses)
        % Validates the datatype of I2C addresses output from
        % scanI2CBus.
        % In case of Arduino, scanI2CBusHook returns as a cell array. Hence
        % no definition here.
        end

        function maxI2CReadWriteBufferSize = getMaxI2CReadWriteBufferSizeHook(obj)
        % To maintain backward compatibility with legacy Arduino SPPKG
            if ismember(obj.Board, {'MKR1000','MKR1010', 'MKRZero','Nano33IoT','Nano33BLE','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                maxI2CReadWriteBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferI2CSAMDMBEDESP;
            else
                maxI2CReadWriteBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferI2CAVRSAM;
            end
        end

        function i2cDriverObj = getI2CDriverObjImpl(obj)
            if(isempty(obj.I2CDriverObj))
                obj.I2CDriverObj = arduinodriver.ArduinoI2C();
            end
            i2cDriverObj = obj.I2CDriverObj();
        end

        function maxSPIReadWriteBufferSize = getMaxSPIReadWriteBufferSizeHook(obj)
        % To maintain backward compatibility with legacy Arduino SPPKG
        % Same definition as getMaxI2CReadWriteBufferSizeHook()
            if ismember(obj.Board, {'Uno','Nano3','DigitalSandbox','ProMini328_3V'})
                maxSPIReadWriteBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferSize2KRAMBoards;
            else
                maxSPIReadWriteBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferSPIAllboards;
            end
        end

        function maxSerialBufferSize = getMaxSerialReadWriteBufferSizeHook(obj)
            if ismember(obj.Board, {'Uno','Nano3','DigitalSandbox','ProMini328_3V'})
                maxSerialBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferSize2KRAMBoards;
            elseif ismember(obj.Board,{'MKR1000','MKR1010', 'MKRZero','Nano33IoT'})
                maxSerialBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferSerialSAMD;
            elseif ismember(obj.Board,{'Due'})
                maxSerialBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferSerialSAM;
            elseif ismember(obj.Board,{'Nano33BLE','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                maxSerialBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferSerialMbedESP;
            else
                maxSerialBufferSize = arduinoio.internal.ArduinoConstants.MaxBufferSerialAVR;
            end
        end

        function type = getI2CBusTypeImpl(~)
            type = "numeric";
        end
    end

    %% spi.controller
    methods(Access = protected)
        function spiBitRates = getSPIBitRatesImpl(~, ~)
            spiBitRates = 4e6:-1:1;
        end

        function spiPinsArray = getAvailableSPIPinsImpl(obj)
            terminals = obj.getSPITerminals();
            pins = getPinsFromTerminals(obj, terminals);
            spiPinsArray = [];
            if isempty(pins)
                if strcmpi(obj.Board, 'Due')
                    pins = ["SPI-3" "SPI-1" "SPI-4"];
                elseif strcmpi(obj.Board,'Leonardo') ||  strcmpi(obj.Board,'Micro')
                    pins = ["ICSP-3" "ICSP-1" "ICSP-4"];
                end
            end
            if ~isempty(pins)
                if numel(pins) < 4
                    spiPinsArray(1).SCLPin = string(pins(1+2));
                    spiPinsArray(1).SDIPin = string(pins(1+1));
                    spiPinsArray(1).SDOPin = string(pins(1));
                else
                    for i = 4:4:numel(pins)
                        spiPinsArray(i/4).SCLPin = string(pins(i-1)); %#ok<AGROW>
                        spiPinsArray(i/4).SDIPin = string(pins(i-2)); %#ok<AGROW>
                        spiPinsArray(i/4).SDOPin = string(pins(i-3)); %#ok<AGROW>
                    end
                end
            end
        end

        function spiDriverObj = getSPIDriverObjHook(obj, ~)
        % Returns the SPI device driver to be used by SPI device object
        % for IO operation. If the object is not created, then create
        % one. Else, send the one already created and stored in
        % obj.SPIDriverObj
            if isempty(obj.SPIDriverObj)
                obj.SPIDriverObj = arduinodriver.ArduinoSPI();
            end
            spiDriverObj = obj.SPIDriverObj;
        end
    end
    %% serial.controller
    methods(Access = protected)
        function serialPinsArray = getAvailableSerialPinsImpl(obj)
            if ~ismember(obj.Board,arduinoio.internal.ArduinoConstants.SerialLibrarySupportBoards)
                serialPinsArray = [];
            elseif ismember(obj.Board,{'Leonardo', 'Micro', 'Nano33IoT'})
                serialPinsArray(1).TxPin =  "D1";
                serialPinsArray(1).RxPin =  "D0";
            elseif ismember(obj.Board,{'Nano33BLE'})
                %                 // Serial (EDBG)
                %                 #define PIN_SERIAL_RX (1ul)
                %                 #define PIN_SERIAL_TX (0ul)
                %                 P1_3,  NULL, NULL,     // D0/TX
                %                 P1_10, NULL, NULL,     // D1/RX
                serialPinsArray(1).TxPin =  "D0";
                serialPinsArray(1).RxPin =  "D1";
            else
                terminals = obj.getSerialTerminals();
                pins = getPinsFromTerminals(obj, terminals);
                serialPinsArray = [];
                if ismember(obj.Board,{'Due','Mega2560','MegaADK'})
                    if ~isempty(pins)
                        for i = 2:2:numel(pins)
                            serialPinsArray(i/2).TxPin = string(pins(numel(pins)-i+1)); %#ok<AGROW>
                            serialPinsArray(i/2).RxPin = string(pins(numel(pins)-i+2)); %#ok<AGROW>
                        end
                    end
                elseif ismember(obj.Board,{'MKR1000','MKR1010', 'MKRZero'})
                    if ~isempty(pins)
                        for i = 2:2:numel(pins)
                            serialPinsArray(i/2).TxPin = string(pins(i)); %#ok<AGROW>
                            serialPinsArray(i/2).RxPin = string(pins(i-1)); %#ok<AGROW>
                        end
                    end
                elseif ismember(obj.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                    if ~isempty(pins)
                        serialPinsArray(1).TxPin = [];
                        serialPinsArray(1).RxPin = [];
                        for i = 2:2:numel(pins)
                            serialPinsArray(2).TxPin = string(pins(i));
                            serialPinsArray(2).RxPin = string(pins(i-1));
                        end
                        serialPinsArray(3).TxPin = [];
                        serialPinsArray(3).RxPin = [];
                    end
                end
            end
        end

        function buses = getAvailableSerialPortIDsHook(obj)
            serialPinsArray = obj.getAvailableSerialPins();
            buses = [];
            if numel(serialPinsArray) > 0
                buses = 1:numel(serialPinsArray);
            end
            if ismember(obj.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                % Hardcoding for ESP32
                buses = 2;
            end
        end

        function supportedBaudRates = getSupportedBaudRatesHook(~)
            supportedBaudRates =  arduinoio.internal.ArduinoConstants.SupportedBaudRates;
        end

        function supportedParityOptions = getSupportedParityHook(~)
            supportedParityOptions=  arduinoio.internal.ArduinoConstants.SupportedParityTypes;
        end

        function supportedDataBitOptions = getSupportedDataBitsHook(~)
            supportedDataBitOptions =  arduinoio.internal.ArduinoConstants.SupportedDataBits;
        end

        function supportedStopBitOptions = getSupportedStopBitOptionsHook(~)
            supportedStopBitOptions =  arduinoio.internal.ArduinoConstants.SupportedStopBits;
        end

        function type = getSerialPortTypeImpl(~)
            type = "numeric";
        end
    end
    %% addon.controller
    methods(Access=protected)
        function libraries = getDefaultLibrariesHook(obj)
        % Update when Servo is enabled for ESP32
            libraries = string(arduinoio.internal.ArduinoConstants.getDefaultLibraries(obj.Board));
        end

        function libraryList = listLibrariesImpl(obj)
            libraryList = getAllLibraries(obj);
        end

        function [basePackageName] = getBasePackageNameImpl(~)
            basePackageName = "arduinoio";
        end

        function baseList = getBaseLibrariesHook(obj)
            baseList = [];
            superclassName = "matlabshared.addon.LibraryBase";
            if isa(obj, 'matlabshared.pwm.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.pwm', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.adc.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.adc', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.i2c.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.i2c', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.spi.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.spi', char(superclassName), true)'];
            end
            if isa(obj, 'matlabshared.serial.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.serial', char(superclassName), true)'];
            end
            baseList = [baseList; internal.findSubClasses('arduinoio', 'matlabshared.addon.LibraryBase', true)];
        end

        function alternateHeaderSearch = areAlternateLibraryHeadersAvailableHook(~, utilityObj, buildInfo)
            alternateHeaderSearch = areAlternateLibraryHeadersAvailableImpl(utilityObj, buildInfo);
        end

    end
    %% can.Node
    methods(Access=protected)
        function supportedCANDeviceInfo = getSupportedCANDeviceInfoImpl(~)
        % A table to capture various supported shields their Chip
        % Select and Interrupt Pins. Dummy values are provided for
        % MCP2515. This table is used for validating inputs.
            supportedDevices = [arduinoio.internal.ArduinoConstants.SupportedCANShields, ...
                                "MCP2515"];
            csPinsForAllSupportedDevices = [arduinoio.internal.ArduinoConstants.ChipSelectMKR, ...
                                            arduinoio.internal.ArduinoConstants.ChipSelectSparkfun, ...
                                            arduinoio.internal.ArduinoConstants.ChipSelectSeeed, ...
                                            "Dummy"];
            intPinsForAllSupportedDevices = [arduinoio.internal.ArduinoConstants.InterruptMKR, ...
                                             arduinoio.internal.ArduinoConstants.InterruptSparkfun, ...
                                             arduinoio.internal.ArduinoConstants.InterruptSeeed, ...
                                             "Dummy"];
            oscFreqForAllSupportedDevices = repmat(arduinoio.internal.ArduinoConstants.OscillatorFreqForSupportedShields, ...
                                                   1, 4); % 1x4 vector of osc freq
            supportedBoards = {arduinoio.internal.ArduinoConstants.BoardsSupportingMKR, ...
                               arduinoio.internal.ArduinoConstants.BoardsSupportingSparkfun, ...
                               arduinoio.internal.ArduinoConstants.BoardsSupportingSeeed, ...
                               []};
            supportedCANDeviceInfo = table(csPinsForAllSupportedDevices', ...
                                           intPinsForAllSupportedDevices', ...
                                           oscFreqForAllSupportedDevices', ...
                                           supportedBoards', ...
                                           'VariableNames', {'ChipSelectPin', 'InterruptPin', 'OscillatorFrequency', 'SupportedBoards'}, ...
                                           'RowNames', supportedDevices);
        end

        function canChipObj = getCANChannelProviderImpl(obj, deviceName, varargin)
        % Device name has been validated in matlabshared.can.canChannel
            try
                switch deviceName
                  case 'MCP2515'
                    % Chip Support
                    canChipObj = arduinoio.ArduinoMCP2515(obj, varargin{:});
                  otherwise
                    % Shield Support
                    % To check only the max. Min input is taken care of.
                    narginchk(2, 4);
                    % OscilllatorFrequency not allowed for Shields
                    p = inputParser;
                    p.PartialMatching = true;
                    p.KeepUnmatched = true;
                    addParameter(p, 'OscillatorFrequency', []);
                    try
                        parse(p, varargin{:});
                    catch e
                        throwAsCaller(e);
                    end
                    if ~isempty(p.Results.OscillatorFrequency)
                        obj.localizedError('MATLAB:arduinoio:can:oscFreqNotAllowedForShields');
                    end
                    % Prepend varargin with CS Pin and INT Pin
                    varargin = [{obj.SupportedCANDeviceInfo{deviceName, 1}}, {obj.SupportedCANDeviceInfo{deviceName, 2}}, varargin]; %#ok<CCAT1>
                    canChipObj = arduinoio.ArduinoMCP2515(obj, varargin{:});
                end
            catch e
                switch e.identifier
                  case 'MATLAB:arduinoio:can:noMCP2515'
                    obj.localizedError('MATLAB:arduinoio:can:noMCP2515', char(deviceName));
                  otherwise
                    throwAsCaller(e);
                end
            end
        end
    end

    %% Custom Display
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);

            switch obj.ConnectionType
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                fprintf('                  Port: ''%s''\n', obj.Port);
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                fprintf('         DeviceAddress: ''%s''\n', obj.DeviceAddress);
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                fprintf('               Address: ''%s''\n', obj.Address);
                fprintf('                  Name: ''%s''\n', obj.Name);
                fprintf('             Connected: %d\n', obj.Connected);
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                fprintf('         DeviceAddress: ''%s''\n', obj.DeviceAddress);
                fprintf('                  Port: %d\n', obj.Port);
            end

            obj.displayDynamicPropertiesHook();
            fprintf('         AvailablePins: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.AvailablePins)));
            if isa(obj, 'matlabshared.dio.controller')
                fprintf('  AvailableDigitalPins: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.AvailableDigitalPins)));
            end
            if isa(obj, 'matlabshared.pwm.controller')
                fprintf('      AvailablePWMPins: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.AvailablePWMPins)));
            end
            if isa(obj, 'matlabshared.adc.controller')
                fprintf('   AvailableAnalogPins: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.AvailableAnalogPins)));
            end
            if isa(obj, 'matlabshared.i2c.controller')
                fprintf('    AvailableI2CBusIDs: [%s]\n', ...
                        matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableI2CBusIDs));
            end
            if isa(obj, 'matlabshared.serial.controller')  && ~isempty(obj.AvailableSerialPortIDs)
                fprintf('AvailableSerialPortIDs: [%s]\n', ...
                        matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableSerialPortIDs));
            end
            if isa(obj, 'matlabshared.addon.controller')
                fprintf('             Libraries: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.Libraries)));
            end

            % Allow for the possibility of a footer.
            footer = matlabshared.hwsdk.internal.footer(inputname(1));

            if ~isempty(footer)
                disp(footer);
            end
            fprintf('\n');
        end

        function displayDynamicPropertiesHook(obj)
            fprintf('                 Board: ''%s''\n', char(obj.getBoardNameHook));
        end

        % HWSDK displays pins as string array. Since Arduino has been
        % displaying pins as cell array of character vector, following
        % methods are overridden to make the property cellstr.
        function availablePins = getAvailablePinsForPropertyDisplayHook(~, pins)
            availablePins = cellstr(pins);
        end

        function availableDigitalPins = getAvailableDigitalPinsForPropertyDisplayHook(~, pins)
            availableDigitalPins = cellstr(pins);
        end

        function availableAnalogPins = getAvailableAnalogPinsForPropertyDisplayHook(~, pins)
            availableAnalogPins = cellstr(pins);
        end

        function availablePWMPins = getAvailablePWMPinsForPropertyDisplayHook(~, pins)
            availablePWMPins = cellstr(pins);
        end

        function libraries = getLibrariesForPropertyDisplayHook(~, libs)
            libraries = cellstr(libs);
        end
    end

    %% Footer display
    methods(Access = public, Hidden, Sealed)
        function showAllProperties(obj)
            switch obj.ConnectionType
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                fprintf('                  Port: ''%s''\n', obj.Port);
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                fprintf('         DeviceAddress: ''%s''\n', obj.DeviceAddress);
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                fprintf('         DeviceAddress: ''%s''\n', obj.DeviceAddress);
                fprintf('                  Port: %d\n', obj.Port);
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                fprintf('               Address: ''%s''\n',obj.Address);
                fprintf('                  Name: ''%s''\n',obj.Name);
                fprintf('             Connected: %d\n', obj.Connected);
            end

            obj.displayDynamicPropertiesHook();
            fprintf('         AvailablePins: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.AvailablePins)));
            fprintf('  AvailableDigitalPins: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.AvailableDigitalPins)));
            fprintf('      AvailablePWMPins: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.AvailablePWMPins)));
            fprintf('   AvailableAnalogPins: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.AvailableAnalogPins)));
            fprintf('    AvailableI2CBusIDs: [%s]\n', matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableI2CBusIDs));
            if ~isempty(obj.AvailableSerialPortIDs)
                fprintf('AvailableSerialPortIDs: [%s]\n', matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableSerialPortIDs));
            end
            fprintf('             Libraries: {%s}\n', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedCharacterVector(string(obj.Libraries)));
            fprintf('   AnalogReferenceMode: ''%s''\n',obj.AnalogReferenceMode);
            fprintf('       AnalogReference: %5.3f(V)\n',obj.AnalogReference);

            % Display the BaudRate if the connection type is Serial
            if isequal(obj.ConnectionType, matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial)
                fprintf('              BaudRate: %d\n',obj.BaudRate);
            end
            fprintf('\n');
        end
    end

    %% Helper methods
    methods(Access=private)
        function arduinoCLIPath = fetchConfigurationDetailsFromInputs(~, varargin)
        %fetchConfigurationDetailsFromInputs fetches
        %arduino CLI Location from input arguments of arduino API
        %   a = arduino(<port>, <board>, 'ArduinoCLIPath', <loc>)
        %   eliminates UI from appearing in the MCR Environment
            if nargin >= 4
                p = inputParser;
                % Accept partial matching
                p.PartialMatching = true;
                % Silently ignore other NV Pairs
                p.KeepUnmatched = true;
                addParameter(p, 'ArduinoCLIPath', '');
                try
                    if strcmp(getenv('HostIOServerTransport'),'tcpclient')
                        % <ipaddress>,<board>,<tcpipport>,'ArduinoCLIPath'
                        numOfInitialParams = 4;
                    else
                        % <port>,<board>,'ArduinoCLIPath'
                        numOfInitialParams = 3;
                    end
                    parse(p, varargin{numOfInitialParams:end});
                catch
                    % Ignore ParamMissingValue error. No other error thrown
                end
                arduinoCLIPath = p.Results.ArduinoCLIPath;
            else
                arduinoCLIPath = '';
            end
        end

        function [port, board, arduinoCLIPath] = fetchConfigurationDetailsFromUser(obj, varargin)
            if nargin >= 3
                % obj, Port, Board + other NV Pairs
                defaultPort = varargin{1};
                defaultBoard = varargin{2};
            elseif nargin == 2
                % Only obj, Port
                defaultPort = varargin{1};
                defaultBoard = '';
            elseif nargin == 1
                % Only obj
                defaultPort = '';
                defaultBoard = '';
            end
            % Launch UI for getting arduino configuration details
            [port, board, arduinoCLIPath] = arduinoio.internal.getPortBoardCLI(obj.Utility, defaultPort, defaultBoard);
        end

        function initResourceManager(obj, boardType)
            obj.ResourceManager = arduinoio.internal.ResourceManager(char(boardType));
            supportedBoards = arduinoio.internal.ArduinoConstants.getSupportedBoards(obj.ConnectionType);
            switch obj.ConnectionType
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                try
                    obj.Board = validatestring(obj.Board, supportedBoards);
                catch
                    obj.localizedError('MATLAB:hwsdk:general:invalidBluetoothBoard', obj.Board, strjoin(supportedBoards, ', '));
                end
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                try
                    obj.Board = validatestring(obj.Board, supportedBoards);
                catch
                    obj.localizedError('MATLAB:hwsdk:general:invalidWiFiBoard', obj.Board, strjoin(supportedBoards, ', '));
                end
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                try
                    obj.Board = validatestring(obj.Board, supportedBoards);
                catch
                    obj.localizedError('MATLAB:hwsdk:general:invalidBLEBoard', obj.Board, strjoin(supportedBoards, ', '));
                end
            end
        end

        function initUtility(obj)
            obj.Utility = arduinoio.internal.UtilityCreator.getInstance();
        end

        function result = validateBoard(~, boardParam)
            b = arduinoio.internal.BoardInfo.getInstance();
            for board = b.Boards
                if strcmpi(board.Name, boardParam)
                    result = board.Name;
                    return;
                end
            end
            error(['Invalid Board: ' boardParam]);
        end

        function buildInfo = prepareBuildInfo(obj, buildInfo)
            buildInfo.ConnectionType = obj.ConnectionType;
            buildInfo.Port = obj.Port;
            buildInfo.Libraries = obj.Libraries;
            buildInfo.TraceOn = obj.TraceOn;
            buildInfo.SPPKGPath = arduinoio.SPPKGRoot;
            buildInfo.BaudRate = num2str(obj.BaudRate);
            buildInfo.HWSPPKGVersion = obj.LibVersion;
            buildInfo.MAXPacketSize = getMaxBufferSizeImpl(obj);
            buildInfo.AnalogReference = obj.AnalogReference;
            buildInfo.AnalogReferenceMode = obj.AnalogReferenceMode;
            if buildInfo.TraceOn
                buildInfo.ShowUploadResult = true;
            else
                buildInfo.ShowUploadResult = false;
            end
            if isdeployed()
                buildInfo.CLIPath = char(obj.ArduinoCLIPath);
            end
            disp(obj.getLocalizedText('MATLAB:arduinoio:general:programmingArduino', buildInfo.Board, char(buildInfo.Port)));
        end

        %Validate user inputs for Analog Reference and Analog Reference
        %Mode and initialize these properties
        function validateAnalogReference(obj)

        %Default internal analog reference voltage
            if ismember(obj.Board, arduinoio.internal.ArduinoConstants.AREF3VBoards)
                DefaultInternalReference = 3.3;
            else
                DefaultInternalReference = 5.0;
            end

            if (isempty(obj.AnalogReference) && isempty(obj.AnalogReferenceMode) && ~obj.ForceBuildOn)
                % If 'ForceBuildOn' is false, initalize with the existing
                % server's values in validateServerAnalogReferenceInfo()
            elseif ((isempty(obj.AnalogReference) && strcmpi(obj.AnalogReferenceMode,'internal'))...
                    || (isempty(obj.AnalogReference) && isempty(obj.AnalogReferenceMode) && obj.ForceBuildOn))
                %Default analog reference values
                obj.AnalogReference = DefaultInternalReference;
                obj.AnalogReferenceMode = 'internal';
            elseif (~isempty(obj.AnalogReference) && (isempty(obj.AnalogReferenceMode) || strcmpi(obj.AnalogReferenceMode,'external')))
                if ~ismember(obj.Board,arduinoio.internal.ArduinoConstants.ExternalAREFUnsupportedBoards) % these boards don't support external AREF
                                                                                                          %External analog reference mode
                    if (obj.AnalogReference > 0 && obj.AnalogReference <= DefaultInternalReference)
                        obj.AnalogReferenceMode = 'external';
                    else
                        obj.localizedError('MATLAB:arduinoio:general:invalidAnalogReferenceValue',num2str(DefaultInternalReference));
                    end
                else
                    obj.localizedError('MATLAB:arduinoio:general:analogReferenceUnsupported',obj.Board);
                end
            elseif (~isempty(obj.AnalogReference) && strcmpi(obj.AnalogReferenceMode,'internal'))
                %Internal analog reference mode

                %Ensure AnalogReferenceMode provided by user is initialized in lower case
                obj.AnalogReferenceMode = 'internal';

                %Combine valid internal analog reference voltage values for
                %an arduino board in validAnalogReference variable
                validAnalogReference = 'null';
                switch obj.Board
                  case {'Uno','Nano3','ProMini328_3V','ProMini328_5V','DigitalSandbox'}
                    if ~(obj.AnalogReference == arduinoio.internal.ArduinoConstants.InternalAnalogReferenceAVR{1} ...
                         || obj.AnalogReference == DefaultInternalReference)

                        validAnalogReference = ['',num2str(arduinoio.internal.ArduinoConstants.InternalAnalogReferenceAVR{1}),'(V)',',',''];
                    end
                  case {'Mega2560','MegaADK'}
                    if ~(obj.AnalogReference == arduinoio.internal.ArduinoConstants.InternalAnalogReferenceAVR{1} ...
                         || obj.AnalogReference == arduinoio.internal.ArduinoConstants.InternalAnalogReferenceAVR{2} ...
                         || obj.AnalogReference == DefaultInternalReference)

                        validAnalogReference = ['',num2str(arduinoio.internal.ArduinoConstants.InternalAnalogReferenceAVR{1}),'(V)',',','',...
                                                '',num2str(arduinoio.internal.ArduinoConstants.InternalAnalogReferenceAVR{2}),'(V)',',',''];
                    end
                  case {'Leonardo','Micro'}
                    if ~(obj.AnalogReference == arduinoio.internal.ArduinoConstants.InternalAnalogReferenceAVR{2} ...
                         || obj.AnalogReference == DefaultInternalReference)

                        validAnalogReference = ['',num2str(arduinoio.internal.ArduinoConstants.InternalAnalogReferenceAVR{2}),'(V)',',',''];
                    end
                  case {'MKR1000','MKR1010','MKRZero','Nano33IoT'}
                    if ~(obj.AnalogReference == arduinoio.internal.ArduinoConstants.InternalAnalogReferenceSAMD{1} ...
                         || obj.AnalogReference == arduinoio.internal.ArduinoConstants.InternalAnalogReferenceSAMD{2} ...
                         || obj.AnalogReference == arduinoio.internal.ArduinoConstants.InternalAnalogReferenceSAMD{3} ...
                         || obj.AnalogReference == DefaultInternalReference)

                        validAnalogReference = ['',num2str(arduinoio.internal.ArduinoConstants.InternalAnalogReferenceSAMD{1}),'(V)',',','',...
                                                '',num2str(arduinoio.internal.ArduinoConstants.InternalAnalogReferenceSAMD{2}),'(V)',',','',...
                                                '',num2str(arduinoio.internal.ArduinoConstants.InternalAnalogReferenceSAMD{3}),'(V)',',',''];
                    end
                  case {'Due','Nano33BLE','ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}
                    if ~(obj.AnalogReference == DefaultInternalReference)
                        validAnalogReference = '';
                    end
                end

                % Throw an error with valid internal analog reference values
                % for the arduino board user is using, if validAnalogReference has any value other than the
                % intialized value 'null'
                if ~strcmpi(validAnalogReference,'null')
                    obj.localizedError('MATLAB:arduinoio:general:invalidInternalAnalogReferenceValue',num2str(obj.AnalogReference),validAnalogReference,num2str(DefaultInternalReference));
                end
            elseif (isempty(obj.AnalogReference) && strcmpi(obj.AnalogReferenceMode,'external'))
                %If anlaog reference voltage value is not provided for
                %external analog reference mode, throw an error
                if (~ismember(obj.Board,{'Due','Nano33BLE'}))
                    obj.localizedError('MATLAB:arduinoio:general:missingAnalogReferenceValue',num2str(DefaultInternalReference));
                else
                    obj.localizedError('MATLAB:arduinoio:general:analogReferenceUnsupported',obj.Board);
                end
            else
                %If analog reference mode is given an input other than internal or external
                if (~ismember(obj.Board,{'Due','Nano33BLE'}))
                    validAnalogReferenceModes = '''external'' or ''internal''';
                    obj.localizedError('MATLAB:arduinoio:general:invalidAnalogReferenceMode',obj.Board,validAnalogReferenceModes);
                else
                    validAnalogReferenceModes = '''internal''';
                    obj.localizedError('MATLAB:arduinoio:general:invalidAnalogReferenceMode',obj.Board,validAnalogReferenceModes);
                end
            end
        end

        function status = validateServerAnalogReferenceInfo(obj,serverInfo)

            if(obj.ForceBuildOn)
                status=true;
            else
                %Extract analog reference macro and the analog reference voltage from server

                serverAnalogReferenceVoltage = str2double(extractAfter(extractAfter(extractAfter(extractAfter(serverInfo.CustomData,','),','),','),'  '));
                serverAnalogReferenceMacroValue = extractAfter(extractBefore(extractAfter(extractAfter(serverInfo.CustomData,','),','),','),'  ');

                % If user doesn't provide AnalogReference name value pair and
                % ForceBuild is false, initalize with the existing server's values
                if (isempty(obj.AnalogReference) && isempty(obj.AnalogReferenceMode))
                    if logical(serverAnalogReferenceVoltage>=0)
                        % AnalogReference initialization is being repeated for the below values of analog reference macro, to
                        % ensure server values are taken only when both reference voltage and analog reference macro
                        % have valid values. For invalid values the properties should be left blank and server should
                        % be initialized to default values in Utility class. For more details refer to g2130242
                        switch obj.Board
                          case {'Uno','UnoR4WiFi','UnoR4Minima','Nano3','ProMini328_3V','ProMini328_5V','DigitalSandbox','Mega2560','MegaADK','Leonardo','Micro'}
                            if (strcmpi(serverAnalogReferenceMacroValue,"0"))
                                obj.AnalogReferenceMode = 'external';
                                obj.AnalogReference = serverAnalogReferenceVoltage;
                            elseif (any(strcmpi(serverAnalogReferenceMacroValue,["1","2","3"])))
                                obj.AnalogReferenceMode = 'internal';
                                obj.AnalogReference = serverAnalogReferenceVoltage;
                            end
                          case {'MKR1000','MKR1010','MKRZero','Due','Nano33IoT','Nano33BLE'}
                            if (strcmpi(serverAnalogReferenceMacroValue,"2"))
                                obj.AnalogReferenceMode = 'external';
                                obj.AnalogReference = serverAnalogReferenceVoltage;
                            elseif (any(strcmpi(serverAnalogReferenceMacroValue,["0","1","3","4","5"])))
                                obj.AnalogReferenceMode = 'internal';
                                obj.AnalogReference = serverAnalogReferenceVoltage;
                            end
                          case {'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
                            obj.AnalogReferenceMode = 'internal';
                            obj.AnalogReference = serverAnalogReferenceVoltage;
                        end
                    end
                end

                %Return status value as true if server analog reference
                %voltage and mode is same as the user provided values
                switch obj.Board
                  case {'Uno','UnoR4WiFi','UnoR4Minima','Nano3','ProMini328_3V','ProMini328_5V','DigitalSandbox','Mega2560','MegaADK','Leonardo','Micro'}
                    if strcmpi(obj.AnalogReferenceMode,'external')
                        status = (serverAnalogReferenceVoltage == obj.AnalogReference) && strcmpi(serverAnalogReferenceMacroValue,"0");
                    elseif strcmpi(obj.AnalogReferenceMode,'internal')
                        status = (serverAnalogReferenceVoltage == obj.AnalogReference) && any(strcmpi(serverAnalogReferenceMacroValue,["1","2","3"]));
                    else
                        status = 0;
                    end
                  case {'MKR1000','MKR1010','MKRZero','Due','Nano33IoT','Nano33BLE'}
                    if strcmpi(obj.AnalogReferenceMode,'external')
                        status = (serverAnalogReferenceVoltage == obj.AnalogReference) && strcmpi(serverAnalogReferenceMacroValue,"2");
                    elseif strcmpi(obj.AnalogReferenceMode,'internal')
                        status = (serverAnalogReferenceVoltage == obj.AnalogReference) && any(strcmpi(serverAnalogReferenceMacroValue,["0","1","3","4","5"]));
                    else
                        status = 0;
                    end
                  case {'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
                    status = (serverAnalogReferenceVoltage == obj.AnalogReference) && any(strcmpi(serverAnalogReferenceMacroValue,"0"));
                end
            end
        end

        function pinStatus = configurePinForPeripheralsWithDedicatedResourceOwner(obj, pin, mode, caller, resourceOwner)
        % This function has been separated only to reduce cyclomatic
        % complexity in configurePinImpl.
            switch caller
              case 'spi.device'
                % SPI Pins - store state and configure
                % resource
                % CS Pin - store state, configure resource
                % and update pin mode map so that
                % hwsdk.controller will later configure the
                % pin to digital output through IOServer
                if strcmp(mode,'DigitalOutput')
                    % Update CS Pin resource to SPI mode,
                    % so that it becomes incompatible to
                    % other modes until spi object is
                    % cleared
                    pinStatus = configurePinWithUndo(pin, resourceOwner, mode, true);
                    overridePinResource(obj,pin,resourceOwner,'SPI');
                else
                    pinStatus = configurePinWithUndo(pin, resourceOwner, mode, false);
                end
              otherwise
                % Store the state and configure pins because current
                % state is required for restoration when object
                % creation fails. This case works for i2c.device,
                % serial.device, shiftRegister and ultrasonic.
                pinStatus = configurePinWithUndo(pin, resourceOwner, mode, false);
            end

            function pinStatus = configurePinWithUndo(pin, resourceOwner, pinMode, forceConfig)
                [~, ~, prevMode, prevResourceOwner] = getPinInfo(obj.ResourceManager, obj, pin);
                pinStatus.Pin = pin;
                pinStatus.ResourceOwner = prevResourceOwner;
                pinStatus.PrevPinMode = prevMode;
                configurePinResource(obj, pin, resourceOwner, pinMode, forceConfig);
            end
        end
    end

    %% Public methods for arduino libraries implementing LibraryBase
    methods(Access = {?matlabshared.hwsdk.internal.base,?arduino.accessor.UnitTest})

        function id = getLibraryID(obj, libName)
            if contains(strjoin(obj.Libraries), libName)
                % Adding LibraryIDs only to addon libraries. Until
                % IOServer extends LibraryIDs to all libraries.

                addOnIndices = false(1, numel(obj.Libraries));

                % Iterate over each library in obj.Libraries
                for i = 1:numel(obj.Libraries)
                    % Check if the current library is in the list of
                    % shipping libraries and if it is not a shipping library,
                    % mark it as true in addOnIndices
                    addOnIndices(i) = ~(any(strcmpi(obj.Libraries{i}, arduinoio.internal.ArduinoConstants.ShippingLibraries)));
                end

                addOnLibraries = obj.Libraries(addOnIndices);
                id = find(contains(addOnLibraries, libName))-1;
            else
                obj.localizedError('MATLAB:arduinoio:general:libraryNotUploaded', libName);
            end
        end

        function maxBytes = getMaxBufferSizeImpl(obj)

            maxBytes = arduinoio.internal.getMaxBufferSizeForBoard(obj.Board);

        end

        function name = getBoardNameHook(obj)
            name = obj.Board;
        end
        %% Arduino Custom Addon's API
        % BEGIN

        function result = getMCU(obj)
            result = obj.ResourceManager.MCU;
        end

        function out = getPinAlias(obj, pin)
            try
                out = obj.ResourceManager.getPinAlias(pin);
            catch e
                throwAsCaller(e);
            end
        end

        function terminals = getTerminalsFromPins(obj, pins)
            try
                terminals = obj.ResourceManager.getTerminalsFromPins(pins);
            catch e
                throwAsCaller(e);
            end
        end

        function pins = getPinsFromTerminals(obj, terminals)
            if isempty(terminals)
                pins = {};
                return;
            end

            try
                pins = obj.ResourceManager.getPinsFromTerminals(terminals);
            catch e
                throwAsCaller(e);
            end
        end

        function result = isTerminalAnalog(obj, terminal)
            try
                result = obj.ResourceManager.isTerminalAnalog(terminal);
            catch e
                throwAsCaller(e);
            end
        end

        function result = isTerminalDigital(obj, terminal)
            try
                result = obj.ResourceManager.isTerminalDigital(terminal);
            catch e
                throwAsCaller(e);
            end
        end

        function value = getTerminalMode(obj, terminal)
            try
                value = obj.ResourceManager.getTerminalMode(terminal);
            catch e
                throwAsCaller(e);
            end
        end

        function terminals = getI2CTerminals(obj, bus)
            try
                if nargin < 2
                    bus = 0;
                end
                terminals = obj.ResourceManager.getI2CTerminals(bus);
            catch e
                throwAsCaller(e);
            end
        end

        function terminals = getSerialTerminals(obj, varargin)
            try
                narginchk(1,1);
                if nargin > 1
                    port = varargin{1};
                    terminals = obj.ResourceManager.getSerialTerminals(port);
                else
                    terminals = obj.ResourceManager.getSerialTerminals;
                end
            catch e
                throwAsCaller(e);
            end
        end


        function terminals = getSPITerminals(obj)
            try
                terminals = obj.ResourceManager.getSPITerminals();
            catch e
                throwAsCaller(e);
            end
        end

        function terminals = getServoTerminals(obj)
            terminals = obj.ResourceManager.getServoTerminals();
        end

        function terminals = getPWMTerminals(obj)
            terminals = obj.ResourceManager.getPWMTerminals();
        end

        function terminals = getInterruptTerminals(obj)
            terminals = obj.ResourceManager.getInterruptTerminals();
        end

        function pin = getPinAliasHook(obj, pin)
            try
                pin = getPinAlias(obj, pin);
            catch
                validPins = obj.getAvailableDigitalPins();
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidPinNumber', obj.Board, matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(validPins));
            end
        end

        function validatePin(obj, pin, type)
            try
                % Validate terminals does the actual validation based on
                % the Arduino board.
                % All pins are digital pins. Hence validating with digital.
                pin = validateDigitalPin(obj, pin);
                [~, terminal, ~, ~] = getPinInfo(obj.ResourceManager, obj, pin);
                obj.ResourceManager.validateTerminal(terminal, type);
            catch e
                throwAsCaller(e);
            end
        end

        function varargout = configurePinResource(obj, pin, resourceOwner, mode, forceConfig)
            try
                if nargout > 0
                    narginchk(2, 2);
                    varargout = {configurePin(obj.ResourceManager, pin)};
                else
                    narginchk(4, 5);
                    if isstring(mode) || ischar(mode)
                        if strcmp(mode, '')
                            mode = 'Unset';
                        end
                        % Check for partial matching input and correct it
                        supportedModes = obj.getSupportedModesHook();
                        % Modes matching to input
                        matchingModes = strncmpi(mode, supportedModes, strlength(string(mode)));
                        % Find if there is a unique matching mode
                        if any(matchingModes)
                            count = histcounts(matchingModes);
                            if 2 == numel(count) && 1 == count(2)
                                % Update if there is a unique matching mode
                                mode = supportedModes{matchingModes};
                            else
                                % Error if no unique matching mode
                                if strcmp('D', extractBefore(pin, 2))
                                    subsystem = 'Digital';
                                else
                                    subsystem = 'Analog';
                                end
                                obj.localizedError('MATLAB:hwsdk:general:invalidPinMode', ...
                                                   subsystem, ...
                                                   matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(supportedModes, ', '));
                            end
                        end
                    end

                    [~, pinNumber, prevMode, prevResourceOwner] = getPinInfo(obj.ResourceManager, obj, pin);
                    % Set the pin number property in device driver class

                    if nargin < 5
                        forceConfig = false;
                    end

                    try
                        configurePin(obj.ResourceManager, pin, resourceOwner, mode, forceConfig);
                    catch e
                        if strcmp(e.identifier, 'MATLAB:hwsdk:general:resourceReserved') ... % Error coming from validateResourceOwner
                                && ((strcmpi(prevMode, 'Tone') && strcmpi(prevResourceOwner, obj.ArduinoResourceOwner)) || ...  % Pin configured to Tone by Arduino
                                    (strcmpi(prevMode, 'Reserved') && strcmpi(prevResourceOwner, obj.ToneResourceOwner)))           % Pin configured to Reserved by Tone
                                                                                                                                    % Other modes are invading on Tone Mode.
                                                                                                                                    % Throw error when an attempt is made to configure the pins reserved by Tone, in different modes
                            obj.localizedError('MATLAB:arduinoio:general:reservedByTone', obj.Board, char(pin), char(obj.TonePin));
                        else
                            throwAsCaller(e);
                        end
                    end
                    mode = configurePin(obj.ResourceManager, pin);
                    if strcmpi(mode, 'Unset')
                        if strcmpi(prevMode, 'Tone')
                            % Tone stops when freq = 0 or duration = 0
                            peripheralPayload = [pinNumber, typecast(uint16(0), 'uint8'), typecast(uint16(0), 'uint8')];
                            rawWrite(obj.Protocol, obj.PLAYTONE, peripheralPayload);
                            obj.TonePin = '';
                        end
                        if ~strcmpi(prevMode, 'Interrupt')
                            if ~strcmpi(obj.Board, 'Due')
                                if strcmpi(prevMode, 'SPI')
                                    spiPins = getSPITerminals(obj);
                                    pinNumber = spiPins(end);
                                end
                                mapPinModes(obj, pinNumber, ["DigitalInput", "Unset"]);
                            end
                        end
                    elseif ismember(mode, {'DigitalInput', 'DigitalOutput', 'Pullup', 'AnalogInput', 'PWM'})
                        if ~strcmpi(prevMode, mode) && ... % For Pullup.
                                ~ismember(mode,{'PWM','DigitalOutput'}) &&...
                                ~(ismember(prevMode, {'AnalogInput', 'DigitalInput'}) && ismember(mode, {'AnalogInput', 'DigitalInput'}))

                            if ismember(mode,{'AnalogInput', 'DigitalInput', 'Pullup'})
                                pinNumberAnalog = pinNumber;
                                if ismember(obj.Board,{'Leonardo','Micro'})
                                    %added to fix g2154643. This ensures
                                    %pinHandleMaps for all alias pins are
                                    %initialized properly
                                    [pinNumberAnalog, pinNumber] = getAnalogPinsLeonardoMicro(obj.ResourceManager, pin);
                                end
                                % Instead of calling the IOClient APIs directly,
                                % the open/close methods of each peripheral is
                                % called
                                mapPinModes(obj, pinNumberAnalog, "AnalogInput");
                                if strcmpi(mode, 'Pullup')
                                    mapPinModes(obj, pinNumber, "DigitalInput_PullUp");
                                else
                                    mapPinModes(obj, pinNumber, "DigitalInput");
                                end
                            end
                        elseif ~ismember(obj.Board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}) && ~strcmpi(prevMode, mode) && ...
                                ~(ismember(prevMode, {'DigitalOutput', 'PWM'}) && ismember(mode, {'DigitalOutput', 'PWM'}))
                            % change pin mode on the board only when the new mode
                            % is different from the previous mode plus it is not a
                            % conversion between DigitalInput & AnalogInput
                            % or between PWM & DigitalOutput
                            if ismember(mode,{'PWM', 'DigitalOutput'})
                                % Frequency is set automatically by Arduino. PWM Duty cycle is not set here
                                mapPinModes(obj, pinNumber, ["PWM", "DigitalOutput"]);
                            end
                        elseif ismember(obj.Board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}) && ~strcmpi(prevMode, mode) && ...
                                ismember(mode, {'DigitalOutput', 'PWM'})
                            if ismember(mode,{'PWM'})
                                mapPinModes(obj, pinNumber, "PWM");
                            elseif ismember(mode,{'DigitalOutput'})
                                mapPinModes(obj, pinNumber, "DigitalOutput");
                            end
                        end
                    end
                end
            catch e
                throwAsCaller(e);
            end
        end

        % Resource Count Methods
        function count = incrementResourceCount(obj, resourceName)
            try
                count = obj.ResourceManager.incrementResourceCount(resourceName);
            catch e
                throwAsCaller(e);
            end
        end

        function count = decrementResourceCount(obj, resourceName)
            try
                count = obj.ResourceManager.decrementResourceCount(resourceName);
            catch e
                throwAsCaller(e);
            end
        end

        function count = getResourceCount(obj, resourceName)
            try
                count = obj.ResourceManager.getResourceCount(resourceName);
            catch e
                throwAsCaller(e);
            end
        end

        % Resource Slots
        function slot = getFreeResourceSlot(obj, resourceName)
            try
                slot = obj.ResourceManager.getFreeResourceSlot(resourceName);
            catch e
                throwAsCaller(e);
            end
        end

        function clearResourceSlot(obj, resourceName, slot)
            try
                obj.ResourceManager.clearResourceSlot(resourceName, slot);
            catch e
                throwAsCaller(e);
            end
        end

        % Resource Properties
        function setSharedResourceProperty(obj, resourceName, propertyName, propertyValue)
            try
                obj.ResourceManager.setSharedResourceProperty(resourceName, propertyName, propertyValue);
            catch e
                throwAsCaller(e);
            end
        end

        function value = getSharedResourceProperty(obj, resourceName, propertyName)
            try
                value = obj.ResourceManager.getSharedResourceProperty(resourceName, propertyName);
            catch e
                throwAsCaller(e);
            end
        end

        % Get Pin ResourceOwner
        function resourceOwner = getResourceOwner(obj, terminal)
            try
                resourceOwner = getResourceOwner(obj.ResourceManager, terminal);
            catch e
                throwAsCaller(e);
            end
        end

        % Update Resource owner for SPI
        function overridePinResource(obj, pin, resourceOwner, mode)
            try
                overridePinResource(obj.ResourceManager, pin, resourceOwner, mode);
            catch e
                throwAsCaller(e);
            end
        end

        % Converts HWSDK I2C Bus ID to Hardware Bus Number
        function [busNumber, SCLPin, SDAPin] = getI2CBusInfoHook(obj, hwsdkI2CBusID)
            busNumber = hwsdkI2CBusID;
            i2cPins = obj.getAvailableI2CPins();
            SCLPin = i2cPins(hwsdkI2CBusID+1).SCLPin;
            SDAPin = i2cPins(hwsdkI2CBusID+1).SDAPin;
        end

        function hwsdkDefaultI2CBusID = getHwsdkDefaultI2CBusIDHook(~)
            hwsdkDefaultI2CBusID = 0;
        end

        % Hardware inherits following I2C methods to modify the property disp
        function sclPin = getI2CSCLPinForPropertyDisplayHook(obj, pin)
            if strcmp(obj.Board, 'Due') && strcmp(pin, 'D71')
                sclPin = 'SCL1';
            else
                sclPin = char(pin);
            end
        end

        function sdaPin = getSDAPinForPropertyDisplayHook(obj, pin)
            if strcmp(obj.Board, 'Due') && strcmp(pin, 'D70')
                sdaPin = 'SDA1';
            else
                sdaPin = char(pin);
            end
        end

        % Hardware inherits following SPI methods to modify the property disp
        function csPin = getCSPinForPropertyDisplayHook(~, pin)
            csPin = char(pin);
        end

        function sclPin = getSPISCLPinForPropertyDisplayHook(~, pin)
            sclPin = char(pin);
        end

        function sdiPin = getSDIPinForPropertyDisplayHook(~, pin)
            sdiPin = char(pin);
        end

        function sdoPin = getSDOPinForPropertyDisplayHook(~, pin)
            sdoPin = char(pin);
        end

        % Hardware inherits following SPI method to modify the object disp
        function showSPIProperties(~, Interface, SPIChipSelectPin, SCLPin, SDIPin, SDOPin, SPIMode, ActiveLevel, BitOrder, BitRate, showAll)
            if nargin < 2
                showAll = 0;
            end

            fprintf('             Interface: ''%s''\n', Interface);
            fprintf('      SPIChipSelectPin: ''%s''\n', SPIChipSelectPin);

            fprintf('                SCLPin: ''%s''\n', SCLPin);
            fprintf('                SDIPin: ''%s''\n', SDIPin);
            fprintf('                SDOPin: ''%s''\n', SDOPin);

            if showAll
                fprintf('               SPIMode: %d\n', SPIMode);
                fprintf('           ActiveLevel: ''%s''\n', ActiveLevel);
                fprintf('              BitOrder: ''%s''\n', BitOrder);
                fprintf('               BitRate: %d (bits/s)\n', BitRate);
            end

            fprintf('\n');
        end

        function isPinConfigurable = isPinConfigurableHook(obj, varargin)
        % ISPINCONFIGURABLEHOOK specifies if a particular pin (and/or)
        % interface is configurable or not
        % INPUTS:
        %   obj - this
        %   NV Pairs:
        %       Interface (matlabshared.hwsdk.internal.InterfaceEnum
        %       Pin
        % OUTPUTS:
        %   isPinConfiguraPle (bool)
        %       true => the pin is configurable and configurePinInternal
        %       will be called on it
        %       false => the pin is not configurable

            if nargin == 1
                isPinConfigurable = true;
            else
                p = inputParser;
                p.PartialMatching = true;
                addParameter(p, 'Interface', []);
                addParameter(p, 'Pin', []);
                parse(p, varargin{:});
                if isempty(p.Results.Interface)
                    isPinConfigurable = true;
                else
                    switch p.Results.Interface
                      case matlabshared.hwsdk.internal.InterfaceEnum.SPI
                        spiPinStruct = getAvailableSPIPins(obj);
                        spiPins = [spiPinStruct.SCLPin, spiPinStruct.SDIPin, spiPinStruct.SDOPin];
                        if isempty(p.Results.Pin) || ...
                                (~isempty(p.Results.Pin) && any(strcmp(cellstr(p.Results.Pin), cellstr(spiPins))))
                            % Either no pins specified (or)
                            % Specified pins are SPI Pins
                            if any(contains(obj.Board, ["Due", "Leonardo", "Micro"]))
                                isPinConfigurable = false;
                            else
                                isPinConfigurable = true;
                            end
                        else
                            % Pins are specified and they are CS pins
                            isPinConfigurable = true;
                        end
                      case matlabshared.hwsdk.internal.InterfaceEnum.I2C
                        % Following check is needed for boards with I2CBus1 where we don't expose I2CBus1 pins to the users. eg: Nano33BLE.
                        % And for Arduino Due we expose I2C Bus 1 pins D70 and D71 to the users, so this if condition must go through
                        % for both I2CBus0 and I2CBus1. See g2652246 for more details.
                        if strcmp(obj.Board, 'Nano33BLE') && ...
                                ~isempty(p.Results.Pin) && ...
                                all(ismember([p.Results.Pin{:}], obj.getI2CTerminals(1)))
                            % If the pins matched with Bus1 pins of
                            % Nano33BLE, don't configure them.
                            isPinConfigurable = false;
                        else
                            isPinConfigurable = true;
                        end

                      otherwise
                        isPinConfigurable = true;
                    end
                end
            end
        end
    end

    methods(Access = {?matlabshared.hwsdk.internal.base,?matlabshared.sensors.sensorBase})
        % Hardware inherits following I2C method to modify the object disp
        function showI2CProperties(obj, Interface, I2CAddress, Bus, SCLPin, SDAPin, BitRate, showAll)
            if nargin < 2
                showAll = 0;
            end

            [stackTrace, ~] = dbstack('-completenames');
            functionNames = {stackTrace(:).name};
            fromSensor = any(contains(functionNames,{'sensorUnit', 'sensorBoard'}));

            if fromSensor
                % Order: Interface, I2CAddress, Bus, Pins (string)
                if showAll
                    fprintf('             Interface: "%s"\n', Interface);
                end
                for i = 1:numel(I2CAddress)
                    if 1 == i
                        fprintf('            I2CAddress: %-1d ("0x%s")\n', I2CAddress(i), dec2hex(I2CAddress(i)));
                    else
                        fprintf('                      : %-1d ("0x%s")\n',I2CAddress(i), dec2hex(I2CAddress(i)));
                    end
                end
                if showAll
                    fprintf('                   Bus: %d\n', Bus);
                end
                if strcmp(obj.Board, 'Due') && (Bus == 1)
                    fprintf('                SCLPin: "SCL1"\n');
                    fprintf('                SDAPin: "SDA1"\n');
                else
                    fprintf('                SCLPin: "%s"\n', SCLPin);
                    fprintf('                SDAPin: "%s"\n', SDAPin);
                end
            else
                % Order: Interface, I2CAddress, Bus, Pins (char)
                if showAll
                    fprintf('             Interface: ''%s''\n', Interface);
                end
                fprintf('            I2CAddress: %-1d (''0x%02s'')\n', I2CAddress, dec2hex(I2CAddress));
                if showAll
                    fprintf('                   Bus: %d\n', Bus);
                end
                if strcmp(obj.Board, 'Due') && (Bus == 1)
                    fprintf('                SCLPin: ''SCL1''\n');
                    fprintf('                SDAPin: ''SDA1''\n');
                else
                    fprintf('                SCLPin: ''%s''\n', SCLPin);
                    fprintf('                SDAPin: ''%s''\n', SDAPin);
                end
            end

            if showAll
                fprintf('               BitRate: %d (bits/s)\n', BitRate);
            end

            fprintf('\n');
        end
    end

    methods(Access = {?matlabshared.hwsdk.controller, ?matlabshared.hwsdk.internal.connections.ConnectionController})
        function list = getBleListHook(~,varargin)
            assert(nargin >= 1);
            if(nargin == 2)
                if ismac % On mac, blelist with service UUID doesnt contains empty name field
                    list = blelist('Services', arduinoio.internal.ArduinoConstants.ServiceUUID,'Timeout',varargin{1});
                else
                    list = blelist('Timeout',varargin{1});
                end
            else
                if ismac % On mac, blelist with service UUID doesnt contains empty name field
                    list = blelist('Services',arduinoio.internal.ArduinoConstants.ServiceUUID);
                else
                    list = blelist;
                end
            end
        end

        function emulatorPortStatus = portEmulatorAvailableHook(~, address)
        % Method to validate the pseudo serial terminal ports specified
        % as 'address'. e.g. port can be /dev/pts/55
        % Setting the default status to false for physical serial ports
            emulatorPortStatus = false;
            % Pseudo port validation is limited to Linux platform
            % Check if a preference named 'HostIOServerEnabled' exists
            % under the pref group MATLAB_HARDWARE. Validation proceeds once
            % the hostIOServerEnabled is found and is true
            if isunix && ~ismac && ispref('MATLAB_HARDWARE', 'HostIOServerEnabled')
                if any(true(getpref('MATLAB_HARDWARE', 'HostIOServerEnabled')))
                    cmd = 'ls /dev/pts';
                    [~, result] = system(cmd);
                    fields = textscan(result, '%s');
                    portIndex = strfind(address, '/');
                    % validateTransport calls this function for all transport types
                    % matching port will be found only for serial transport
                    % emulatorPortStatus should be true only if a matching port is found
                    if ~isempty(portIndex)
                        ptsPort = extractAfter(address, portIndex(end));
                        matchingPort = cellfun(@(x)strcmpi(x, ptsPort), fields, 'UniformOutput', false);
                        if any(matchingPort{1})
                            emulatorPortStatus = true;
                        end
                    end
                end
            end
        end

        function inputParserErrorHook(obj,e)
        % Hardware spkg can override this hook to catch additional
        % errors while parsing user inputs and throw error messages specific to arduino class

            switch e.identifier
              case 'MATLAB:InputParser:ArgumentFailedValidation'
                message = e.message;
                index = strfind(message, '''');
                str = message(index(1)+1:index(2)-1);

                if ismember(str,{'AnalogReference', 'BaudRate'})
                    obj.localizedError('MATLAB:arduinoio:general:invalidDoubleTypePos',str);
                elseif strcmpi(str,'AnalogReferenceMode')
                    obj.localizedError('MATLAB:arduinoio:general:invalidCharacterType',str);
                end
              otherwise
                throwAsCaller(e);
            end
        end

        function unmatchedCustomParamsErrorHook(obj,param)
        % Display all valid name value pairs in the error message
            obj.localizedError('MATLAB:hwsdk:general:invalidParam', param, upper(class(obj)), 'are ''Libraries'', ''AnalogReference'', ''AnalogReferenceMode'',');
        end

        function parseCustomNameValueParametersHook(obj, inputparserObj)
        % Overriding parseCustomNameValueParametersHook(obj, inputparserObj)
        % from matlabshared.hwsdk.controller.
        % Fetches the result of parsing ArduinoCLIPath for further
        % use.
            if isdeployed()
                obj.ArduinoCLIPath = inputparserObj.Results.ArduinoCLIPath;
            end

            obj.AnalogReference = inputparserObj.Results.AnalogReference;

            % If user doesn't provide the 'AnalogReferenceMode' name value
            % pair, it will be initialized as null and the 'AnalogReferenceMode'
            % property value would be initialized as ''
            if strcmpi(inputparserObj.Results.AnalogReferenceMode,'null')
                obj.AnalogReferenceMode = '';
            elseif strcmpi(inputparserObj.Results.AnalogReferenceMode,'')

                % If user provides 'AnalogReferenceMode' value as empty
                % character array '' or empty string "", an error should be
                % thrown.
                obj.localizedError('MATLAB:arduinoio:general:emptyAnalogReferenceModeValue','AnalogReferenceMode');
            else
                obj.AnalogReferenceMode = char(inputparserObj.Results.AnalogReferenceMode);
            end

            % Enabling the 'MATLAB:InputParser:AmbiguousParameter' warning
            % after a disable warning command has been called in
            % addCustomNameValueParametersHook
            warning('on','MATLAB:InputParser:AmbiguousParameter');
        end

        function connection = serialHook(obj, varargin)
            narginchk(2, 2);
            baudRate = num2str(obj.BaudRate);
            port = varargin{1};
            timeOut = '10';
            % TODO The RemoteUtilities does not support MATLAB
            % compiler deployment yet, need to remove the %#exclude
            % below and isdeployed once g3238819 is resolved
            %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
            if ~isdeployed && matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
                % Create pseudo terminal to access the port with specific
                % baudrate for MATLAB Online
                % TODO: Need to confirm (g3203214)
                % 1. Whether running createVirtualSerialPort with a
                % different baudrate is going to reset it for port which is
                % already requested?
                % 2. If not, is there any other way to modify the baud rate on the
                % virtual port already created
                % 3. Whether createVirtualSerialPort on the same remote
                % port always returns the same port ID for the same MATLAB
                % Online session?
                startupDelay = 3; % Delay in seconds between port connect and first access attempt
                useDedicatedTransport = true;
                remoteUtils = matlabshared.remoteconnectivity.internal.RemoteUtilities();

                % Create a virtual port for the real port on the user's
                % machine. VirtualSerialPortObj struct contains the name of the
                % virtual port that will be further used to communicate
                % with the real hardware. VirtualSerialPortObj need not be
                % persisted. The virtual port will exist regardless of the
                % VirtualSerialPortObj object. It can be opened and closed
                % any number of times. The lifetime of the virtual port is
                % managed by the infrastructure, no need to hold on to the
                % VirtualSerialPortObj to keep the virtual port alive.
                VirtualSerialPortObj = remoteUtils.createVirtualSerialPort(obj.Port, ...
                                                                           baudRate, startupDelay, useDedicatedTransport);
                actualPort = VirtualSerialPortObj.virtualComport;
            else
                actualPort = port;
            end
            connection = matlabshared.ioclient.transport.TransportLayerUtility.getTransportLayer('serial', actualPort, 'BaudRate', baudRate, 'TimeOut', timeOut);
        end

        function connection = tcpClientHook(obj, deviceAddress, port)
            try
                port = char(string(port));
                connection = matlabshared.ioclient.transport.TransportLayerUtility.getTransportLayer('tcpclient',deviceAddress,port);
            catch
                obj.localizedError('MATLAB:hwsdk:general:openFailed', strcat('IP address:',deviceAddress,' , Port:',port,' , Board:'), char(getBoardNameHook(obj)));
            end
        end

        function connection = bluetoothHook(~, deviceAddress, channel)
            if contains(deviceAddress, 'btspp://')
                % stripping off 'btspp://' as the new
                % 'bluetooth' accepts only numeric address
                deviceAddress = upper(deviceAddress(9:end));
            end
            connection = matlabshared.ioclient.transport.TransportLayerUtility.getTransportLayer('bluetooth', deviceAddress, channel);
        end

        function connection = blePeripheralHook(~,deviceAddress)
        % Create connection between IOServer ble client and hwsdk
            connection = matlabshared.ioclient.transport.TransportLayerUtility.getTransportLayer('ble',deviceAddress,'ServiceUUID',char(arduinoio.internal.ArduinoConstants.ServiceUUID),'WriteCharacteristicUUID',char(arduinoio.internal.ArduinoConstants.WriteCharacteristicUUID),'ReadCharacteristicUUID',char(arduinoio.internal.ArduinoConstants.ReadCharacteristicUUID));
        end

        function addCustomNameValueParametersHook(~, inputparserObj)
        % Overriding addCustomNameValueParametersHook(obj, inputparserObj)
        % from matlabshared.hwsdk.controller.
        % Adds ArduinoCLIPath to be parsed with other HWSDK
        % parameters.
            if isdeployed()
                addParameter(inputparserObj, 'ArduinoCLIPath', '');
            end

            %Analog Reference must be be a scalar numeric value
            validationfcn = @(x)isnumeric(x)&&isscalar(x);
            addParameter(inputparserObj, 'AnalogReference', [], validationfcn,'PartialMatchPriority',1);

            %Analog Reference Mode must be be a character array or string
            validationfcn = @(x)ischar(x)||isStringScalar(x);

            %Adding default value as null to differentiate between when
            %user enters the value as an emtpy character array '',or when he
            %doesnt provide any value. The default values are being used to
            %determine when to throw error in
            %parseCustomNameValueParametersHook method
            addParameter(inputparserObj, 'AnalogReferenceMode', 'null',validationfcn,'PartialMatchPriority',2);

            % Turn off 'MATLAB:InputParser:AmbiguousParameter' warning
            % when there is an ambiguity in the name value pair names
            % during input parser's partial matching in hwsdk.controller, like
            % AnalogReference and AnalogReferenceMode for Arduino I/O APIs.
            warning('off','MATLAB:InputParser:AmbiguousParameter');
        end

        function validateCustomParamsHook(obj, CustomParams, validParameters)
        % CustomParams for Arduino is the board name
            if isstring(CustomParams) || ischar(CustomParams)
                CustomParams = cellstr(CustomParams);
            end
            % Error out if the CustomeParam belongs to validParameters - TraceOn, ForceBuildOn, etc.
            validParamAvailable = strncmpi(CustomParams, validParameters, numel(cell2mat(CustomParams)));
            validParamAvailableIndex = find(validParamAvailable == 1, 1);
            if ~isempty(validParamAvailableIndex)
                obj.localizedError('MATLAB:hwsdk:general:paramNotInPairs');
            end
        end
    end

    methods (Access = ?matlabshared.hwsdk.internal.base)
        function [Pin, Terminal, Mode, ResourceOwner] = getPinInfoHook(obj, pin)
            [Pin, Terminal, Mode, ResourceOwner] = getPinInfo(obj.ResourceManager, obj, pin);
        end

        function compatibleModes = getCompatibleModesHook(~, mode)
        % A hardware may allow operations when the pin is configured to
        % some other mode. Those are called compatible modes. HSP can
        % provide if there is such a case.
        % INPUTS:
        %   obj - matlabshared.dio.controller
        %   mode - HSP must provide modes that are compatible with this
        % OUTPUTS:
        %   compatibleModes - string array of modes that are compatible
        %   with mode mentioned above.
            switch(mode)
              case 'DigitalOutput'
                compatibleModes = "PWM";
              case 'PWM'
                compatibleModes = "DigitalOutput";
              case 'AnalogInput'
                compatibleModes = ["DigitalInput", "Pullup"];
              case 'DigitalInput'
                compatibleModes = ["AnalogInput", "Pullup"];
              case 'Pullup'
                compatibleModes = ["AnalogInput", "DigitalInput"];
              otherwise
                compatibleModes = string.empty();
            end
        end

        function spiBusAlias = getSPIBusAliasImpl(~, bus, ~)
            spiBusAlias = bus-1;
        end
    end
end

% LocalWords:  Aref hwsdk arduinoio vid matlabshared addon mysensors mhz
% LocalWords:  baudrate avrfreaks nano LF maxlhs Uno isstring dio randi adc pwm
% LocalWords:  spi SCL ICSP SDI SDO Bluetooth Wi Addon's CIs IOSERVER CUsed
% LocalWords:  GPIO Pullup arduino's pid
