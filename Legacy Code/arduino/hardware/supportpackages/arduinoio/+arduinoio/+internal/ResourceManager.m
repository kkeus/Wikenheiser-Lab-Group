classdef (Hidden,Sealed) ResourceManager < matlabshared.hwsdk.internal.base
%   RESOURCEMANAGER Manages resources based on board type

%   Copyright 2014-2023 The MathWorks, Inc.

    properties (SetAccess = private, GetAccess = {?arduino,?arduino.accessor.UnitTest,?matlab.hwmgr.providers.ArduinoDeviceProvider,...
                                                  ?arduinoioapplet.modules.interfaces.ArduinoManager})
        Board
        BoardName
        Package
        CPU
        MemorySize
        BaudRate
        MCU
        VIDPID
        NumTerminals
        TerminalsDigital
        TerminalsAnalog
        TerminalsDigitalAndAnalog
        TerminalsPWM
        TerminalsServo
        TerminalsI2C
        TerminalsInterrupt
        ICSPSPI
        TerminalsSPI
        TerminalsSerial

        AnalogPinModes
        DigitalPinModes

        % Array structure of terminals (absolute pin numbers) used to track
        % status of each resource.
        Terminals
        ResourceMap
        NonMegaReservedTonePins = {'D3', 'D11'};
    end
    properties (Access = private)
        isSerialAvailableDue = ones(1, 3); % there are 3 Serial Ports on Due
    end

    methods
        function obj = ResourceManager(boardType)
            b = arduinoio.internal.BoardInfo.getInstance();
            try
                % workaround to throw ambiguousBoardName error for partial
                % board names for Nano. Remove once g2177358 fixed
                boardTypeVal = upper(boardType);
                if ismember(boardTypeVal,{'N','NA','NAN','NANO'})
                    matchedBoards = {'Nano3','Nano33IoT','Nano33BLE'};
                    obj.localizedError('MATLAB:hwsdk:general:ambiguousBoardName', boardType, strjoin(matchedBoards, ', '));
                end
                boardType = validatestring(boardType, {b.Boards.Name});
            catch e
                switch (e.identifier)
                  case 'MATLAB:ambiguousStringChoice'
                    matches = strfind(lower({b.Boards.Name}), lower(boardType));
                    matchedBoards = {};
                    for ii = 1:numel(matches)
                        if ~isempty(matches{ii}) && matches{ii}(1)==1
                            matchedBoards = [matchedBoards, b.Boards(ii).Name]; %#ok<AGROW>
                        end
                    end
                    obj.localizedError('MATLAB:hwsdk:general:ambiguousBoardName', boardType, strjoin(matchedBoards, ', '));
                  case 'MATLAB:hwsdk:general:ambiguousBoardName'
                    % workaround to throw ambiguousBoardName error for partial
                    % board names for Nano. Remove once g2177358 fixed
                    throwAsCaller(e);
                  otherwise
                    obj.localizedError('MATLAB:hwsdk:general:invalidBoardName', boardType, ...
                                       matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector({b.Boards.Name}, ', '));
                end
            end
            idx = find(arrayfun(@(x) strcmp(x.Name, boardType), b.Boards), 1);
            if isempty(idx)
                obj.localizedError('MATLAB:hwsdk:general:invalidBoardName', boardType, ...
                                   matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector({b.Boards.Name}, ', '));
            end

            obj.Board            = b.Boards(idx).Name;
            obj.BoardName        = b.Boards(idx).BoardName;
            obj.Package          = b.Boards(idx).Package;
            obj.CPU              = b.Boards(idx).CPU;
            obj.MemorySize       = b.Boards(idx).MemorySize;
            obj.MCU              = b.Boards(idx).MCU;
            obj.VIDPID           = b.Boards(idx).VIDPID;
            obj.NumTerminals     = b.Boards(idx).NumPins;
            obj.TerminalsDigital = b.Boards(idx).PinsDigital;
            obj.TerminalsAnalog  = b.Boards(idx).PinsAnalog;

            obj.TerminalsDigitalAndAnalog = intersect(obj.TerminalsDigital, obj.TerminalsAnalog);
            obj.TerminalsAnalog  = setdiff(obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog);
            obj.TerminalsPWM     = b.Boards(idx).PinsPWM;
            obj.TerminalsServo   = b.Boards(idx).PinsServo;
            obj.TerminalsI2C     = b.Boards(idx).PinsI2C;
            obj.TerminalsInterrupt= b.Boards(idx).PinsInterrupt;
            obj.ICSPSPI          = b.Boards(idx).ICSPSPI;
            obj.TerminalsSPI     = b.Boards(idx).PinsSPI;

            if ismember(obj.Board,arduinoio.internal.ArduinoConstants.SerialLibrarySupportBoards)
                obj.TerminalsSerial = b.Boards(idx).PinsSerial;
            end

            % Define a structure for terminal data
            terminals.Mode = 'Unset';
            terminals.ResourceOwner = '';

            % Arduino pins are zero based. Use the getTerminalMode() method to
            % access this array with correct pin indexing.
            %
            obj.Terminals = repmat(terminals, 1, obj.NumTerminals);
            obj.Terminals(1).Mode = 'Rx';
            obj.Terminals(2).Mode = 'Tx';

            if isTerminalAnalog(obj, obj.TerminalsI2C(1))
                obj.AnalogPinModes = {'DigitalInput', 'AnalogInput', 'DigitalOutput', 'Pullup', 'I2C', 'SPI', 'Servo', 'Ultrasonic', 'CAN', 'Unset'};
                obj.DigitalPinModes = {'DigitalInput', 'DigitalOutput', 'Pullup', 'PWM', 'Servo', 'SPI', 'Interrupt', 'Ultrasonic', 'CAN', 'Unset'};
            else
                obj.AnalogPinModes = {'DigitalInput', 'AnalogInput', 'DigitalOutput', 'Pullup', 'SPI', 'Servo', 'Ultrasonic', 'CAN', 'Unset'};
                obj.DigitalPinModes = {'DigitalInput', 'DigitalOutput', 'Pullup', 'PWM', 'Servo', 'SPI', 'I2C', 'Interrupt', 'Ultrasonic', 'CAN', 'Unset'};
            end

            % Tone supported only on AVR,cortex-m0plus and cortex-m4
            if contains(obj.MCU,'atmega')
                obj.DigitalPinModes = ['Tone', obj.DigitalPinModes];
                obj.AnalogPinModes = ['Tone',  obj.AnalogPinModes];
            end

            if ismember(obj.MCU,{'cortex-m4','cortex-m0plus'})
                obj.DigitalPinModes = ['Tone', obj.DigitalPinModes];
                obj.AnalogPinModes = ['Tone',  obj.AnalogPinModes];
            end

            % Serial peripheral supported only on Mega2560,MegaADK, Due,
            % MKR1000,MKR1010, MKRZero, Nano33IoT, Nano33BLE, Leonardo, Micro, and ESP32
            if ismember(obj.MCU, {'atmega2560','cortex-m3', 'cortex-m0plus','cortex-m4','atmega32u4','esp32'})
                obj.DigitalPinModes = ['Serial', obj.DigitalPinModes];
            end

            % Special cases
            switch obj.MCU
              case 'atmega32u4'
                % Some Micro and Leonardo digital pins can be analog(aliasing)
                obj.DigitalPinModes = ['AnalogInput', obj.DigitalPinModes];

                % added to fix g2154643. This ensures pinHandleMaps for all alias pins are
                % initialized properly
                addprop(obj,'BoardPinMap');
                obj.BoardPinMap = containers.Map({'A6','A7','A8','A9','A10','A11'},{'D4','D6','D8','D9','D10','D12'});
                % Configure the pins D0 and D1 on Leoanrdo and Micro to
                % 'Unset' when arduino object is created
                obj.Terminals(1).Mode = 'Unset';
                obj.Terminals(2).Mode = 'Unset';
              case 'esp32'
                obj.DigitalPinModes = ['AnalogInput', obj.DigitalPinModes];
                p = addprop(obj,'PWMServoArray');
                p.SetAccess = 'protected';
                p.GetAccess = 'protected';
              case 'cortex-m3'
                obj.AnalogPinModes = ['Interrupt', obj.AnalogPinModes];
              case {'cortex-m0plus','cortex-m4'}
                obj.AnalogPinModes = ['Interrupt', 'PWM', obj.AnalogPinModes];
                % D0 and D1 are not used by USB over CDC for host client communication
                obj.Terminals(1).Mode = 'Unset';
                obj.Terminals(2).Mode = 'Unset';
            end


            % ResourceMap
            obj.ResourceMap = containers.Map;
        end
    end

    %% Friend methods
    %
    %
    methods (Access = {?arduino, ?arduinoio.setup.internal.HardwareInterface, ?arduinoio.internal.TabCompletionHelper, ?arduino.accessor.UnitTest,...
                       ?arduinoioapplet.modules.interfaces.ArduinoManager})

        function result = validateTerminalSupportsTerminalMode(obj, terminal, mode)
        % writePWMVoltage(a, 'A2', 3)
        % To catch the wrong pin in the above function call and not
        % just throw the error of invalidPinMode, this validation needs
        % to be done first. However, the mode, since not checked yet,
        % needs to be corrected if needed as below
            try
                mode = validateTerminalMode(obj, isTerminalDigital(obj, terminal), mode);
            catch e
                % When the above validation fails, it is either due to one
                % of the two causes:
                % - 'MATLAB:hwsdk:general:invalidPinMode'
                % mode is not a valid mode for either digital or analog
                % pins
                % - 'MATLAB:hwsdk:general:notSupportedPinMode'
                % mode is a valid mode, but not for the subsystem the
                % terminal belongs to
                % Only change the mode to 'Unset' for the first case such
                % that it is a mode that is supported on all pins to pass
                % this validation
                %
                if strcmp(e.identifier, 'MATLAB:hwsdk:general:invalidPinMode')
                    mode = 'Unset';
                end
            end

            validTerminals = [obj.TerminalsDigital, obj.TerminalsAnalog];
            switch mode
              case 'AnalogInput'
                validTerminals = [obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog];
              case 'PWM'
                validTerminals = obj.TerminalsPWM;
              case 'Servo'
                validTerminals = obj.TerminalsServo;
              case 'I2C'
                validTerminals = obj.TerminalsI2C;
              case 'SPI'
                validTerminals = obj.TerminalsSPI;
              case 'Serial'
                validTerminals = obj.TerminalsSerial;
              case {'DigitalOutput', 'DigitalInput', 'Ultrasonic'}
                if strcmpi(obj.MCU, 'atmega328p')
                    % On atmega328p boards, pins beyond 19 are analog Only
                    % these cannot be configured as Digital IO and hence
                    % cannot work in Ultrasonic mode as well
                    validTerminals = validTerminals(validTerminals<20);
                elseif ismember(obj.MCU,{'esp32'}) && strcmpi(mode,'DigitalOutput')
                    validTerminals = setdiff(validTerminals,arduinoio.internal.ArduinoConstants.ESP32InputOnlyTerminals,'stable');
                elseif ismember(obj.MCU,{'esp32'}) && strcmpi(mode,'DigitalInput')
                    validTerminals = setdiff(validTerminals,arduinoio.internal.ArduinoConstants.ESP32OutputOnlyTerminals,'stable');
                end
              case 'Interrupt'
                validTerminals = obj.TerminalsInterrupt;
              case 'Pullup'
                if strcmpi(obj.Board, 'Nano3') || strcmpi(obj.Board, 'ProMini328_5V') || strcmpi(obj.Board, 'ProMini328_3V')
                    % A6 and A7 pins on Nano3 are analog only, they
                    % cannot be used in Pullup mode since there are no
                    % pullup resistors available on these pins
                    validTerminals = setdiff(validTerminals, arduinoio.internal.ArduinoConstants.Nano3AndProMiniAnalogOnlyTerminals, 'stable');
                elseif ismember(obj.MCU,{'esp32'})
                    % D34-D39 ESP32-WROOM-DevKitV1 and ESP32-WROOM-DevKitC are input only, they
                    % cannot be used in Pullup mode since there are no
                    % pullup resistors available on these pins
                    validTerminals = setdiff(validTerminals,arduinoio.internal.ArduinoConstants.ESP32InputOnlyTerminals,'stable');
                end
              otherwise
                % DigitalInput, DigitalOutput, Pullup, and Unset are supported by all
                % pins.
            end

            switch mode
              case 'Unset'
                pinType = '';
              otherwise
                pinType = mode;
            end

            % A4 and A5 pins on Nano33IoT and Nano33BLE boards are not considered as Analog
            if strcmpi(mode, 'AnalogInput') && ismember(obj.Board, {'Nano33IoT','Nano33BLE'}) && ismember(obj.getPinsFromTerminals(terminal), {'A4','A5'})
                validPins = obj.getPinsFromTerminals(obj.TerminalsAnalog);
                validPins = setdiff(validPins, {'A4','A5'});
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', obj.Board, pinType, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
            end

            if ~ismember(terminal, validTerminals)
                if strcmp(mode, 'SPI') && isempty(validTerminals)
                    validPins = {'none'};
                else
                    validPins = obj.getPinsFromTerminals(validTerminals);
                end
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', obj.Board, pinType, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
            end
            result = double(terminal);
        end

        function varargout = configurePin(obj, pin, resourceOwner, mode, forceConfig)
        % Work with absolute microcontroller pin numbers (terminals)
            terminal = getTerminalsFromPins(obj, pin);
            if nargout > 0
                if nargin ~= 2
                    error('Internal Error: configurePin invalid number of input arguments');
                end
                terminal = validateTerminalSupportsTerminalMode(obj, terminal, 'Unset');
                varargout = {obj.getTerminalMode(terminal)};
                return;
            end

            %% Validate input parameter types
            % accept string type mode but convert to character vector
            if isstring(mode)
                mode = char(mode);
            end
            terminal = validateTerminalSupportsTerminalMode(obj, terminal, mode);
            mode = validateTerminalMode(obj, isTerminalDigital(obj, terminal), mode);

            if strcmpi(obj.BoardName,'MKRZero') && strcmpi(pin,"D32") && (~strcmpi(mode,'DigitalOutput') || ~strcmpi(mode,'Unset')) && ~isempty(resourceOwner)
                %MKRZero Pin 32 is connected to led pin and is not
                %available on breakout. Therefore, supported mode for this
                %pin is 'DigitalOutput' only
                if isempty(resourceOwner)
                    obj.localizedError('MATLAB:hwsdk:general:notSupportedPinMode', ...
                                       mode, ...
                                       matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector({'DigitalOutput'}, ', '));
                else
                    obj.localizedError('MATLAB:hwsdk:general:invalidResourceownerName',char(resourceOwner),char(pin));
                end
            end

            % Special Case for Arduino Due board D70 and D71 Pins (I2CBus1)
            % D70 and D71 pins are can only be configured to I2C, DigitalInput, DigitalOutput, Ultrasonic and Unset modes.
            if strcmpi(obj.Board,'Due') && ismember(char(pin),{'D70','D71'}) && ~ismember(mode,{'I2C','DigitalOutput','DigitalInput','Ultrasonic','Unset'})
                if isempty(resourceOwner)
                    obj.localizedError('MATLAB:hwsdk:general:notSupportedPinMode', ...
                                       mode, ...
                                       matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector({'I2C','DigitalOutput','DigitalInput','Ultrasonic','Unset'}, ', '));
                else
                    obj.localizedError('MATLAB:hwsdk:general:invalidResourceownerName',char(resourceOwner),char(pin));
                end
            end

            try
                validateattributes(forceConfig, {'logical'}, {'scalar'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidForceConfig');
            end

            try
                validateattributes(resourceOwner, {'char', 'string'}, {'scalartext'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidResourceOwnerType');
            end
            % accept string type resourceOwner but convert to character vector
            if isstring(resourceOwner)
                resourceOwner = char(resourceOwner);
            end

            %% Only the resource owner may make changes to a terminal configuration.
            resourceOwner = obj.validateResourceOwner(terminal, resourceOwner, mode);
            %% Serial on Due case : configured to Digital I/Os during the life of this arduino object
            if strcmpi(obj.Board, 'Due') && ~strcmpi(mode, 'Unset')
                serialTerminalsDue =  getSerialTerminals(obj);
                if ismember(terminal, serialTerminalsDue)
                    portIndex = ceil((terminal - serialTerminalsDue(1) + 1)/2);
                    % Flag the unconfigurable port number
                    if ismember(mode, {'DigitalInput', 'DigitalOutput', 'Pullup'})
                        obj.isSerialAvailableDue(portIndex) = 0;
                    end
                    % Check if Due's serial pins are blocked by digital modes
                    if strcmpi(mode, 'Serial') && isequal(obj.isSerialAvailableDue(portIndex), 0)
                        obj.localizedError('MATLAB:hwsdk:general:serialConfigFailed');
                    end
                end
            end

            %% Special case - SPI
            % configurePin cannot change a pin's mode from SPI to
            % anything else if SPI objects exists in MATLAB
            prevMode = obj.getTerminalMode(terminal);
            if strcmp(prevMode, 'SPI')
                spiTerminals = getSPITerminals(obj);
                if ismember(terminal, spiTerminals) && ~strcmp(prevMode, mode) && getResourceCount(obj, 'SPI')
                    pin = obj.getPinsFromTerminals(terminal);
                    obj.localizedError('MATLAB:hwsdk:general:reservedSPIPins', obj.Board, pin{1});
                end
            end
            %% Special case - I2C
            % configurePin cannot change a pin's mode from I2C to
            % anything else if I2C objects exists in MATLAB
            if strcmp(prevMode, 'I2C')
                busNum = numel(obj.TerminalsI2C)/2;
                % Scan through all I2C bus
                for idx=0:busNum-1
                    % Get respective I2C terminals for given I2C bus
                    i2cTerminalsBus = getI2CTerminals(obj,idx);
                    resourceOwnerDevice = char(strcat('I2CBus',string(idx)));
                    if ismember(terminal, i2cTerminalsBus) && ~strcmp(prevMode, mode) && getResourceCount(obj,resourceOwnerDevice)
                        pin = obj.getPinsFromTerminals(terminal);
                        obj.localizedError('MATLAB:hwsdk:general:reservedResource', obj.Board, pin{1},resourceOwnerDevice,prevMode);
                    end
                end
            end
            %%  Special case - Serial
            % configurePin cannot change a pin's mode from Serial to
            % anything else if Serial objects exists in MATLAB
            if strcmp(prevMode, 'Serial')
                portNum = numel(obj.TerminalsSerial)/2;
                for i=1:portNum
                    serialTerminalsPort = getSerialTerminals(obj,i);
                    if ismember(terminal, serialTerminalsPort) && ~strcmp(prevMode, mode) && getResourceCount(obj,'Serial')
                        pin = obj.getPinsFromTerminals(terminal);
                        obj.localizedError('MATLAB:hwsdk:general:reservedResource', obj.Board, pin{1},resourceOwnerDevice,prevMode);
                    end
                end
            end


            %% Check if the terminal is already in the requested target mode
            if strcmp(prevMode, mode)
                obj.updateResource(terminal, resourceOwner, mode);
                return;
            end


            %% Validate terminal mode conversion is compatible with previous
            % terminal mode
            if ~forceConfig
                obj.validateCompatibleTerminalModeConversion(terminal, mode);
            end

            if ismember(obj.Board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}) && ismember(prevMode,{'PWM','Servo'})
                obj.localizedError('MATLAB:arduinoio:general:cannotChangePinConfig',char(pin),obj.Board,prevMode);
            end

            if ismember(obj.Board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}) && ismember(mode,{'PWM','Servo','Unset'})
                %ESP32 WROOM only total of 16 PWM+Servos can be configured at
                %any point
                sizePWMServoArray = size(obj.PWMServoArray);
                if ~strcmpi(mode,'Unset') && any(~ismember(char(pin), obj.PWMServoArray)) && sizePWMServoArray(2)<arduinoio.internal.ArduinoConstants.MaxPWMServoESP32 % trying to set mode to PWM or Servo
                    obj.PWMServoArray = [obj.PWMServoArray {char(pin)}]; % allow configuring this pin to Servo/PWM and add to array
                elseif  ismember(mode,{'PWM','Servo'})% Max limit for Servo+PWM pins reached and user is trying to set mode to PWM or Servo throw error
                    obj.localizedError('MATLAB:arduinoio:general:maxServosPWMESP32',obj.Board,char(num2str(arduinoio.internal.ArduinoConstants.MaxPWMServoESP32)));
                end
            end
            %configure all Pins of a pingroup to specified mode(I2C/SPI/Serial) or
            %single pin to the new mode (or Unset)
            %after validating that it is a valid pin mode conversion
            if strcmpi(mode,'I2C') ||(strcmpi(prevMode,'I2C') && strcmpi(mode,'Unset'))
                busNum = numel(obj.TerminalsI2C)/2;
                if forceConfig
                    for i=0:busNum-1
                        i2cTerminalsBus = getI2CTerminals(obj,i);
                        if any(ismember(i2cTerminalsBus,terminal))
                            for j=1:numel(i2cTerminalsBus)
                                obj.applyFilterTerminalModeChange(i2cTerminalsBus(j), resourceOwner, mode, forceConfig);
                            end
                            break;
                        end
                    end
                else
                    %To resolve issue in  g2038911 not configuring both I2C
                    %pins if device tries to acquire these resources so
                    %that correct error is thrown for SCLPin as well if it
                    %is reserved in another mode earlier and it is not 'Unset'
                    %on device object creation failure
                    obj.applyFilterTerminalModeChange(terminal, resourceOwner, mode, forceConfig);
                end
            elseif strcmpi(mode,'Serial') ||(strcmpi(prevMode,'Serial') && strcmpi(mode,'Unset'))
                if ismember(obj.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                    portNum = 2;
                else
                    portNum = numel(obj.TerminalsSerial)/2;
                end
                if forceConfig
                    for i=1:portNum
                        serialTerminalsPort = getSerialTerminals(obj,i);
                        if any(ismember(serialTerminalsPort,terminal))
                            for j=1:numel(serialTerminalsPort)
                                obj.applyFilterTerminalModeChange(serialTerminalsPort(j), resourceOwner, mode, forceConfig);
                            end
                            break;
                        end
                    end
                else
                    %To resolve issue in  g2043856 not configuring both Serial
                    %pins if device tries to acquire these resources so
                    %that correct error is thrown for SCLPin as well if it
                    %is reserved in another mode earlier and it is not 'Unset'
                    %on device object creation failure
                    obj.applyFilterTerminalModeChange(terminal, resourceOwner, mode, forceConfig);
                end
            elseif strcmpi(mode,'SPI') || (strcmpi(prevMode,'SPI') && strcmpi(mode,'Unset'))
                spiTerminals = obj.TerminalsSPI;
                % Validate if all of spi terminals are free for
                % configuration
                for i=1:numel(spiTerminals)
                    obj.validateCompatibleTerminalModeConversion(spiTerminals(i), mode);
                end
                % Apply the configuration
                for i=1:numel(spiTerminals)
                    obj.applyFilterTerminalModeChange(spiTerminals(i), resourceOwner, mode, forceConfig);
                end
            elseif strcmpi(prevMode, 'Tone') && strcmpi(mode, 'Unset')
                % Unconfigure Tone pin.
                obj.applyFilterTerminalModeChange(terminal, resourceOwner, mode, forceConfig);
                % Unreserve D3 and D11 reserved by Tone
                for i = 1:numel(obj.NonMegaReservedTonePins)
                    % Do nothing if pin to be unreserved is
                    % same as the tone pin because it is
                    % already unconfigured.
                    if ~strcmp(pin, obj.NonMegaReservedTonePins{i})
                        resTerminal = getTerminalsFromPins(obj, obj.NonMegaReservedTonePins{i});
                        resOwner = getResourceOwner(obj, resTerminal);
                        obj.applyFilterTerminalModeChange(resTerminal, resOwner, mode, true);
                    end
                end
            else
                % Apply new terminal mode (if applicable)
                obj.applyFilterTerminalModeChange(terminal, resourceOwner, mode, forceConfig);
            end
        end

        function buildInfo = getBuildInfo(obj)
            buildInfo.Board         = obj.Board;
            buildInfo.BoardName     = obj.BoardName;
            buildInfo.Package       = obj.Package;
            buildInfo.CPU           = obj.CPU;
            buildInfo.MemorySize    = obj.MemorySize;
            buildInfo.MCU           = obj.MCU;
            buildInfo.VIDPID        = obj.VIDPID;
        end

        function value = getTerminalMode(obj, terminal)
        % Arduino terminal numbers are zero based
            validateTerminalFormat(obj, terminal);
            value = obj.Terminals(terminal+1).Mode;
        end

        function resourceOwner = getResourceOwner(obj, terminal)
            validateTerminalFormat(obj, terminal);

            resourceOwner = '';
            r = obj.Terminals(terminal+1).ResourceOwner;
            if ~isempty(r)
                resourceOwner = r;
            end
        end

        % added to fix g2154643. This ensures pinHandleMaps for all alias pins are
        % initialized properly. The map ensures that correct terminals are returned for analog digital pins for Leonardo and Micro alias pins
        function[analogTerminal, digitalTerminal] = getAnalogPinsLeonardoMicro(obj,pin)
            % Convert pin to char vector to extract the analog pin terminal
            % from the pin. Following piece of code make use of indexing to
            % extract pin number info and it will not work if the pin is a 
            % string. Eg: pin = "A1"; pin(2:end) returns empty. See g3135288 
            % for more info.
            if isstring(pin)
                pin = char(pin);
            end
            if isKey(obj.BoardPinMap,pin)
                analogTerminal = str2double(pin(2:end));
                digitalPin = char(obj.BoardPinMap(pin));
                digitalTerminal = str2double(digitalPin(2:end));
            elseif ismember(pin, obj.BoardPinMap.values)
                digitalTerminal = str2double(pin(2:end));
                pinsArray = obj.BoardPinMap.keys;
                for i=1:obj.BoardPinMap.size(1)
                    if strcmpi(obj.BoardPinMap(char(pinsArray(i))),pin)
                        analogPin = char(pinsArray(i));
                        analogTerminal = str2double(analogPin(2:end)); % pinsArray(i);
                        break;
                    end
                end
            else
                Terminal = getTerminalsFromPins(obj,pin);
                analogTerminal = str2double(pin(2:end));
                digitalTerminal = Terminal;
            end
        end

        %% Return true or false indicating whether given terminal supports special functionality
        function result = isTerminalAnalog(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, union(obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog));
        end

        function result = isTerminalDigital(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, union(obj.TerminalsDigital, obj.TerminalsDigitalAndAnalog));
        end

        %% Get equivalent pin
        function output = getPinAlias(obj, pin)
        % Convert given pin to its equivalent pin if exists. Otherwise,
        % same pin number is returned.
        %
            validatePinFormat(obj, pin);
            terminal = getTerminalsFromPins(obj, pin);
            if ismember(terminal, obj.TerminalsDigitalAndAnalog)
                if strcmp(pin(1), 'A')
                    tAnalogPins = [obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog];
                    if isTerminalDigital(obj, tAnalogPins(str2double(pin(2:end))+1))
                        output = getPinsFromTerminals(obj, tAnalogPins(str2double(pin(2:end))+1));
                        output = output{1};
                    else
                        output = pin;
                    end
                else
                    tAnalogPins = [obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog];
                    output = find(tAnalogPins == terminal, 1);
                    if ~isempty(output) && ~ismember(obj.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                        output = ['A' num2str(output-1)];
                    else
                        output = pin;
                    end
                end
            else
                output = pin;
            end
        end

        function [Pin, Terminal, Mode, ResourceOwner] = getPinInfo(obj, parent, pin)
        % Get pin
            try
                Pin = char(validateDigitalPin(parent, pin));
            catch e
                throwAsCaller(e);
            end

            % Get terminal.
            Terminal = getTerminalsFromPins(obj, pin);

            % Get mode
            Mode = obj.Terminals(Terminal+1).Mode;

            % Get resource owner
            ResourceOwner = '';
            r = obj.Terminals(Terminal+1).ResourceOwner;
            if ~isempty(r)
                ResourceOwner = r;
            end

            Pin = string(Pin);
        end

        %% Conversions between pins and terminals
        function pins = getPinsFromTerminals(obj, terminals)
            if ~isempty(terminals)
                pins = cell(1, numel(terminals));
                for index = 1:numel(terminals)
                    theTerminal = terminals(index);
                    validateTerminalFormat(obj, theTerminal);
                    if ismember(theTerminal, obj.TerminalsDigital)
                        pins{index} = strcat('D', num2str(theTerminal));
                    elseif ismember(theTerminal, obj.TerminalsAnalog)
                        pins{index} = strcat('A', num2str(theTerminal-obj.TerminalsAnalog(1)));
                    end
                end
            else
                obj.localizedError('MATLAB:hwsdk:general:invalidTerminalType');
            end
        end

        function terminals = getTerminalsFromPins(obj, pins)
        % accept array of strings type pins, e.g [string('A3'), string('D4')]
            if isstring(pins) && ~isempty(pins) && ~isscalar(pins)
                pins = cellstr(pins);
            end
            if ~iscell(pins)
                pins = {pins};
            else
                terminals = zeros(numel(pins), 1);
            end
            for ii = 1:numel(pins)
                pin = pins{ii};

                try
                    pin = validatePinFormat(obj, pin);
                catch e
                    throwAsCaller(e);
                end

                subsystem = pin(1);
                pinSub = pin(2:end);
                % Error out if the pin contains invalid appended zeros or
                % whitespaces(see geck g2057749)
                flagError = false;
                if(~contains(pinSub, ' '))
                    % We working on char vector here, not string. So
                    % str2num cannot be replaced by str2double.
                    digitsPinSub = str2num(pinSub(:))'; %#ok<ST2NM>
                    firstNonZero = find(digitsPinSub > 0, 1, 'first'); % e.g firstNonZero = 1 for D1, empty for D00 (or D0), and >1 for D01
                    if(isempty(firstNonZero)) % e.g D0, D00, or D000
                        invalidZeroCount = numel(digitsPinSub); % a count of 1 corresponds to D0
                        flagError = invalidZeroCount > 1;        % sets the flagError to true for invalidZeroCount > 1
                    elseif(firstNonZero > 1) % e.g D01, D0012
                        flagError = true;
                    end
                    pin = str2double(pin(2:end));
                else
                    flagError = true;
                end

                if flagError
                    validPins = getPinsFromTerminals(obj, [obj.TerminalsDigital, obj.TerminalsAnalog]);
                    obj.localizedError('MATLAB:hwsdk:general:invalidPinNumber', obj.Board, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
                end

                if subsystem == 'D'
                    if ismember(pin, obj.TerminalsDigital)
                        terminal = pin;
                    else
                        validPins = getPinsFromTerminals(obj, [obj.TerminalsDigital, obj.TerminalsAnalog]);
                        obj.localizedError('MATLAB:hwsdk:general:invalidPinNumber', obj.Board, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
                    end
                else
                    try
                        analogTerminals = obj.TerminalsAnalog;
                        if ismember(obj.MCU, {'atmega32u4'})
                            analogTerminals = [obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog];
                        end
                        terminal = analogTerminals(pin + 1);
                    catch
                        validPins = getPinsFromTerminals(obj, [obj.TerminalsDigital, obj.TerminalsAnalog]);
                        obj.localizedError('MATLAB:hwsdk:general:invalidPinNumber', obj.Board, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
                    end
                end
                terminals(ii) = terminal;
            end
        end

        %% Obtain terminals with special functionality
        function terminals = getI2CTerminals(obj, bus)
            busNum = numel(obj.TerminalsI2C)/2;
            buses = 0:busNum-1;
            if nargin < 2
                bus = 0;
            else
                try
                    validateattributes(bus, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
                catch
                    obj.localizedError('MATLAB:hwsdk:general:invalidBusTypeNumeric','I2C', matlabshared.hwsdk.internal.renderArrayOfIntsToString(buses));
                end
            end
            % This check is needed because for Nano33BLE there are no user
            % exposed I2CTerminals for I2C bus 1. See g2731933 for more info.
            if ~(strcmpi(obj.BoardName, 'Nano33BLE') && (bus == 1))
                if bus > busNum-1
                    obj.localizedError('MATLAB:arduinoio:general:invalidI2CBusNumber', obj.Board, matlabshared.hwsdk.internal.renderArrayOfIntsToString(buses));
                end
                terminals = obj.TerminalsI2C(2*bus+1:2*bus+2);
            else
                terminals = ["SDA1", "SCL1"];
            end
        end

        function terminals = getSPITerminals(obj)
            if strcmpi(obj.Board, 'DigitalSandbox')
                terminals = [];
                return;
            end
            if isempty(obj.ICSPSPI) && isempty(obj.TerminalsSPI)
                obj.localizedError('MATLAB:hwsdk:general:notSupportedInterface', 'SPI', obj.Board);
            else
                terminals = obj.TerminalsSPI;
            end
        end

        function terminals = getSerialTerminals(obj,port)
            if isempty(obj.TerminalsSerial)
                obj.localizedError('MATLAB:hwsdk:general:notSupportedInterface', 'Serial', obj.Board);
            else
                portNum = numel(obj.TerminalsSerial)/2;
                ports = 1:portNum;
                if nargin < 2
                    terminals = obj.TerminalsSerial;
                else
                    try
                        validateattributes(port, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
                    catch
                        obj.localizedError('MATLAB:hwsdk:general:invalidSerialPortType','Serial', matlabshared.hwsdk.internal.renderArrayOfIntsToString(ports));
                    end

                    if port > portNum
                        obj.localizedError('MATLAB:hwsdk:general:unsupportedPort', char(num2str(port)), obj.Board, matlabshared.hwsdk.internal.renderArrayOfIntsToString(ports));
                    end
                    terminals = obj.TerminalsSerial((port-1)*2+1:(port-1)*2+2);
                end
            end
        end

        function terminals = getServoTerminals(obj)
            terminals = obj.TerminalsServo;
        end

        function terminals = getPWMTerminals(obj)
            terminals = obj.TerminalsPWM;
        end

        function terminals = getInterruptTerminals(obj)
            terminals = obj.TerminalsInterrupt;
        end

        function modes = getSupportedModes(obj,terminal)

            modes = {};
            % Flag to indicate if the terminal supports digital mode.
            terminalSupportsDigitalInputMode = true;
            terminalSupportsDigitalOutputMode = true;

            % Validate if terminal supports digital output mode.
            % Error indicates that pin doesn't support digital mode - set flag to false.
            try
                obj.validateTerminalSupportsTerminalMode(terminal, 'DigitalOutput');
            catch
                terminalSupportsDigitalOutputMode = false;
            end

            % Validate if terminal supports digital input mode.
            % Error indicates that pin doesn't support digital mode - set flag to false.
            try
                obj.validateTerminalSupportsTerminalMode(terminal, 'DigitalInput');
            catch
                terminalSupportsDigitalInputMode = false;
            end


            if ismember(terminal,union(obj.TerminalsAnalog,obj.TerminalsDigitalAndAnalog))
                % A4 and A5 pins are not considered as Analog pins in Nano33IoT and Nano33BLE boards
                if ~ismember(obj.Board, {'Nano33IoT','Nano33BLE'}) ||...
                        ~ismember(obj.getPinsFromTerminals(terminal), {'A4','A5'})
                    modes{end+1} = 'AnalogInput';
                end
            end
            if ismember(terminal,obj.TerminalsDigital)
                if terminalSupportsDigitalInputMode
                    modes{end+1} = 'DigitalInput';
                end
                if terminalSupportsDigitalOutputMode
                    modes{end+1} = 'DigitalOutput';
                end
            end
            if ismember(terminal,obj.TerminalsPWM)
                modes{end+1} = 'PWM';
            end
            if ismember(terminal,obj.TerminalsI2C)
                modes{end+1} = 'I2C';
            end
            if ismember(terminal,obj.TerminalsSPI)
                modes{end+1} = 'SPI';
            end
            if ismember(terminal,obj.TerminalsInterrupt)
                modes{end+1} = 'Interrupt';
            end
            if ismember(terminal,obj.TerminalsServo)
                modes{end+1} = 'Servo';
            end
            if ismember(terminal,obj.TerminalsSerial)
                modes{end+1} = 'Serial';
            end
            % Tone is supported only on AVR,cortex-m0plus and cortex-m4 boards
            % Add "Tone" to the list only if it's one of the supported pin modes
            if ismember("Tone",union(obj.AnalogPinModes,obj.DigitalPinModes))
                modes{end+1} = 'Tone';
            end

            % Digital pins can be configured in any of the other modes as well
            % Whereas pins that are Analog only cannot be configured to any other mode.
            % Check if the pin also supports any digital modes.
            if terminalSupportsDigitalInputMode
                modes = [modes,{'Unset','Ultrasonic','Pullup','CAN'}];
            else
                modes = [modes,{'Unset'}];
            end
            modes = sort(modes);
        end

        function validateTerminalType(obj, type)
            supportedTypes = {'servo', 'spi', 'i2c', 'pwm', 'analog', 'digital', 'interrupt'};
            try
                validatestring(lower(type), supportedTypes);
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidValidateType', strjoin(supportedTypes, ', '));
            end
        end

        %% Return false when given terminal does not support the special functionality
        function result = validateTerminal(obj, terminal, type)
            validateTerminalFormat(obj, terminal);
            validateTerminalType(obj, type);

            switch lower(type)
              case 'digital'
                result = validateDigitalTerminal(obj, terminal, 'unset');
              case 'analog'
                result = validateAnalogTerminal(obj, terminal, 'unset');
              case 'pwm'
                result = validatePWMTerminal(obj, terminal);
              case 'i2c'
                result = validateI2CTerminal(obj, terminal);
              case 'spi'
                result = validateSPITerminal(obj, terminal);
              case 'servo'
                result = validateServoTerminal(obj, terminal);
              case 'interrupt'
                result = validateInterruptTerminal(obj, terminal);
              otherwise
            end
        end

        %% Resource Count Methods
        function count = incrementResourceCount(obj, resourceName)
            resourceName = validateResourceNameType(obj, resourceName);

            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if ~isfield(resource, 'Count')
                    resource.Count = 1;
                else
                    resource.Count = resource.Count + 1;
                end
            else
                resource.Count = 1;
            end
            count = resource.Count;
            obj.ResourceMap(resourceName) = resource;
        end

        function count = decrementResourceCount(obj, resourceName)
            resourceName = validateResourceNameType(obj, resourceName);

            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if isfield(resource, 'Count')
                    if resource.Count == 0
                        obj.localizedError('MATLAB:hwsdk:general:resourceCountZero');
                    else
                        resource.Count = resource.Count - 1;
                        count = resource.Count;
                        obj.ResourceMap(resourceName) = resource;
                    end
                else % If resourceName exists but Count does not
                    obj.localizedError('MATLAB:hwsdk:general:resourceCountZero');
                end
            else
                obj.localizedError('MATLAB:hwsdk:general:invalidResourceName', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(keys(obj.ResourceMap), ', '));
            end
        end

        function count = getResourceCount(obj, resourceName)
            resourceName = validateResourceNameType(obj, resourceName);

            count = 0;
            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if ~isfield(resource, 'Count')
                    return;
                end
                count = resource.Count;
            else
                obj.ResourceMap(resourceName) = struct;
            end
        end

        %% Resource Slot Methods
        function slot = getFreeResourceSlot(obj, resourceName)
            resourceName = validateResourceNameType(obj, resourceName);

            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if ~isfield(resource, 'Slot')
                    slot = 1;
                    resource.Slot(slot) = true;
                    obj.ResourceMap(resourceName) = resource;
                    return;
                end
                for slot = 1:numel(resource.Slot)
                    if resource.Slot(slot) ==  false
                        resource.Slot(slot) = true;
                        obj.ResourceMap(resourceName) = resource;
                        return;
                    end
                end
                slot = numel(resource.Slot) + 1;
                resource.Slot(slot) = true;
                obj.ResourceMap(resourceName) = resource;
                return;
            end

            slot = 1;
            resource.Slot(slot) = true;
            obj.ResourceMap(resourceName) = resource;
        end

        function clearResourceSlot(obj, resourceName, slot)
            resourceName = validateResourceNameType(obj, resourceName);

            try
                validateattributes(slot, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidSlotType');
            end

            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if ~isfield(resource, 'Slot') % If resourceName exists but Slot does not
                    beginSlot = 1;
                    resource.Slot(beginSlot) = true;
                end
                if slot > 0 && slot <= numel(resource.Slot)
                    resource.Slot(slot) = false;
                    obj.ResourceMap(resourceName) = resource;
                else
                    slots = 1:numel(resource.Slot);
                    obj.localizedError('MATLAB:hwsdk:general:invalidSlotNumber', matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(slots));
                end
            else
                obj.localizedError('MATLAB:hwsdk:general:invalidResourceName', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(keys(obj.ResourceMap), ', '));
            end
        end

        function setSharedResourceProperty(obj, resourceName, propertyName, propertyValue)
            resourceName = validateResourceNameType(obj, resourceName);

            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
            end

            propertyName = validatePropertyNameType(obj, propertyName);

            resource.(propertyName) = propertyValue;
            obj.ResourceMap(resourceName) = resource;
        end

        function value = getSharedResourceProperty(obj, resourceName, propertyName)
            value = [];
            resourceName = validateResourceNameType(obj, resourceName);

            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);

                propertyName = validatePropertyNameType(obj, propertyName);

                if isfield(resource, propertyName)
                    value = resource.(propertyName);
                else
                    obj.localizedError('MATLAB:hwsdk:general:invalidPropertyName', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(fieldnames(resource), ', '));
                end
            else
                obj.localizedError('MATLAB:hwsdk:general:invalidResourceName', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(keys(obj.ResourceMap), ', '));
            end
        end

        function overridePinResource(obj, pin, resourceOwner, mode)
            terminal = getTerminalsFromPins(obj, pin);
            updateResource(obj, terminal, resourceOwner, mode);
        end

        function newOwner = validateResourceOwner(obj, terminal, resourceOwner, newMode)
            if strcmp(obj.Terminals(terminal+1).Mode, 'Unset')
                % The only time an object may claim a resource is it that
                % resource is in an unset mode
                obj.Terminals(terminal+1).ResourceOwner = resourceOwner;
                newOwner = resourceOwner;
                return;
            elseif ismember(obj.Board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}) && strcmp(getResourceOwner(obj,terminal),'') && strcmp(obj.Terminals(terminal+1).Mode, 'Servo')
                % Allow servo to take over from empty resource for ESP32 HW
                obj.Terminals(terminal+1).ResourceOwner = resourceOwner;
                newOwner = resourceOwner;
                return;
            elseif ismember(obj.Board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}) && strcmp(getResourceOwner(obj,terminal),'Servo') && strcmp(obj.Terminals(terminal+1).Mode, 'Servo') && isempty(resourceOwner)
                obj.Terminals(terminal+1).ResourceOwner = resourceOwner;
                newOwner = resourceOwner;
                return;
            end

            % Throw an error if resource owners don't match
            if ~strcmp(obj.Terminals(terminal+1).ResourceOwner, resourceOwner)
                if obj.isTerminalAnalog(terminal)
                    subsystem = 'Analog';
                else
                    subsystem = 'Digital';
                end
                pin = obj.getPinsFromTerminals(terminal); pin = pin{1};

                resourceOwner = obj.Terminals(terminal+1).ResourceOwner;
                mode = obj.Terminals(terminal+1).Mode;

                if strcmp(resourceOwner, '')
                    % configurePin(m, 'P16', 'DigitalOutput')
                    % d = device(m, 'SPIChipSelectPin', 'P16') -> reaches
                    % here.
                    obj.localizedError('MATLAB:hwsdk:general:reservedResourceDigitalAnalog', subsystem, pin, obj.Board, mode);
                else
                    obj.localizedError('MATLAB:hwsdk:general:resourceReserved', obj.Board, pin, char(resourceOwner));
                end
            else
                % if same resourceOwner, new mode 'Unset' returns the
                % ownership of the resource to Arduino automatically
                if strcmp(newMode, 'Unset')
                    newOwner = '';
                else
                    newOwner = resourceOwner;
                end
            end
        end
    end

    %% Private methods
    %
    %
    methods (Access = {?arduino.accessor.UnitTest})
        function resourceName = validateResourceNameType(obj, resourceName)
            try
                validateattributes(resourceName, {'char', 'string'}, {'scalartext'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidResourceNameType');
            end
            % accept string type resourceName but convert to character vector
            if isstring(resourceName)
                resourceName = char(resourceName);
            end
        end

        function propertyName = validatePropertyNameType(obj, propertyName)
            try
                validateattributes(propertyName, {'char', 'string'}, {'scalartext'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidPropertyNameType');
            end
            % accept string type propertyName but convert to character vector
            if isstring(propertyName)
                propertyName = char(propertyName);
            end
        end

        function pin = validatePinFormat(obj, pin)
        % accept string input but convert to character vector
            if isstring(pin)
                pin = char(pin);
            end

            if ischar(pin) && ~isempty(pin) && ismember(upper(pin(1)), {'A', 'D'})
            else
                validPins = getPinsFromTerminals(obj, [obj.TerminalsDigital, obj.TerminalsAnalog]);
                obj.localizedError('MATLAB:hwsdk:general:invalidPinTypeString',char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
            end
            pin = upper(pin);
        end

        function validateTerminalFormat(obj, terminal)
            try
                validateattributes(terminal, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan','nonnegative'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidTerminalType');
            end

            validTerminals = union(obj.TerminalsDigital, obj.TerminalsAnalog);

            if ismember(terminal, validTerminals)
            else
                obj.localizedError('MATLAB:hwsdk:general:invalidTerminalNumber', num2str(terminal), obj.Board,  matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(validTerminals));
            end
        end

        function result = isTerminalI2C(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsI2C);
        end

        function result = isTerminalSPI(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsSPI);
        end

        function result = isTerminalPWM(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsPWM);
        end

        function result = isTerminalServo(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsServo);
        end

        function result = isTerminalInterrupt(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsInterrupt);
        end

        function result = validateAnalogTerminal(obj, terminal, mode)
            try
                obj.validateTerminalMode(terminal, mode);
            catch
                % Allow this method to validate the terminal even if mode
                % is invalid
                mode = 'Unset';
            end

            validTerminals = obj.TerminalsAnalog;
            switch mode
              case 'i2c'
                validTerminals = intersect(validTerminals, obj.TerminalsI2C);
              case {'digitalinput','digitaloutput'}
                if strcmp(obj.MCU, 'atmega328p')
                    validTerminals = validTerminals(validTerminals<20);
                elseif ismember(obj.MCU,'esp32') && strcmpi(mode,'digitaloutput')
                    validTerminals = setdiff(validTerminals,arduinoio.internal.ArduinoConstants.ESP32InputOnlyTerminals,'stable');
                elseif ismember(obj.MCU,'esp32') && strcmpi(mode,'digitalinput')
                    validTerminals = setdiff(validTerminals,arduinoio.internal.ArduinoConstants.ESP32OutputOnlyTerminals,'stable');
                end
              case 'interrupt'
                validTerminals = intersect(validTerminals, obj.TerminalsInterrupt);
              otherwise
            end

            switch lower(mode)
              case 'unset'
                pinType = 'analog';
              otherwise
                pinType = ['analog ' mode];
            end

            if ~ismember(terminal, validTerminals)
                validPins = obj.getPinsFromTerminals(validTerminals);
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                   obj.Board, pinType, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
            end
            result = double(terminal);
        end

        function result = validateDigitalTerminal(obj, terminal, mode)
            try
                obj.validateTerminalMode(terminal, mode);
            catch
                % Allow this method to validate the terminal even is mode
                % is invalid
                mode = 'Unset';
            end

            validTerminals = obj.TerminalsDigital;
            switch lower(mode)
              case 'pwm'
                validTerminals = intersect(validTerminals, obj.TerminalsPWM);
              case 'servo'
                validTerminals = intersect(validTerminals, obj.TerminalsServo);
              case 'i2c'
                validTerminals = intersect(validTerminals, obj.TerminalsI2C);
              case 'spi'
                validTerminals = intersect(validTerminals, obj.TerminalsSPI);
              case 'interrupt'
                validTerminals = intersect(validTerminals, obj.TerminalsInterrupt);
              otherwise
            end

            switch lower(mode)
              case 'unset'
                pinType = 'digital';
              otherwise
                pinType = ['digital ' mode];
            end

            if ~ismember(terminal, validTerminals)
                validPins = obj.getPinsFromTerminals(validTerminals);
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                   obj.Board, pinType, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
            end
            result = double(terminal);
        end

        function result = validateServoTerminal(obj, terminal)
            if ~obj.isTerminalServo(terminal)
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                   obj.Board, 'servo', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(obj.getPinsFromTerminals(obj.TerminalsServo)))));
            end
            result = double(terminal);
        end

        function result = validateSPITerminal(obj, terminal)
            if ~obj.isTerminalSPI(terminal)
                if isempty(obj.TerminalsSPI)
                    validTerminals = 'none';
                else
                    validTerminals = strjoin(obj.getPinsFromTerminals(obj.TerminalsSPI), ', ');
                end
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                   obj.Board, 'SPI', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validTerminals))));
            end
            result = double(terminal);
        end

        function result = validateI2CTerminal(obj, terminal)
            if ~obj.isTerminalI2C(terminal)
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                   obj.Board, 'I2C', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(obj.getPinsFromTerminals(obj.TerminalsI2C)))));
            end
            result = double(terminal);
        end

        function result = validatePWMTerminal(obj, terminal)
            if ~obj.isTerminalPWM(terminal)
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                   obj.Board, 'PWM', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(obj.getPinsFromTerminals(obj.TerminalsPWM)))));
            end
            result = double(terminal);
        end

        function result = validateInterruptTerminal(obj, terminal)
            if ~obj.isTerminalInterrupt(terminal)
                obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                   obj.Board, 'Interrupt', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(obj.getPinsFromTerminals(obj.TerminalsInterrupt)))));
            end
            result = double(terminal);
        end

        function mode = validateTerminalMode(obj, subsystem, mode)
        % Check if the given mode is a valid mode for the subsystem
        %
            if strcmp(mode, '')
                mode = 'Unset';
            end

            % Composite modes
            parentMode = '';
            try
                if contains(mode, '\')
                    k = strfind(mode, '\');
                    kk = k(end);
                    parentMode = mode(1:kk);
                    mode = mode(kk+1:end);
                end
            catch
            end

            if subsystem
                subsystem = 'digital';
                validUserPinModes = obj.DigitalPinModes;
                validOtherPinModes = obj.AnalogPinModes;
            else
                subsystem = 'analog';
                validUserPinModes = obj.AnalogPinModes;
                validOtherPinModes = obj.DigitalPinModes;
            end

            allValidPinModes = validUserPinModes;
            allValidPinModes{end+1} = 'Reserved';
            try
                mode = validatestring(mode, allValidPinModes);
            catch
                try
                    mode = validatestring(mode, validOtherPinModes);
                catch
                    obj.localizedError('MATLAB:hwsdk:general:invalidPinMode', ...
                                       subsystem, ...
                                       matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(validUserPinModes, ', '));
                    return;
                end
                obj.localizedError('MATLAB:hwsdk:general:notSupportedPinMode', ...
                                   mode, ...
                                   matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(validUserPinModes, ', '));
            end

            mode = [parentMode mode];
        end

        function validateCompatibleTerminalModeConversion(obj, terminal, mode)
        % Digital Pins: I2C, SPI, DigitalInput, Pullup, DigitalOutput,
        % PWM, Servo, Interrupt, Unset
        %
        % Digital I2C, SPI, Interrupt and Pullup modes cannot be
        % converted to any other pin modes.
        %
        % Digital Input mode cannot be converted to any other pin modes
        % except for Analog Input if supported on the pin
        %
        % Pullup mode can only be converted to DigitalInput or AnalogInput
        % mode
        %
        % Digital Output, PWM and Servo pin modes are all digital
        % output modes that can be interchanged freely as long as they
        % are all output pins... They cannot be converted to a digital
        % input pin mode.

        % There are no other restrictions on an Unset pin.
        %
            if strcmp(mode, 'Unset')
                return;
            end

            currentMode = obj.getTerminalMode(terminal);
            if ~strcmp(mode, currentMode)
                switch(currentMode)
                  case {'I2C', 'SPI', 'Servo', 'Interrupt', 'Tone', 'Ultrasonic'}
                    pin = obj.getPinsFromTerminals(terminal);
                    obj.localizedError('MATLAB:hwsdk:general:reservedPin', pin{1}, currentMode, mode);
                  case {'DigitalInput', 'AnalogInput'}
                    if ~ismember(mode, {'DigitalInput', 'AnalogInput'}) % Freely change between DigitalInput and AnalogInput
                        pin = obj.getPinsFromTerminals(terminal);
                        obj.localizedError('MATLAB:hwsdk:general:reservedPin', pin{1}, currentMode, mode);
                    end
                  case {'PWM', 'DigitalOutput'}
                    if ~ismember(mode, {'PWM', 'DigitalOutput'}) && ~ismember(obj.Board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'})% Compatible output pins for all boards except ESP32
                        pin = obj.getPinsFromTerminals(terminal);
                        obj.localizedError('MATLAB:hwsdk:general:reservedPin', pin{1}, currentMode, mode);
                    elseif ismember(obj.Board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}) && ~strcmpi(mode,currentMode) % not compatible modes for ESP32
                        pin = obj.getPinsFromTerminals(terminal);
                        obj.localizedError('MATLAB:hwsdk:general:reservedPin', pin{1}, currentMode, mode);
                    end
                  case {'Pullup'}
                    if ~ismember(mode, {'DigitalInput', 'AnalogInput'}) % Compatible input pins
                        pin = obj.getPinsFromTerminals(terminal);
                        obj.localizedError('MATLAB:hwsdk:general:reservedPin', pin{1}, currentMode, mode);
                    end
                  case {'Reserved'}
                    % Resource owner needs to handle any compatibility issues
                    %
                  otherwise
                    % Unset pins are not reserved
                    %
                end
            end

        end

        function applyFilterTerminalModeChange(obj, terminal, resourceOwner, mode, forceConfig)
        % Compatibility has already been verified earlier. Now simply
        % apply the configuration mode changes (except for
        % non-changeable modes).

        % Example: If the current terminal mode is 'Pullup', reading
        % the terminal should not result in its configuration changing
        % to 'Input'.
        %
            if ~forceConfig
                if strcmp(obj.getTerminalMode(terminal), 'Pullup') && ...
                        ismember(mode, {'DigitalInput', 'AnalogInput'})
                    return;
                end
            end

            obj.updateResource(terminal, resourceOwner, mode);
        end

        function updateResource(obj, terminal, resourceOwner, mode)
            obj.Terminals(terminal+1).Mode = mode;
            obj.Terminals(terminal+1).ResourceOwner = resourceOwner;
            if strcmp(mode, 'Unset')
                obj.Terminals(terminal+1).ResourceOwner = '';
            end
        end
    end
end

% LocalWords:  arduinoio Pullup SPI atmega microcontroller scalartext CBus spi hwsdk
% LocalWords:  pwm digitalinput digitaloutput CPins changeable Tx nonnan
