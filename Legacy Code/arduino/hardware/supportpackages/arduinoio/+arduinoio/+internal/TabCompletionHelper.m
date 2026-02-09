classdef (Hidden) TabCompletionHelper < matlabshared.hwsdk.internal.base
% helper class for dynamic input arguments' values for
% resources/functionSignatures.json

% Copyright 2016-2020 The MathWorks, Inc.

    methods(Static)
        function boards = getSupportedBoards
        % Get supported boards list from BoardInfo.m
            b = arduinoio.internal.BoardInfo.getInstance();
            boards = {b.Boards.Name};
        end

        function libs = getAddonLibraries
        % Get all valid library strings to specify in 'addon' function
            allLibs = listArduinoLibraries;
            libs = {};
            result = strfind(allLibs, '/');
            for ii = 1:numel(allLibs)
                if ~isempty(result{ii})
                    libs = [libs, allLibs{ii}]; %#ok<AGROW>
                end
            end
        end

        function pins = getInterruptPins(arduinoObj, selectedPins)
        % Get all interrupt pins on the given board
            terminals = getInterruptTerminals(arduinoObj.ResourceManager);
            pins = getPinsFromTerminals(arduinoObj.ResourceManager, terminals);
            if nargin > 1
                pins = setxor(pins, selectedPins);
            end
        end

        function pins = getServoPins(arduinoObj)
        % Get all pins supported for Servo on the given board
            terminals = getServoTerminals(arduinoObj.ResourceManager);
            pins = getPinsFromTerminals(arduinoObj.ResourceManager, terminals);
        end

        function precisions = getShiftRegisterWritePrecisions
        % Get all supported precisions for write methods of
        % shiftRegister object
            precisions = {'uint8', 'uint16', 'uint32', 'uint64'};
        end

        function precisions = getShiftRegisterReadPrecisions
        % Get all supported precisions for read methods of
        % shiftRegister object
            precisions = {'uint8', 'uint16', 'uint32', 'uint64'};
        end

        function types = getStepTypes
        % Get all supported values for StepType NV pair for stepper
        % object
            types = {'Single', 'Double', 'Interleave', 'Microstep'};
        end
        
        function motornum = getMCDCMotorNumber
        % Get all supported DC motor numbers for MotorCarrier
            motornum = {'M1','M2','M3','M4'};
        end
        
        function servonum = getMCServoNumber
        % Get all supported servo motor numbers for MotorCarrier
            servonum = {1,2,3,4};            
        end
        
        function pidnum = getMCPIDNumber
        % Get all supported PID motor numbers for MotorCarrier
            pidnum = {1,2};
        end
        
        function encodernum = getMCRotaryEncoderNumber
        % Get all supported encoder channel numbers for MotorCarrier
            encodernum = {1,2};
        end
        function controlmode = getPIDControlMode
        % Get all supported PID control modes for MotorCarrier
            controlmode = {'speed','position'};
        end
        
        function mode = getAngularPositionMode
         % Get all supported Angular Position write modes for MotorCarrier
            mode = {'abs','rel'};
        end
        
        %% CAN
        function deviceNames = getCANDeviceNames(obj)
            deviceNames = obj.SupportedCANDevices;
            % Remove MCP2515 from the list since a separate flavor of
            % functionSignature exists for MCP2515
            deviceNames(strcmpi(deviceNames, 'MCP2515')) = [];
        end
        
        function CANChipSelectPins = getCANChipSelectPins(obj)
            digitalPins = obj.AvailableDigitalPins;
            spiTerminals = getSPITerminals(obj);
            spiPins = getPinsFromTerminals(obj, spiTerminals);
            if ~isempty(spiPins)
                validPins = setdiff(digitalPins, spiPins(1:3), 'stable');
            else
                validPins = digitalPins;
            end
            CANChipSelectPins = validPins;
        end
        
        function CANInterruptPins = getCANInterruptPins(obj, selectedPins)
            terminals = getInterruptTerminals(obj.ResourceManager);
            pins = getPinsFromTerminals(obj.ResourceManager, terminals);
            if (nargin > 1) && ismember(selectedPins, pins)
                pins = setxor(pins, selectedPins);
            end
            CANInterruptPins = pins;
        end
        
        function oscFreqs = getCANOscillatorFrequencies(~)
            oscFreqs = arduinoio.internal.ArduinoConstants.OscillatorFrequenciesMCP2515;
        end
        
        function busSpeeds = getCANBusSpeeds(~)
            busSpeeds = arduinoio.internal.ArduinoConstants.BusSpeedsMCP2515;
        end
    end
end

% LocalWords:  json addon Microstep cdev spidev Pullup SPI
