classdef GestureConfiguration < matlab.mixin.CustomDisplay & handle
    %GestureConfiguration   Contains set methods to configure Gesture
    %parameters
    %   Configures the following properties under the gesture mode -
    %   Gain, LEDCurrent, LEDBoost, PulseCount, and PulseWidth
    %
    %   Copyright 2021 The MathWorks, Inc.


    properties(Access = public)
        %Gain - Gesture Gain control
        Gain = 4
        %LEDCurrent - Gesture LED drive strength.
        %   Intensity of the IR emission is selectable using four,
        %   factory calibrated, current levels. Sets LED drive
        %   strength in gesture mode
        LEDCurrent = 100
        %LEDBoost - Boost LED drive current up to an additional 300%
        %   Provides additional LED drive current during proximity and
        %   gesture LED pulses if a higher intensity is required
        LEDBoost   = 100
        %PulseCount - Number of Gesture pulses.
        %   Specifies the number of pulses to be generated on LED
        PulseCount = 10
        %PulseWidth - Gesture Pulse Length.
        %   Sets the LED pulse width during a Gesture LED drive pulse.
        PulseWidth = 8
    end

    properties(Access = private, WeakHandle)
        ParentObj arduinoio.sensors.apds9960.APDS9960 % Parent object is the APDS9960 object
    end

    properties(Access = private)
        % Valid values of the Gain, LEDCurrent, LEDBoost, PulseCount, and
        % PulseWidth properties
        %MaxGesturePulseCount - Maximum number of Gesture pulses allowed
        MaxGesturePulseCount   = 64
        %ValidGestureGain - Valid Gesture gain values
        ValidGestureGain       = [1, 2, 4, 8]
        %ValidGestureLEDCurrent - Valid LED drive current values in mA
        ValidGestureLEDCurrent = [100, 50, 25, 12.5]
        %ValidGestureLEDBoost - Valid LED drive current boost percentage
        ValidGestureLEDBoost   = [100, 150, 200, 300]
        %ValidGesturePulseWidth - Valid LED pulse width values in
        %microseconds
        ValidGesturePulseWidth = [4, 8, 16, 32]

        % Gesture Configuration Two - Set Gesture Gain and LEDCurrent
        APDS9960_GESTURE_CONFIGURE_TWO = 0xA3
        % Configuration Register Two - Set LEDBoost for Proximity and Gesture
        APDS9960_CONFIGURE_TWO = 0x90
        % Gesture Pulse Count and Pulse Width Register
        APDS9960_GESTURE_PULSE_SETTING = 0xA6
    end

    methods(Hidden, Access = public)
        function obj = GestureConfiguration(apds9960Obj)
            %GestureConfiguration   Configures the Gesture parameter setting

            % Hold the apds9960 object in the ParentObj property
            obj.ParentObj = apds9960Obj;
        end
    end

    methods
        function set.Gain(obj, val)
            % Set method to configure Gesture specific register settings
            % for Gain control
            try
                configureGestureSensor(obj, 'Gain', val);
                obj.Gain = val;
            catch e
                throwAsCaller(e);
            end
        end

        function set.LEDCurrent(obj, val)
            % Set method to configure Gesture specific register settings
            % for LEDCurrent control
            try
                configureGestureSensor(obj, 'LEDCurrent', val);
                obj.LEDCurrent = val;
            catch e
                throwAsCaller(e);
            end
        end

        function set.LEDBoost(obj, val)
            % Set method to configure Gesture specific register settings
            % for LEDBoost control
            try
                configureGestureSensor(obj, 'LEDBoost', val);
                setLEDBoostValue(obj, val);
            catch e
                throwAsCaller(e);
            end
        end

        function set.PulseCount(obj, val)
            % Set method to configure Gesture specific register settings
            % for PulseCount control
            try
                configureGestureSensor(obj, 'PulseCount', val);
                obj.PulseCount = val;
            catch e
                throwAsCaller(e);
            end
        end

        function set.PulseWidth(obj, val)
            % Set method to configure Gesture specific register settings
            % for PulseWidth control
            try
                configureGestureSensor(obj, 'PulseWidth', val);
                obj.PulseWidth = val;
            catch e
                throwAsCaller(e);
            end
        end
    end

    methods(Access = private)
        function configureGestureSensor(obj, param, val)
            % Configure the gesture specific register
            % settings for controlling Gain, LEDCurrent, LEDBoost,
            % PulseCount, and PulseWidth
            switch param
                case 'Gain'
                    obj.ParentObj.validateSensorParam(val, 'Gesture', param, obj.ValidGestureGain);
                    % The bit value to be written to the register is 0, 1, 2, or 3
                    % which is found by fetching the index of the correct value of
                    % parameter value (provided as an argument to the method)
                    % from the ValidGestureGain vector and to align with
                    % the C style of indexing, one is subtracted from it
                    bitVal = find(obj.ValidGestureGain == val) - 1;
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_GESTURE_CONFIGURE_TWO, 1);
                    % Bits 4:3 needs to be cleared first -
                    % left shift the bitVal by 5 bits
                    % perform bitwise AND operation on regVal and 0x9F (bits 6:5 are zeros)
                    writeVal = bitor(bitshift(bitVal, 5), bitand(regVal, 159));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_GESTURE_CONFIGURE_TWO, writeVal);
                case 'LEDCurrent'
                    obj.ParentObj.validateSensorParam(val, 'Gesture', param, obj.ValidGestureLEDCurrent);
                    % The bit value to be written to the register is 0, 1, 2, or 3
                    % which is found by fetching the index of the correct value of
                    % parameter value (provided as an argument to the method)
                    % from the ValidGestureLEDCurrent vector and to align with
                    % the C style of indexing, one is subtracted from it
                    bitVal = find(obj.ValidGestureLEDCurrent == val) - 1;
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_GESTURE_CONFIGURE_TWO, 1);
                    % Bits 4:3 needs to be cleared first -
                    % left shift the bitVal by 3 bits
                    % perform bitwise AND operation on regVal and 0xE7 (bits 4:3 are zeros)
                    writeVal = bitor(bitshift(bitVal, 3), bitand(regVal, 231));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_GESTURE_CONFIGURE_TWO, writeVal);
                case 'LEDBoost'
                    obj.ParentObj.validateSensorParam(val, 'Gesture', param, obj.ValidGestureLEDBoost);
                    % The bit value to be written to the register is 0, 1, 2, or 3
                    % which is found by fetching the index of the correct value of
                    % parameter value (provided as an argument to the method)
                    % from the ValidGestureLEDBoost vector and to align with
                    % the C style of indexing, one is subtracted from it
                    bitVal = find(obj.ValidGestureLEDBoost == val) - 1;
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONFIGURE_TWO, 1);
                    % Bits 5:4 needs to be cleared first -
                    % left shift the bitVal by 4 bits
                    % perform bitwise AND operation on regVal and 0xCF (bits 5:4 are zeros)
                    writeVal = bitor(bitshift(bitVal, 4), bitand(regVal, 207));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONFIGURE_TWO, writeVal);
                case 'PulseCount'
                    % Check for range first
                    obj.ParentObj.validateSensorParam(val, 'Gesture', param, obj.MaxGesturePulseCount);
                    bitVal = val - 1;
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_GESTURE_PULSE_SETTING, 1);
                    % Bits 5:0 needs to be cleared first -
                    % left shift the bitVal by 0 bits
                    % perform bitwise AND operation on regVal and 0xC0 (bits 5:0 are zeros)
                    writeVal = bitor(bitVal, bitand(regVal, 192));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_GESTURE_PULSE_SETTING, writeVal);
                case 'PulseWidth'
                    obj.ParentObj.validateSensorParam(val, 'Gesture', param, obj.ValidGesturePulseWidth);
                    % The bit value to be written to the register is 0, 1, 2, or 3
                    % which is found by fetching the index of the correct value of
                    % parameter value (provided as an argument to the method)
                    % from the ValidGesturePulseWidth vector and to align with
                    % the C style of indexing, one is subtracted from it
                    bitVal = find(obj.ValidGesturePulseWidth == val) - 1;
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_GESTURE_PULSE_SETTING, 1);
                    % Bits 7:6 needs to be cleared first -
                    % left shift the bitVal by 6 bits
                    % perform bitwise AND operation on regVal and 0x3F (bits 7:6 are zeros)
                    writeVal = bitor(bitshift(bitVal, 6), bitand(regVal, 63));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_GESTURE_PULSE_SETTING, writeVal);
            end
        end

        function obj = setLEDBoostValue(obj, val)
            % Set the value of APDS9960's LEDBoost value
            % Property shared by ProximityConfiguration and
            % GestureConfiguration classes. Since LEDBoost register
            % setting is common for Gesture and Proximity, setting this
            % value with either of the configuration classes's get.
            % LEDBoost method, should get reflected in both of the
            % Gesture.LEDBoost and Proximity.LEDBoost properties
            obj.ParentObj.LEDBoostValue = val;
        end

        function displayMainProperties(obj)
            % Display the main properties
            % The Gesture properties are Gain, LEDCurrent, LEDBoost,
            % PulseCount, and PulseWidth
            fprintf('         Gain: %d\n', obj.Gain);
            fprintf('   LEDCurrent: %d\n', obj.LEDCurrent);
            fprintf('     LEDBoost: %d\n', obj.LEDBoost);
            fprintf('   PulseCount: %d\n', obj.PulseCount);
            fprintf('   PulseWidth: %d\n', obj.PulseWidth);
            fprintf('\n');
        end
    end

    methods
        function val = get.LEDBoost(obj)
            % Fetch the APDS9960's LEDBoostValue
            % this is the value updated by issuing either
            % apds9960Obj.Gesture.LEDBoost or apds9960Obj.Proximity.LEDBoost
            val = obj.ParentObj.LEDBoostValue;
        end
    end

    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            displayMainProperties(obj);
        end

        function delete(~)
            % The destructor is called when APDS9960 object is deleted
            % this will ensure the GestureConfiguration object held by the
            % apds9960 object is destroyed
        end
    end
end

