classdef ProximityConfiguration < matlab.mixin.CustomDisplay & handle
    %ProximityConfiguration   Contains set methods to configure Proximity
    %parameters
    %   Configures Proximity Gain, LEDCurrent, LEDBoost, PulseCount, and
    %   PulseWidth
    %
    %   Copyright 2021 The MathWorks, Inc.

    properties(Access = public)
        %Gain - Proximity Gain control
        Gain = 4
        %LEDCurrent - Proximity LED drive strength.
        %   Intensity of the IR emission is selectable using four,
        %   factory calibrated, current levels. Sets LED drive
        %   strength in proximity mode
        LEDCurrent = 100
        %LEDBoost - Boost LED drive current up to an additional 300%
        %   Provides additional LED drive current during proximity and
        %   gesture LED pulses if a higher intensity is required
        LEDBoost = 100
        %PulseCount - Number of Proximity pulses.
        %   Specifies the number of pulses to be generated on LED
        PulseCount = 10
        %PulseWidth - Proximity Pulse Length.
        %   Sets the LED pulse width during a Proximity LED drive pulse.
        PulseWidth = 8
    end

    properties(Access = private)
        % Valid values of the Gain, LEDCurrent, LEDBoost, PulseCount, and
        % PulseWidth properties
        %MaxProximityPulseCount - Maximum number of Proximity pulses allowed
        MaxProximityPulseCount   = 64
        %ValidProximityGain - Valid Proximity gain values
        ValidProximityGain       = [1, 2, 4, 8]
        %ValidProximityLEDCurrent - Valid LED drive current values in mA
        ValidProximityLEDCurrent = [100, 50, 25, 12.5]  % in mA
        %ValidProximityLEDBoost - Valid LED drive current boost percentage
        ValidProximityLEDBoost   = [100, 150, 200, 300]
        %ValidProximityPulseWidth - Valid LED pulse width values in
        %microseconds
        ValidProximityPulseWidth = [4, 8, 16, 32]

        % Proximity Pulse Count Register
        APDS9960_PROXIMITY_PULSECOUNT = 0x8E
        % Control Register One - Control Proximity LEDCurrent, Proximity Gain, and Color gain
        APDS9960_CONTROL_ONE = 0x8F
        % Configuration Register Two - Set LEDBoost for Proximity and Gesture
        APDS9960_CONFIGURE_TWO = 0x90
    end

    properties(Access = private, WeakHandle)
        ParentObj arduinoio.sensors.apds9960.APDS9960 % Parent object is the APDS9960 object
    end

    methods(Hidden, Access = public)
        function obj = ProximityConfiguration(apds9960Obj)
            %ProximityConfiguration   Configures the Proximity parameter setting

            % Hold the apds9960 object in the ParentObj property
            obj.ParentObj = apds9960Obj;
        end
    end

    methods
        function set.Gain(obj, val)
            % Set method to configure Proximity specific register settings
            % for Gain control
            try
                configureProximitySensor(obj, 'Gain', val);
                obj.Gain = val;
            catch e
                throwAsCaller(e);
            end
        end

        function set.LEDCurrent(obj, val)
            % Set method to configure Proximity specific register settings
            % for LEDCurrent control
            try
                configureProximitySensor(obj, 'LEDCurrent', val);
                obj.LEDCurrent = val;
            catch e
                throwAsCaller(e);
            end
        end

        function set.LEDBoost(obj, val)
            % Set method to configure Proximity specific register settings
            % for LEDBoost control
            try
                configureProximitySensor(obj, 'LEDBoost', val);
                setLEDBoostValue(obj, val);
            catch e
                throwAsCaller(e);
            end
        end

        function set.PulseCount(obj, val)
            % Set method to configure Proximity specific register settings
            % for PulseCount control
            try
                configureProximitySensor(obj, 'PulseCount', val);
                obj.PulseCount = val;
            catch e
                throwAsCaller(e);
            end
        end

        function set.PulseWidth(obj, val)
            % Set method to configure Proximity specific register settings
            % for PulseWidth control
            try
                configureProximitySensor(obj, 'PulseWidth', val);
                obj.PulseWidth = val;
            catch e
                throwAsCaller(e);
            end
        end
    end

    methods(Access = private)
        function configureProximitySensor(obj, param, val)
            % Configure the proximity specific register
            % settings for controlling Gain, LEDCurrent, LEDBoost,
            % PulseCount, and PulseWidth
            switch param
                case 'Gain'
                    obj.ParentObj.validateSensorParam(val, 'Proximity', param, obj.ValidProximityGain);
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONTROL_ONE, 1);
                    % The bit value to be written to the register is 0, 1, 2, or 3
                    % which is found by fetching the index of the correct value of
                    % parameter value (provided as an argument to the method)
                    % from the ValidProximityGain vector and to align with
                    % the C style of indexing, one is subtracted from it
                    bitVal = find(obj.ValidProximityGain == val) - 1;
                    % Bits 3:2 needs to be cleared first -
                    % left shift the bitVal by 2 bits
                    % perform bitwise AND operation on regVal and 0xF3 (bits 3:2 are zeros)
                    writeVal = bitor(bitshift(bitVal, 2), bitand(regVal, 243));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONTROL_ONE, writeVal);
                case 'LEDCurrent'
                    obj.ParentObj.validateSensorParam(val, 'Proximity', param, obj.ValidProximityLEDCurrent);
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONTROL_ONE, 1);
                    % The bit value to be written to the register is 0, 1, 2, or 3
                    % which is found by fetching the index of the correct value of
                    % parameter value (provided as an argument to the method)
                    % from the ValidProximityLEDCurrent vector and to align with
                    % the C style of indexing, one is subtracted from it
                    bitVal = find(obj.ValidProximityLEDCurrent == val) - 1;
                    % Bits 7:6 needs to be cleared first -
                    % left shift the bitVal by 6 bits
                    % perform bitwise AND operation on regVal and 0x3F (bits 7:6 are zeros)
                    writeVal = bitor(bitshift(bitVal, 6), bitand(regVal, 63));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONTROL_ONE, writeVal);
                case 'LEDBoost'
                    obj.ParentObj.validateSensorParam(val, 'Proximity', param, obj.ValidProximityLEDBoost);
                    % The bit value to be written to the register is 0, 1, 2, or 3
                    % which is found by fetching the index of the correct value of
                    % parameter value (provided as an argument to the method)
                    % from the ValidProximityLEDBoost vector and to align with
                    % the C style of indexing, one is subtracted from it
                    bitVal = find(obj.ValidProximityLEDBoost == val) - 1;
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONFIGURE_TWO, 1);
                    % Bits 5:4 needs to be cleared first -
                    % left shift the bitVal by 4 bits
                    % perform bitwise AND operation on regVal and 0xCF (bits 5:4 are zeros)
                    writeVal = bitor(bitshift(bitVal, 4), bitand(regVal, 207));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONFIGURE_TWO, writeVal);
                case 'PulseCount'
                    obj.ParentObj.validateSensorParam(val, 'Proximity', param, obj.MaxProximityPulseCount);
                    bitVal = val - 1;
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_PROXIMITY_PULSECOUNT, 1);
                    % Bits 5:0 needs to be cleared first -
                    % left shift the bitVal by 0 bits
                    % perform bitwise AND operation on regVal and 0xC0 (bits 5:0 are zeros)
                    writeVal = bitor(bitVal, bitand(regVal, 192));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_PROXIMITY_PULSECOUNT, writeVal);
                case 'PulseWidth'
                    obj.ParentObj.validateSensorParam(val, 'Proximity',param, obj.ValidProximityPulseWidth);
                    % The bit value to be written to the register is 0, 1, 2, or 3
                    % which is found by fetching the index of the correct value of
                    % parameter value (provided as an argument to the method)
                    % from the ValidProximityPulseWidth vector and to align with
                    % the C style of indexing, one is subtracted from it
                    bitVal = find(obj.ValidProximityPulseWidth == val) - 1;
                    regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_PROXIMITY_PULSECOUNT, 1);
                    % Bits 7:6 needs to be cleared first -
                    % left shift the bitVal by 6 bits
                    % perform bitwise AND operation on regVal and 0x3F (bits 7:6 are zeros)
                    writeVal = bitor(bitshift(bitVal, 6), bitand(regVal, 63));
                    writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_PROXIMITY_PULSECOUNT, writeVal);
            end
        end

        function obj = setLEDBoostValue(obj, val)
            % Set the value of APDS9960's LEDBoost property shared by
            % ProximityConfiguration and GestureConfiguration classes
            % Since LEDBoost register setting is common for Gesture and
            % Proximity, setting this value with either of the configuration
            % classes's get.LEDBoost method, should get reflected in both of
            % the Gesture.LEDBoost and Proximity.LEDBoost properties
            obj.ParentObj.LEDBoostValue = val;
        end

        function displayMainProperties(obj)
            % Display the main properties of the ProximityConfiguration
            % class
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
            % this will ensure the ProximityConfiguration object held by the
            % apds9960 object is destroyed
        end
    end
end


