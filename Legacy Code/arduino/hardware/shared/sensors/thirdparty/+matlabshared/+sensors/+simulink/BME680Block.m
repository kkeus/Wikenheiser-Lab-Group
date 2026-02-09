classdef BME680Block < matlab.System ...
        & coder.ExternalDependency ...
        & matlabshared.sensors.simulink.internal.I2CSensorBase ...
        & matlabshared.sensors.simulink.internal.BlockSampleTime ...
        & matlabshared.sensors.simulink.internal.CommonFunctionsFor3pRecipe

    % Block outputs pressure, humidity, temperature and IAQ values.
    %#codegen
    %#ok<*EMCA>

    % Copyright 2022-2024 The MathWorks, Inc.

    properties(Access = protected)
        Logo = 'SENSORS'
    end

    properties (Nontunable)
        I2CModule = '';
        I2CAddress = '0x77';
        SensorPowerMode(1,:) char {matlab.system.mustBeMember(SensorPowerMode,{'Continuous (ODR = 1Hz)','Low power (ODR = 0.33Hz)','Ultra low power (ODR = 3.3mHz)'})} = 'Low power (ODR = 0.33Hz)';
        IsActiveHumidity (1, 1) logical = true;
        IsActivePressure (1, 1) logical = true;
        IsActiveTemperature (1, 1) logical = true;
        IsActiveIAQ (1, 1) logical = true;
        IsActiveeCO2 (1, 1) logical = false;
        IsActivebVOC (1, 1) logical = false;
        IsIAQStatus (1, 1) logical = false;
    end

    properties (Access = private)
        % Pre-computed constants.
    end

    properties(Nontunable, Access = protected)
        I2CBus;
    end

    properties(Hidden, Constant)
        I2CAddressSet = matlab.system.StringSet({'0x76','0x77'});
    end

    methods
        % Constructor
        function obj = BME680Block(varargin)
            % Support name-value pair arguments when constructing the object.
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods (Access=protected)
        function setupImpl(obj)
            setValidatedI2CBus(obj);
            switch obj.I2CAddress
                case '0x77'
                    i2caddress = int32(1);
                case '0x76'
                    i2caddress = int32(2);
            end
            switch obj.SensorPowerMode
                case 'Low power (ODR = 0.33Hz)'
                    modeValue = int32(1);
                case 'Continuous (ODR = 1Hz)'
                    modeValue = int32(2);
                case 'Ultra low power (ODR = 3.3mHz)'
                    modeValue = int32(3);
            end
            if coder.target('rtw')
                % Call C-function implementing device initialization
                coder.cinclude('BME68x.h');
                coder.ceval('setupFunction',i2caddress,modeValue);
            end
        end

        function varargout= stepImpl(obj)
            pressure = single(0);
            temperature = single(0);
            humidity = single(0);
            iaq = single(0);
            eCO2 = single(0);
            bVOC = single(0);
            iaqStatus = single(0);
            if coder.target('rtw')
                % Call C-function implementing device output
                coder.ceval('stepFunction',coder.ref(pressure),coder.ref(temperature),coder.ref(humidity),coder.ref(iaq),coder.ref(eCO2),coder.ref(bVOC),coder.ref(iaqStatus));
            end
            if isequal(iaqStatus,1)
                iaqStatus = single(0);
            else
                iaqStatus = single(1);
            end
            count = 1;
            if obj.IsActivePressure
                varargout{count} = pressure;
                count = count + 1;
            end
            if obj.IsActiveTemperature
                varargout{count} = temperature;
                count = count + 1;
            end
            if obj.IsActiveHumidity
                varargout{count} = humidity;
                count = count + 1;
            end
            if obj.IsActiveIAQ
                varargout{count} = iaq;
                count = count + 1;
            end
            if obj.IsActiveeCO2
                varargout{count} = eCO2;
                count = count + 1;
            end
            if obj.IsActivebVOC
                varargout{count} = bVOC;
                count = count + 1;
            end
            if obj.IsIAQStatus && obj.IsActiveIAQ
                varargout{count} =uint8(iaqStatus);
            end


        end

        function releaseImpl(obj)
            if isempty(coder.target)
                % Place simulation termination code here
            else
                % Call C-function implementing device termination

            end
        end
    end

    methods (Access=protected)
        %% Define output properties
        function num = getNumInputsImpl(~)
            num = 0;
        end

        function num = getNumOutputsImpl(obj)
            count = 0;
            if obj.IsActivePressure
                count = count + 1;
            end
            if obj.IsActiveTemperature
                count = count + 1;
            end
            if obj.IsActiveHumidity
                count = count + 1;
            end
            if obj.IsActiveIAQ
                count = count + 1;
            end
            if obj.IsActiveeCO2
                count = count + 1;
            end
            if obj.IsActivebVOC
                count = count + 1;
            end
            if obj.IsIAQStatus && obj.IsActiveIAQ
                count = count + 1;
            end
            num = count;
        end

        function varargout = getOutputNamesImpl(obj)
            % Return output port names for System block
            count = 1;
            if obj.IsActivePressure
                varargout{count} = 'Pressure';
                count = count + 1;
            end
            if obj.IsActiveTemperature
                varargout{count} = 'Temperature';
                count = count + 1;
            end
            if obj.IsActiveHumidity
                varargout{count} = 'Humidity';
                count = count + 1;
            end
            if obj.IsActiveIAQ
                varargout{count} = 'IAQ';
                count = count + 1;
            end
            if obj.IsActiveeCO2
                varargout{count} = 'eCO2';
                count = count + 1;
            end
            if obj.IsActivebVOC
                varargout{count} = 'bVOC';
                count = count + 1;
            end
            if obj.IsIAQStatus && obj.IsActiveIAQ
                varargout{count} = 'IAQStatus';
            end
        end

        function flag = isOutputSizeLockedImpl(~,~)
            flag = true;
        end

        function varargout = isOutputFixedSizeImpl(obj,~)
            count = 1;
            if obj.IsActivePressure
                varargout{count} = true;
                count = count + 1;
            end
            if obj.IsActiveTemperature
                varargout{count} = true;
                count = count + 1;
            end
            if obj.IsActiveHumidity
                varargout{count} = true;
                count = count + 1;
            end
            if obj.IsActiveIAQ
                varargout{count} = true;
                count = count + 1;
            end
            if obj.IsActiveeCO2
                varargout{count} = true;
                count = count + 1;
            end
            if obj.IsActivebVOC
                varargout{count} = true;
                count = count + 1;
            end
            if obj.IsIAQStatus && obj.IsActiveIAQ
                varargout{count} = true;
            end
        end

        function varargout = isOutputComplexImpl(obj)
            count = 1;
            if obj.IsActivePressure
                varargout{count} = false;
                count = count + 1;
            end
            if obj.IsActiveTemperature
                varargout{count} = false;
                count = count + 1;
            end
            if obj.IsActiveHumidity
                varargout{count} = false;
                count = count + 1;
            end
            if obj.IsActiveIAQ
                varargout{count} = false;
                count = count + 1;
            end
            if obj.IsActiveeCO2
                varargout{count} = false;
                count = count + 1;
            end
            if obj.IsActivebVOC
                varargout{count} = false;
                count = count + 1;
            end
            if obj.IsIAQStatus && obj.IsActiveIAQ
                varargout{count} = false;
            end
        end

        function varargout = getOutputSizeImpl(obj)
            count = 1;
            if obj.IsActivePressure
                varargout{count} = [1,1];
                count = count + 1;
            end
            if obj.IsActiveTemperature
                varargout{count} = [1,1];
                count = count + 1;
            end
            if obj.IsActiveHumidity
                varargout{count} = [1,1];
                count = count + 1;
            end
            if obj.IsActiveIAQ
                varargout{count} = [1,1];
                count = count + 1;
            end
            if obj.IsActiveeCO2
                varargout{count} = [1,1];
                count = count + 1;
            end
            if obj.IsActivebVOC
                varargout{count} = [1,1];
                count = count + 1;
            end
            if obj.IsIAQStatus && obj.IsActiveIAQ
                varargout{count} = [1,1];
            end
        end

        function varargout = getOutputDataTypeImpl(obj)
            count = 1;
            if obj.IsActivePressure
                varargout{count} = 'single';
                count = count + 1;
            end
            if obj.IsActiveTemperature
                varargout{count} = 'single';
                count = count + 1;
            end
            if obj.IsActiveHumidity
                varargout{count} = 'single';
                count = count + 1;
            end
            if obj.IsActiveIAQ
                varargout{count} = 'single';
                count = count + 1;
            end
            if obj.IsActiveeCO2
                varargout{count} = 'single';
                count = count + 1;
            end
            if obj.IsActivebVOC
                varargout{count} = 'single';
                count = count + 1;
            end
            if obj.IsIAQStatus && obj.IsActiveIAQ
                varargout{count} = 'uint8';
            end
        end

        % Block mask display
        function maskDisplayCmds = getMaskDisplayImpl(obj)
            outport_label = [];
            num = getNumOutputsImpl(obj);
            if num > 0
                outputs = cell(1,num);
                [outputs{1:num}] = getOutputNamesImpl(obj);
                for i = 1:num
                    outport_label = [outport_label 'port_label(''output'',' num2str(i) ',''' outputs{i} ''');' ]; %#ok<AGROW>
                end
            end
            icon = 'BME68x';
            maskDisplayCmds = [ ...
                ['color(''white'');',...
                'plot([100,100,100,100]*1,[100,100,100,100]*1);',...
                'plot([100,100,100,100]*0,[100,100,100,100]*0);',...
                'color(''blue'');', ...
                ['text(38, 92, ','''',obj.Logo,'''',',''horizontalAlignment'', ''right'');',newline],...
                'color(''black'');'], ...
                ['text(52,50,' [''' ' icon ''',''horizontalAlignment'',''center'');' newline]]   ...
                outport_label
                ];
        end

        function flag = isInactivePropertyImpl(obj, prop)
            flag = false;
            switch prop
                case "IsIAQStatus"
                    flag = ~obj.IsActiveIAQ;
            end
        end

        function validatePropertiesImpl(obj)
            % Validate related or interdependent property values
            % Check whether all outputs are disabled. In that case an error is
            % thrown asking user to enable atleast one output
            if ~obj.IsActivePressure && ~obj.IsActiveHumidity && ~(obj.IsIAQStatus && obj.IsActiveIAQ) && ~obj.IsActiveTemperature && ~obj.IsActiveIAQ && ~obj.IsActiveeCO2 && ~obj.IsActivebVOC
                error(message('matlab_sensors:general:SensorsNoOutputs'));
            end

        end

        function sts = getSampleTimeImpl(obj)
            sts = getSampleTimeImpl@matlabshared.sensors.simulink.internal.BlockSampleTime(obj);
        end
    end

    methods (Static, Access=protected)
        function simMode = getSimulateUsingImpl(~)
            simMode = 'Interpreted execution';
        end

        function isVisible = showSimulateUsingImpl
            isVisible = false;
        end
    end

    methods (Static)
        function name = getDescriptiveName(~)
            name = 'BME68x';
        end

        function tf = isSupportedContext(~)
            tf = true;
        end
    end

    methods(Access = protected, Static)
        function header = getHeaderImpl()
            header = matlab.system.display.Header(mfilename('class'), 'Title',...
                'BME68x Gas Sensor','Text',message('matlab_sensors:blockmask:bme680MaskDescription',char(0176)).getString,'ShowSourceLink',false);
        end
        function groups = getPropertyGroupsImpl
            i2cModule = matlab.system.display.internal.Property('I2CModule', 'Description', 'I2C module');
            i2cAddress = matlab.system.display.internal.Property('I2CAddress', 'Description', 'matlab_sensors:blockmask:bme680I2CAddress');
            sensorPowerMode = matlab.system.display.internal.Property('SensorPowerMode', 'Description', 'matlab_sensors:blockmask:bme680Mode');
            i2cProperties = matlab.system.display.Section('PropertyList', {i2cModule,i2cAddress,sensorPowerMode});
            % Select outputs
            humidityProp = matlab.system.display.internal.Property('IsActiveHumidity', 'Description','matlab_sensors:blockmask:bme680IsActiveHumidity','Row',matlab.system.display.internal.Row.current);
            pressureProp = matlab.system.display.internal.Property('IsActivePressure', 'Description','matlab_sensors:blockmask:bme680IsActivePressure','Row',matlab.system.display.internal.Row.current);
            temperatureProp = matlab.system.display.internal.Property('IsActiveTemperature', 'Description', message('matlab_sensors:blockmask:bme680IsActiveTemperature',char(0176)).getString,'Row',matlab.system.display.internal.Row.current);
            iaqProp = matlab.system.display.internal.Property('IsActiveIAQ', 'Description','matlab_sensors:blockmask:bme680IsActiveIAQ','Row',matlab.system.display.internal.Row.current);
            eCO2Prop = matlab.system.display.internal.Property('IsActiveeCO2', 'Description','matlab_sensors:blockmask:bme680IsActiveeCO2','Row',matlab.system.display.internal.Row.current);
            bVOCProp = matlab.system.display.internal.Property('IsActivebVOC', 'Description','matlab_sensors:blockmask:bme680IsActivebVOC','Row',matlab.system.display.internal.Row.current);
            statusProp= matlab.system.display.internal.Property('IsIAQStatus','Description', 'matlab_sensors:blockmask:bme680IsActiveIAQStatus');
            selectOutputs = matlab.system.display.Section('Title', 'Select outputs', 'PropertyList', {pressureProp,temperatureProp,humidityProp,iaqProp,statusProp,eCO2Prop,bVOCProp});
            % Sample time
            sampleTimeProp = matlab.system.display.internal.Property('SampleTime', 'Description', 'matlab_sensors:blockmask:bme680SampleTime');
            sampleTimeSection = matlab.system.display.Section('PropertyList', {sampleTimeProp});
            mainGroup = matlab.system.display.SectionGroup(...
                'Title','Parameters',...
                'Sections', [i2cProperties,selectOutputs,sampleTimeSection]);
            groups=mainGroup;
        end
    end
end
