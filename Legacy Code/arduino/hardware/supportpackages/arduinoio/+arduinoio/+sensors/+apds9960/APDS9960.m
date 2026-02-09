classdef APDS9960 < matlabshared.addon.LibraryBase & matlab.mixin.CustomDisplay
    %APDS9960    Create an APDS9960 sensor object
    %
    %   APDS9960 methods:
    %       readGesture   - Read gesture sensed by APDS9960 sensor
    %       readProximity - Read proximity value measure by APDS9960 sensor
    %       readColor     - Read clear light and/or RGB component values measured by APDS9960 sensor
    %
    %   Copyright 2021 The MathWorks, Inc.

    properties(GetAccess = public, SetAccess = protected)
        %I2CAddress - I2C device address on the Arduino hardware
        I2CAddress
        %Bus - I2C bus number
        Bus
        %SCLPin - A serial clock pin for the serial clock signal
        %on an I2C bus 
        SCLPin
        %SDAPin - A serial data pin for a serial data signal on 
        %an I2C bus
        SDAPin
    end

    properties(Dependent = true, SetAccess = protected)
        %BitRate - the maximum speed of I2C communication in bits/s
        BitRate
    end

    properties(GetAccess = public, SetAccess = protected)
        %Gesture - Gesture holds the instance of GestureConfiguration class
        Gesture
        %Proximity - Proximity holds the instance of ProximityConfiguration class
        Proximity
        %Color - Color holds the instance of ColorConfiguration class
        Color
    end

    properties(Access = {?arduinoio.sensors.apds9960.APDS9960, ?arduinoio.sensors.apds9960.GestureConfiguration, ?arduinoio.sensors.apds9960.ColorConfiguration, ?arduinoio.sensors.apds9960.ProximityConfiguration, ?arduino.accessor.UnitTest})
        %I2CObj - I2C device object
        I2CObj
    end

    properties(Access = private)
        %APDS9960_DEVICE_ADDRESS - ADPS9960 Device Address
        APDS9960_DEVICE_ADDRESS = 0x39
        %APDS9960_ENABLE_REGISTER - APDS9960 Enable Register
        %   Set Power and Wait Time bits
        %   Enable/Disable Proximity, Color, and Gesture engines
        APDS9960_ENABLE_REGISTER = 0x80
        %APDS9960_PROXIMITY_DATA - Proximity Data Register
        APDS9960_PROXIMITY_DATA = 0x9C
        %APDS9960_COLOR_DATA - Color Data Register
        APDS9960_COLOR_DATA = 0x94

        %APDS9960_CREATE_APDS9960 - Command ID to set I2C bus number
        APDS9960_CREATE_APDS9960 = 0x01
        %APDS9960_INIT_APDS9960 - Command ID to initiate the sensor to
        %default settings
        APDS9960_INIT_APDS9960 = 0x02
        %APDS9960_READ_GESTURE - Command ID to read gesture
        APDS9960_READ_GESTURE = 0x03
        %APDS9960_DELETE_APDS9960 - Command ID to reset the sensor to 
        %power on reset default
        APDS9960_DELETE_APDS9960 = 0x04
    end

    properties(Access = private)
        %ColorEnabled - Checks if the color engine is enabled on the sensor
        ColorEnabled
    end

    properties(Access = {?arduinoio.sensors.apds9960.APDS9960, ?arduinoio.sensors.apds9960.GestureConfiguration, ?arduinoio.sensors.apds9960.ProximityConfiguration})
        %LEDBoostValue - Boost LED drive current during proximity and gesture LED pulses
        %   A placeholder value that gets updated by issuing either
        %   apds9960Obj.Gesture.LEDBoost = x or apds9960.Proximity.LEDBoost = x
        %   this is fetched by get.LEDBoost methods defined in either of the
        %   ProximityConfiguration or GestureConfiguration classes to set a
        %   common LEDBoost value
        %   Defaults to 100%
        LEDBoostValue = 100
    end

    properties(Access = protected, Constant = true)
        LibraryName = 'APDS9960'
        DependentLibraries = {'I2C'}
        LibraryHeaderFiles = ''
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'APDS9960.h')
        CppClassName = 'APDS9960'
    end

    properties(Access = private, Constant = true)
        %MaxProximityRawValue - Maximum raw value of proximity pushed out by the sensor
        MaxProximityRawValue = double(intmax("uint8"))
    end

    methods
        % Get method for the dependent property BitRate
        function value = get.BitRate(obj)
            value = obj.I2CObj.BitRate;
        end
    end

    methods(Hidden, Access = public)
        function obj = APDS9960(arduinoObj, varargin)
            %APDS9960   Constructs an instance of the APDS9960 class
            %   Creates an I2C device object to communicate with the analog
            %   engines - proximity and color of the APDS9960 sensor.
            %   And creates a custom peripheral over I2C to fetch gesture data
            %   from the sensor. Holds the instances of GestureConfiguration,
            %   ProximityConfiguration, and ColorConfiguration classes

            % Only Bus and BitRate NV pairs are allowed
            narginchk(1,5);
            try
                p = inputParser;
                p.PartialMatching = true;
                if strcmpi(arduinoObj.Board, 'Nano33BLE')
                    % Default I2C bus number for Nano 33 BLE Sense is 1
                    addParameter(p, 'Bus', 1);
                else
                    % Default I2C bus number for other supported Arduino
                    % boards is 0
                    addParameter(p, 'Bus', 0);
                end
                % Default BitRate for all supported Arduino boards is
                % 100000 bits/s
                addParameter(p, 'BitRate', []);
                parse(p, varargin{:});

                % Create I2C device object
                obj.I2CObj = device(arduinoObj, 'I2CAddress', obj.APDS9960_DEVICE_ADDRESS, 'Bus', p.Results.Bus, 'BitRate', p.Results.BitRate);

            catch e
                parameters = p.Parameters;
                if ismember(e.identifier, {'MATLAB:InputParser:UnmatchedParameter'})
                    message = e.message;
                    index = strfind(message, '''');
                    str = message(index(1)+1:index(2)-1);
                    obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'APDS9960 sensor object', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                elseif strcmpi(e.identifier, 'MATLAB:InputParser:ParamMustBeChar')
                    nvPairs = cellfun(@ischar, varargin(1:end));
                    nvNames = nvPairs(1:2:end);
                    numericNVNames = find(~nvNames);
                    nonCharNVName = varargin{(numericNVNames(1)*2-1)};
                    if isnumeric(nonCharNVName)
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', num2str(nonCharNVName), 'APDS9960 sensor object', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                    else
                        throwAsCaller(e);
                    end
                end
                throwAsCaller(e);
            end

            % Hold the arduino object in the Parent property
            obj.Parent = arduinoObj;

            % Set the I2CAddress, Bus, SCLPin, and SDAPin of APDS9960
            obj.I2CAddress = obj.I2CObj.I2CAddress;
            obj.Bus = obj.I2CObj.Bus;
            obj.SCLPin = obj.I2CObj.SCLPin;
            obj.SDAPin = obj.I2CObj.SDAPin;

            % Initialize the APDS9960 register settings
            createAPDS9960(obj);

            % Indicate that color engine is turned on
            obj.ColorEnabled = true;

            % Turn on both proximity and color engines
            enablePower(obj, 1);
            enableProximity(obj, 1);
            enableColor(obj, 1);

            % Hold the configuration class objects in the Gesture,
            % Proximity, and Color properties
            obj.Gesture = arduinoio.sensors.apds9960.GestureConfiguration(obj);
            obj.Proximity = arduinoio.sensors.apds9960.ProximityConfiguration(obj);
            obj.Color = arduinoio.sensors.apds9960.ColorConfiguration(obj);
        end

        function deleteAPDS9960(obj)
            % Send command ID to the customer peripheral to configure the
            % APDS9960 registers to power on reset defaults
            sendCommand(obj, obj.LibraryName, obj.APDS9960_DELETE_APDS9960, []);
        end
    end

    methods (Access=protected)
        function delete(obj)
            try
               deleteAPDS9960(obj);
            catch
                % If sensor connection is lost/unavailable, deleteAPPDS960
                % will not work as a command is sent over to the hardware
                % via custom peripheral
            end
        end
    end

    methods(Access = public)
        function [gesture, timestamp] = readGesture(obj, varargin)
            %readGesture   Read gesture sensed by APDS9960 sensor
            %
            %   [VAL] = readGesture(apds9960Obj) returns a basic gesture
            %   up, down, left, or right sensed by APDS9960 sensor
            %
            %   [VAL,TIMESTAMP] = readGesture(apds9960Obj) returns a basic
            %   gesture up, down, left, or right sensed by APDS9960
            %   sensor and the timestamp in 'dd-MMM-uuuu HH:mm:ss.SSS'
            %   format
            %
            %   % Construct an arduino object
            %   a = arduino('COM14','Nano33BLE','Libraries','APDS9960');
            %
            %   % Construct APDS9960 object
            %   apds9960Obj = apds9960(a);
            %
            %   % Read gesture sensed by APDS9960 sensor
            %   val = readGesture(apds9960Obj);
            %   [val, timestamp] = readGesture(apds9960Obj);
            %
            %   See also readColor, readProximity

            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'APDS9960'));
            try
                narginchk(1, 1);
                % Enable the gesture engine
                enableGesture(obj, 1);
                % Read gesture data from the sensor's FIFO
                % A. 1x32 vector is returned if a successful gesture is
                %    detected
                % B. 1x1 value is returned if no gesture is detected 
                %    within the custom peripheral timeout
                gestureData = sendCommand(obj, obj.LibraryName, obj.APDS9960_READ_GESTURE, []);

                if ~isequal(numel(gestureData), 1)
                    % Determine a basic gesture up, down, left, right, or
                    % none with getGesture() method
                    gesture = getGesture(obj, gestureData);
                else
                    % Return none if gestureData is 1x1 value
                    gesture = arduinoio.sensors.apds9960.Gestures.none;
                end
                % Disable the gesture engine
                enableGesture(obj, 0);
                timestamp = datetime;
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function [proximity, timestamp] = readProximity(obj, varargin)
            %readProximity   Read proximity value measured by APDS9960
            %sensor
            %
            %   [VAL] = readProximity(apds9960Obj) returns the proximity
            %   value measured by APDS9960 sensor normalized in the range 
            %   of 0 to 1 where 0 means near and 1 means far
            %
            %   [VAL,TIMESTAMP] = readProximity(apds9960Obj) is the same as
            %   readProximity(apds9960Obj) and returns the timestamp in
            %   'dd-MMM-uuuu HH:mm:ss.SSS' format
            %
            %   % Construct an arduino object
            %   a = arduino('COM14','Nano33BLE','Libraries','APDS9960');
            %
            %   % Construct APDS9960 object
            %   apds9960Obj = apds9960(a);
            %
            %   % Read Proximity measured by APDS9960 sensor
            %   val = readProximity(apds9960Obj);
            %   [val, timestamp] = readProximity(apds9960Obj);
            %
            %   See also readColor, readGesture

            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'APDS9960'));
            try
                narginchk(1, 1);
                proximity = readRegister(obj.I2CObj, obj.APDS9960_PROXIMITY_DATA, 1);
                % normalize the raw count from 0 to 1
                % 0 - near, 1 - far
                proximity = normalizeProximity(obj, proximity);
                timestamp = datetime;
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end

        function [colorData, timestamp] = readColor(obj, varargin)
            %readColor   Read clear light and/or RGB component values
            %measured by APDS9960 sensor
            %
            %   [VAL] = readColor(apds9960Obj) returns a 1x3 row vector
            %   containing R, G, B component values normalized with respect
            %   to the clear light value measured by APDS9960 sensor
            %
            %   [VAL] = readColor(apds9960Obj, 'normalized') is the same as
            %   readColor(apds9960Obj)
            %
            %   [VAL] = readColor(apds9960Obj, 'raw') returns a 1x4 row
            %   vector containing 'uint16' raw values of the clear light
            %   and R, G, and B components measured by APDS9960 sensor
            %
            %   [VAL, TIMESTAMP] = readColor(apds9960Obj) returns a 1x3 row
            %   vector containing R, G, B component values normalized with
            %   respect to the clear light value measured by APDS9960
            %   sensor and the timestamp in 'dd-MMM-uuuu HH:mm:ss.SSS'
            %   format
            %
            %   [VAL,TIMESTAMP] = readColor(apds9960Obj, 'normalized') is
            %   the same as readColor(apds9960Obj) and returns the
            %   timestamp in 'dd-MMM-uuuu HH:mm:ss.SSS' format
            %
            %   [VAL,TIMESTAMP] = readColor(apds9960Obj, 'raw') returns a
            %   1x4 row vector containing 'uint16' raw values of the clear
            %   light and R, G, and B components measured by APDS9960
            %   sensor and  the timestamp in 'dd-MMM-uuuu HH:mm:ss.SSS'
            %   format
            %
            %   % Construct an arduino object
            %   a = arduino('COM14','Nano33BLE','Libraries','APDS9960');
            %
            %   % Construct APDS9960 object
            %   apds9960Obj = apds9960(a);
            %
            %   % Read RGB component values measured by APDS9960 sensor
            %   % normalized with respect to clear light value
            %   val = readColor(apds9960Obj);
            %   [val, timestamp] = readColor(apds9960Obj);
            %   [val, timestamp] = readColor(apds9960Obj, 'normalized');
            %
            %   % Read raw values of clear light and RGB components
            %   % measured by APDS9960 sensor
            %   val = readColor(apds9960Obj, 'raw');
            %   [val, timestamp] = readColor(apds9960Obj, 'raw');
            %
            %   See also readProximity, readGesture

            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent, 'APDS9960', varargin{:}));
            try
                narginchk(1, 2);
                IsNormalized = true;
                if isequal(nargin, 2)
                    colorMode = varargin{1};
                    if (isstring(colorMode) || ischar(colorMode)) && ismember(lower(char(colorMode)), {'raw', 'normalized'})
                        if strcmpi(char(colorMode), 'raw')
                            IsNormalized = false;
                        end
                    else
                        obj.localizedError('MATLAB:arduinoio:general:InvalidAPDS9960ColorMode', num2str(colorMode));
                    end
                end
                % Read color data bytes from the sensor
                colorDataRaw = readRegister(obj.I2CObj, obj.APDS9960_COLOR_DATA, 'uint64');
                % Separate out the clear light, R, G, and B component values
                colorDataRaw = typecast(uint64(colorDataRaw), 'uint16');
                clearChannelData = colorDataRaw(1);
                RData = colorDataRaw(2);
                GData = colorDataRaw(3);
                BData = colorDataRaw(4);
                colorData = [clearChannelData, RData, GData, BData];
                % Normalize the color values
                % normalizeColor returns 1x3 RGB component values normalized with respect to current clear light value if
                % positional argument is not specified or is 'normalized'
                % normalizeColor returns 1x4 uint16 clear light + RGB component values if positional argument is specified as'raw'
                if IsNormalized
                    colorData = normalizeColor(obj, colorData);
                end
                timestamp = datetime;
            catch e
                integrateErrorKey(obj.Parent, e.identifier);
                throwAsCaller(e);
            end
        end
    end


    methods(Access = private)
        function createAPDS9960(obj)
            % Send command to the custom peripheral to set I2C bus number
            % and APDS9960 device address
            sendCommand(obj, obj.LibraryName, obj.APDS9960_CREATE_APDS9960, [obj.I2CObj.Bus, obj.APDS9960_DEVICE_ADDRESS]);
            % Initiate the APDS9960 register settings
            status = sendCommand(obj, obj.LibraryName, obj.APDS9960_INIT_APDS9960, []);
            if ~status
                obj.localizedError('MATLAB:arduinoio:general:InitAPDS9960Failed');
            end
        end

        function gesture = getGesture(~, gestureData)
            gestureData = reshape(gestureData, [4 numel(gestureData)/4])';
            % First column of gestureData is data obtained from up photodiode
            % Second column of gestureData is data obtained from down photodiode
            % Third column of gestureData is data obtained from left photodiode
            % Fourth column of gestureData is data obtained from right photodiode
            upData = gestureData(:, 1);
            downData = gestureData(:,2);
            leftData = gestureData(:,3);
            rightData = gestureData(:,4);
            upDownDifference = upData - downData;
            leftRightDifference = leftData - rightData;
            % For a up to down gesture, upDownDifference will always be
            % negative
            % For a down to up gesture, upDownDifference will always be
            % positive
            % For a left to right gesture, leftRightDifference will always be
            % negative
            % For a right to left gesture, leftRightDifference will always be
            % positive

            % Check if these curves are almost flat -> it's not a gesture.
            % Values obtained from up, down, left, and right photodiodes do
            % not vary much with respect to time or they roughly represent flat curves.
            % This is because there is no substantial movement detected by
            % the photodiodes for a gesture to be considered as 'none'.
            % Whereas for other valid cases, the values detected by the
            % up, down, left, and right photodiodes have a positive slope to it
            % Refer to the directional orientation in the APDS9960
            % datasheet to understand the photodiode responses
            % https://cdn.sparkfun.com/datasheets/Sensors/Proximity/apds9960.pdf
            % Compute mean of first two halves of each curve
            % if the curves are to be considered as flat, these mean values
            % should not deviate much with respect to each other.
            % Get the first halves of the up data
            upDataFirstHalf = upData(1:floor(0.5*numel(upData)));
            upDataSecondHalf = upData(numel(upDataFirstHalf):end);
            % Compute the mean values of these halves
            MeanUpDataFirstHalf = mean(upDataFirstHalf);
            MeanUpDataSecondHalf = mean(upDataSecondHalf);

            % Get the first halves of the down data
            downDataFirstHalf = downData(1:floor(0.5*numel(downData)));
            downDataSecondHalf = downData(numel(downDataFirstHalf):end);
            % Compute the mean values of these halves
            MeanDownDataFirstHalf = mean(downDataFirstHalf);
            MeanDownDataSecondHalf = mean(downDataSecondHalf);

            % Get the first halves of the left data
            leftDataFirstHalf = leftData(1:floor(0.5*numel(leftData)));
            leftDataSecondHalf = leftData(numel(leftDataFirstHalf):end);
            % Compute the mean values of these halves
            MeanLeftDataFirstHalf = mean(leftDataFirstHalf);
            MeanLeftDataSecondHalf = mean(leftDataSecondHalf);

            % Get the first halves of the right data
            rightDataFirstHalf = rightData(1:floor(0.5*numel(rightData)));
            rightDataSecondHalf = rightData(numel(rightDataFirstHalf):end);
            % Compute the mean values of these halves
            MeanRightDataFirstHalf = mean(rightDataFirstHalf);
            MeanRightDataSecondHalf = mean(rightDataSecondHalf);

            % If the difference between the mean values of the two halves of each
            % curve is less than a threshold of 10, these curves should be
            % considered as flat.
            % The curves are considered to be flat if there is no movement
            % detected by the sesnor or is not properly detected due to
            % a) target is too far from the sensor
            % b) target is too slow to be detected as a gesture
            % c) kept stationary over the sensor
            if ~(abs(MeanUpDataFirstHalf - MeanUpDataSecondHalf) < 10 && abs(MeanDownDataFirstHalf - MeanDownDataSecondHalf) < 10 && abs(MeanLeftDataFirstHalf - MeanLeftDataSecondHalf) < 10 && abs(MeanRightDataFirstHalf - MeanRightDataSecondHalf) < 10)
                % If there is a larger deviation between Up and Down data in
                % comparison to the deviation in Left and Right data
                % i.e. if the maxima of |U-D| > maxima of |L-R|, this
                % condition points to a dominant movement either along Up
                % or Down direction with respect to the sensor.
                % If there is larger deviation between Left and Right data in
                % comparison to the deviation in Up and Down data
                % i.e. if the maxima of |L-R| > maxima of |U-D|, this
                % condition points to a dominant movement either along Left
                % or Right direction with respect to the sensor
                if max(abs(upDownDifference)) > max(abs(leftRightDifference))
                    % For a Up to Down movement, the Up data usually has
                    % lesser values compared to Down data. This is because
                    % more energy is reflected back into the Down
                    % photodiode when a target is moved in a direction from
                    % Up to Down
                    if sum(upDownDifference) < 0
                        gesture = arduinoio.sensors.apds9960.Gestures.down;
                    else
                        gesture = arduinoio.sensors.apds9960.Gestures.up;
                    end
                else
                    % For a Left to Right movement, the Left data usually has
                    % lesser values compared to Right data. This is because
                    % more energy is reflected back into the Right
                    % photodiode when a target is moved in a direction from
                    % Left to Right
                    if sum(leftRightDifference) < 0
                        gesture = arduinoio.sensors.apds9960.Gestures.right;
                    else
                        gesture = arduinoio.sensors.apds9960.Gestures.left;
                    end
                end
            else
                % Gesture is 'none' if the up, down, left, and right curves
                % are flat i.e. no substantial movement is detected by the
                % sensor
                gesture = arduinoio.sensors.apds9960.Gestures.none;
            end
        end

        function setMode(obj , mode, enable)
            % Enable register (0x80)
            % | 0 | gestureEnable | 0 | 0 | x | proximityEnable | colorEnable | powerEnable |
            % Set bits in the enable register
            try
                validateattributes(enable, {'double', 'uint8', 'logical'}, {'scalar', 'real', 'finite', 'nonnan'});
                mode = validatestring(mode, {'proximityEnable', 'colorEnable', 'gestureEnable', 'powerEnable'});
                regVal = readRegister(obj.I2CObj, obj.APDS9960_ENABLE_REGISTER, 1);
                switch mode
                    case 'powerEnable'
                        % Bit 0 in enable register needs to be cleared first -
                        % left shift the enable by 0 bits
                        % perform bitand on enable and 0xFE (bit 0 is zero)
                        writeVal = bitor(enable, bitand(regVal, 254));
                    case 'colorEnable'
                        % Bit 1 in enable register needs to be cleared first -
                        % left shift the enable by 1 bit
                        % perform bitand on enable and 0xFD (bit 1 is zero)
                        writeVal = bitor(bitshift(enable, 1), bitand(regVal, 253));
                    case 'proximityEnable'
                        % Bit 2 in enable register needs to be cleared first -
                        % left shift the enable by 2 bits
                        % perform bitand on enable and 0xFB (bit 2 is zero)
                        writeVal = bitor(bitshift(enable, 2), bitand(regVal, 251));
                    case 'gestureEnable'
                        % Bit 6 in enable register needs to be cleared first -
                        % left shift the enable by 6 bits
                        % perform bitand on enable and 0xBF (bit 6 is zero)
                        writeVal = bitor(bitshift(enable, 6), bitand(regVal, 191));
                end
                writeRegister(obj.I2CObj, obj.APDS9960_ENABLE_REGISTER, writeVal);
            catch e
                throwAsCaller(e);
            end
        end

        function enableProximity(obj, enable)
            % Turn on the Proximity engine by
            % setting proximityEnable bit in the enable register
            setMode(obj, 'proximityEnable', enable);
        end

        function enableColor(obj, enable)
            % Turn on the Color engine by
            % setting colorEnable bit in the enable register
            setMode(obj, 'colorEnable', enable);
            if enable
                obj.ColorEnabled = true;
            else
                obj.ColorEnabled = false;
            end
        end

        function enableGesture(obj, enable)
            % Disable the Color engine before turning on the gesture
            % engine. At the constructor call, Proximity and Color engines are
            % initially enabled.
            if obj.ColorEnabled
                enableColor(obj, 0);
            end

            if enable
                % Turn on the Gesture engine by
                % setting gestureEnable bit in the enable register
                setMode(obj, 'gestureEnable', 1);
            else
                % Turn off the Gesture engine once a gesture has been read
                setMode(obj, 'gestureEnable', 0);
                % Turn on the Color engine once a gesture has been read
                enableColor(obj, 1);
            end
        end

        function  enablePower(obj, enable)
            % Turn on the internal circuitry by
            % setting powerEnable bit in the enable register
            setMode(obj, 'powerEnable', enable);
        end

        function normalizedProximity = normalizeProximity(obj, proximity)
            % Sensor returns a raw value where 0 -> far and 255 -> near.
            % Aligning the convention with respect to 0 -> near and 255 -> far
            proximity = obj.MaxProximityRawValue  - double(proximity);
            % Normalize the raw value with respect to Max raw value
            normalizedProximity = proximity/obj.MaxProximityRawValue;
        end

        function normalizedColor = normalizeColor(~, colorData)
            normalizedColor = double(colorData);
            % Pull out the clear light value
            ClearLightValue = normalizedColor(1);
            if ~all(find(normalizedColor) == 0)
                % Normalize the R,G,B component values with respect to the
                % clear light value
                normalizedColor = normalizedColor(2:end)/ClearLightValue;
            else
                % If the perceived raw values are zero, do not divide
                % by clear light value which is also 0
                normalizedColor = normalizedColor(2:end);
            end
        end
    end

    methods(Access = {?arduinoio.sensors.apds9960.GestureConfiguration, ?arduinoio.sensors.apds9960.ProximityConfiguration, ?arduinoio.sensors.apds9960.ColorConfiguration})
        function validateSensorParam(~, val, mode, param, validValue)
            try
                % mode is the APDS9960 mode - Gesture, Proximity, or Color
                % param is the mode specific value like Gain, LEDCurrent,
                % LEDBoost, PulseCount, or PulseWidth
                % validValue is an array of param specific valid values
                % For PulseCount, validValue is the upper limit of the
                % allowable pulse count value
                % Combine mode and param to include in the error message
                mode = [mode, ' ', param];
                switch param
                    case "PulseCount"
                        % Check if the PulseCount value is valid and within the
                        % valid range.
                        matlabshared.hwsdk.internal.validateIntParameterRanged(mode, val, 1, validValue);
                    case "LEDCurrent"
                        % validateDoubleParameterPos is used here as LEDCurrent
                        % values can be double e.g. 12.5. Check if LEDCurent is
                        % a valid value i.e. double or int
                        matlabshared.hwsdk.internal.validateDoubleParameterPos(mode, val);
                        if ~any(ismember(validValue, val))
                            % Throw error if LEDCurrent value doesn't belong to
                            % the valid LEDCurrent values
                            matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:invalidIntValue', ...
                                mode, matlabshared.hwsdk.internal.renderArrayOfIntsToString(validValue))
                        end
                    otherwise
                        % Check if other parameters like Gain, LEDBoost, and
                        % PulseWidth are valid values i.e. integer or double.
                        matlabshared.hwsdk.internal.validateIntParameter(mode, val, validValue);
                end
            catch e
                switch e.identifier
                    case 'MATLAB:hwsdk:general:invalidIntTypeRanged'
                        % Throw a correct error for PulseCount
                        % corresponding to invalid integer value range
                        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntValueRanged', ...
                            mode, num2str(1), num2str(validValue));
                    case {'MATLAB:arduinoio:general:invalidIntType', 'MATLAB:hwsdk:general:invalidDoubleTypePos'}
                        % Throw a correct for parameters being of
                        % non-numeric data types
                        matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:invalidIntValue', ...
                            mode, matlabshared.hwsdk.internal.renderArrayOfIntsToString(validValue));
                    otherwise
                        % Throw error for invalid parameter values
                        throwAsCaller(e);
                end
            end
        end
    end

    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            fprintf('         I2CAddress: %-1d (''0x%02s'')\n', obj.I2CAddress, dec2hex(obj.I2CAddress));
            fprintf('                Bus: %d\n', obj.Bus);
            fprintf('             SCLPin: ''%s''\n', obj.SCLPin);
            fprintf('             SDAPin: ''%s''\n', obj.SDAPin);
            fprintf('            BitRate: %d (bits/s)\n', obj.BitRate);
            % Allow for the possibility of a footer.
            footer = matlabshared.hwsdk.internal.footer(inputname(1));
            if ~isempty(footer)
                disp(footer);
            end
            fprintf('\n');
        end
    end

    methods(Access = public, Hidden, Sealed)
        function showAllProperties(obj)
            fprintf('         I2CAddress: %-1d (''0x%02s'')\n', obj.I2CAddress, dec2hex(obj.I2CAddress));
            fprintf('                Bus: %d\n', obj.Bus);
            fprintf('             SCLPin: ''%s''\n', obj.SCLPin);
            fprintf('             SDAPin: ''%s''\n', obj.SDAPin);
            fprintf('            BitRate: %d (bits/s)\n', obj.BitRate);
            fprintf('            Gesture: [1x1 GestureConfiguration]\n');
            fprintf('          Proximity: [1x1 ProximityConfiguration]\n');
            fprintf('              Color: [1x1 ColorConfiguration]\n\n');
            fprintf('\n');
        end
    end
end

