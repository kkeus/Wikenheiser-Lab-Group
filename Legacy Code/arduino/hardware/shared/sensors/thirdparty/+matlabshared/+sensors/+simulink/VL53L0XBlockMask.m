classdef VL53L0XBlockMask < matlab.System & matlabshared.sensors.simulink.internal.I2CSensorBase & matlabshared.sensors.simulink.internal.BlockSampleTime
    % VL53L0X Time of Flight sensor
    % This sensor includes API's provided by ST Microelectronics.
    % VL53L0X block outputs distance of obstacle from microcontroller in mm.

    %   Copyright 2024 The MathWorks, Inc.

    %#codegen

    properties(Nontunable)
        I2CModule = '';
        I2CAddress = 0x29;
        RangingMode(1,:) char {matlab.system.mustBeMember(RangingMode,{'Default', 'High accuracy', 'Long range', 'High speed'})} = 'Default';
    end

    properties(Access = protected)
        Logo = 'SENSORS'
    end

    properties(Nontunable,Access = protected)
        I2CBus;
    end

    methods
        % Public methods
        function obj = VL53L0XBlock(obj)
            coder.allowpcode('plain');
        end

        function set.RangingMode(obj,value)
            obj.RangingMode=value;
        end

        function set.I2CAddress(obj,value)
            if ischar(value)
                value = string(value);
            end
            validateattributes(value,{'char','numeric','string'},{'nonempty','scalar'},'I2C Address');
            coder.extrinsic('matlabshared.sensors.internal.validateHexParameterRanged');
            value = coder.const(uint8(matlabshared.sensors.internal.validateHexParameterRanged(value)));
            if value> 7 && value < 120
                obj.I2CAddress = value;
            else
                coder.internal.errorIf(true,'matlab_sensors:general:outOfRangeI2CAddress');
            end
        end

    end

    methods (Access = protected)

        function setupImpl(obj)
            setValidatedI2CBus(obj);
            if ~coder.target('MATLAB')
                coder.cinclude('vl53l0x_main.h');
                coder.ceval('initializeVL53L0X',uint8(obj.I2CAddress),uint32(obj.I2CBus),obj.RangingMode);
            end
        end

        function [varargout] = stepImpl(obj)
            y=uint16(0);
            if ~coder.target('MATLAB')
                y = coder.ceval('calculateRange');
            end
            varargout{1} = y;
        end

        function releaseImpl(obj)
        end

        function N = getNumInputsImpl(~)
            % Specify number of System inputs
            N = 0;
        end

        function N = getNumOutputsImpl(obj)
            % Specify number of System outputs
            N=1;
        end

        function varargout = getOutputNamesImpl(obj)
            % Return output port names for System block
            varargout{1} = 'Distance';

        end

        function varargout= getOutputSizeImpl(obj)
            % Return size for each output port
            varargout{1} = [1,1];
        end

        function varargout = getOutputDataTypeImpl(obj)
            varargout{1} = 'uint16';
        end

        function varargout  = isOutputComplexImpl(obj)
            for i = 1 : obj.getNumOutputsImpl
                varargout{i} = false;
            end
        end

        function varargout   = isOutputFixedSizeImpl(obj)
            for i = 1 : obj.getNumOutputsImpl
                varargout{i} = true;
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
            maskDisplayCmds = [ ...
                ['color(''white'');',...
                'plot([100,100,100,100]*1,[100,100,100,100]*1);',...
                'plot([100,100,100,100]*0,[100,100,100,100]*0);',...
                'color(''blue'');', ...
                ['text(38, 92, ','''',obj.Logo,'''',',''horizontalAlignment'', ''right'');',newline],...
                'color(''black'');'], ...
                ['text(52,50,' [''' ' 'VL53L0X' ''',''horizontalAlignment'',''center'');' newline]]   ...
                outport_label
                ];
        end

        function sts = getSampleTimeImpl(obj)
            sts = getSampleTimeImpl@matlabshared.sensors.simulink.internal.BlockSampleTime(obj);
        end
    end

    methods(Static, Access = protected)
        % Note that this is ignored for the mask-on-mask
        function header = getHeaderImpl
            %getHeaderImpl Create mask header
            %   This only has an effect on the base mask.
            txtString = 'Measure distance to target for a complete field of view (FOV = 25 degrees) covered by a VL53L0X sensor. The block outputs distance measurement in millimeters (mm).';
            header = matlab.system.display.Header(mfilename('class'), 'Title',...
                'VL53L0X Time of Flight Sensor','Text',txtString,'ShowSourceLink',false);
        end

        function groups = getPropertyGroupsImpl(~)
            % Define section for properties in System block dialog box.
            i2cModule = matlab.system.display.internal.Property('I2CModule', 'Description', 'I2C module');
            i2cAddress = matlab.system.display.internal.Property('I2CAddress', 'Description', 'I2C address');
            bitRate=matlab.system.display.internal.Property('BitRate', 'Description', 'Bit rate','IsGraphical',false);
            rangingMode = matlab.system.display.internal.Property('RangingMode','Description', 'Ranging mode');
            i2cProperties = matlab.system.display.Section('PropertyList', {i2cModule,i2cAddress,bitRate,rangingMode});
            SampleTimeProp = matlab.system.display.internal.Property('SampleTime', 'Description', 'Sample time');
            sampleTimeSection = matlab.system.display.Section('PropertyList', {SampleTimeProp});
            MainGroup = matlab.system.display.SectionGroup(...
                'Title','Parameters',...
                'Sections', [i2cProperties,sampleTimeSection]);
            groups=MainGroup;
        end
    end

    methods(Access = protected, Static)
        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog
            simMode = 'Interpreted execution';
        end

        function flag = showSimulateUsingImpl
            % Return false if simulation mode hidden in System block dialog
            flag = false;
        end

    end
end