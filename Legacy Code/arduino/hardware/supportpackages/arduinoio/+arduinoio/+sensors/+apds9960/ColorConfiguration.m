classdef ColorConfiguration  < matlab.mixin.CustomDisplay & handle
    %ColorConfiguration   Contains set methods to configure Color
    %parameters
    %   Configures Color Gain
    %
    %   Copyright 2021 The MathWorks, Inc.

    properties(Access = public)
        %Gain - Color Gain control, defaults to 1
        Gain = 1
    end

    properties(Access = private)
        %ValidColorGain - Valid Gain values
        ValidColorGain = [1, 4, 16, 64]
        %APDS9960_CONTROL_ONE - Control Proximity LEDCurrent,
        %   Proximity Gain, and Color gain
        APDS9960_CONTROL_ONE = 0x8F
    end

    properties(Access = private, WeakHandle)
        ParentObj arduinoio.sensors.apds9960.APDS9960 % Parent object is the APDS9960 object
    end

    methods(Hidden, Access = public)
        function obj = ColorConfiguration(apds9960Obj)
            %ColorConfiguration   Configures the Color parameter setting

            % Hold the apds9960Obj in the ParentObj property
            obj.ParentObj = apds9960Obj;
        end
    end

    methods
        function set.Gain(obj, val)
            % Set method to configure Color specific register
            % settings for Gain
            try
                configureColorSensor(obj, val);
                obj.Gain = val;
            catch e
                throwAsCaller(e);
            end
        end
    end

    methods(Access = private)
        function configureColorSensor(obj, val)
            % Configure the color specific register
            % settings for controlling Gain
            obj.ParentObj.validateSensorParam(val, 'Color', 'Gain', obj.ValidColorGain);
            % The bit value to be written to the register is 0, 1, 2, or 3
            % which is found by fetching the index of the correct value of
            % parameter value (provided as an argument to the method)
            % from the ValidColorGain vector and to align with
            % the C style of indexing, one is subtracted from it
            bitVal = find(obj.ValidColorGain == val) - 1;
            regVal = readRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONTROL_ONE, 1);
            % Bits 1:0 needs to be cleared first -
            % left shift the bitVal by 0 bits
            % perform bitwise AND operation on regVal and 0xFC (bits 1:0 are zeros)
            writeVal = bitor(bitVal, bitand(regVal, 252));
            writeRegister(obj.ParentObj.I2CObj, obj.APDS9960_CONTROL_ONE, writeVal);
        end

        function displayMainProperties(obj)
            fprintf('         Gain: %d\n', obj.Gain);
            fprintf('\n');
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
            % this will ensure the ColorConfiguration object held by the
            % apds9960 object is destroyed
        end
    end
end

