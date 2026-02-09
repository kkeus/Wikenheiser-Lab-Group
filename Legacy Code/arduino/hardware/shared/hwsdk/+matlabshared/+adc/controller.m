classdef controller < matlabshared.adc.controller_base
                     
                      
% HWSDK Analog IO Controller
%
% All the methods and hooks to interface HWSDK to IOSERVER are implemented here
%
% Available methods Syntax:
%   data = readVoltage(obj, pin); % Reads a Analog Pin
% Input Arguments:
%   obj = Object belonging to target class which inherits from adc.controller
%   pin = pin to perform read operation on (Eg: 'D13')

%   Copyright 2017-2024 The MathWorks, Inc.
    properties(GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableAnalogPins string
    end
    

    properties(Access = ?matlabshared.hwsdk.internal.base)
        % This property holds the analog driver object that provides
        % internal APIs for IO and code generation
        AnalogDriverObj = matlabshared.ioclient.peripherals.AnalogInput();
    end

    methods
        % HWSDK displays a string array. Some hardware might require a
        % different type of display. Since a Getter cannot be
        % inherited, a trip is provided here which the individual hardware
        % can make use of.
        function availableAnalogPins = get.AvailableAnalogPins(obj)
            availableAnalogPins =  getAvailableAnalogPinsForPropertyDisplayHook(obj, obj.AvailableAnalogPins);
        end
    end

    methods(Access = protected)
        % Hardware inherits this method to modify the property display
        function availableDigitalPins = getAvailableAnalogPinsForPropertyDisplayHook(~, pins)
            availableDigitalPins = pins;
        end
    end

    methods (Access = private, Static = true)
        function name = matlabCodegenRedirect(~)
        % Codegen redirector class. During codegen this class will be
        % replaced by matlabshared.coder.controller.controller by MATLAB
            name = 'matlabshared.coder.adc.controller';
        end
    end

    methods(Access = public, Hidden)
        function obj = controller(varargin)
        end
    end

    methods(Sealed, Access = public)
        function [data, triggerTime] = readVoltage(obj, pin,varargin)
            % Register on clean up for integrating all data.
            if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                c = onCleanup(@() integrateData(obj,varargin{:}));
            end
             try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                if nargin>8
                    obj.localizedError('MATLAB:maxrhs');
                end
                pin = validateAnalogInputVoltagePin(obj, pin);
                configureControllerPin(obj, pin, "readVoltage");
                % hook to get the pin Number according to the hardware
                pinNumber = getADCPinNumberHook(obj, pin);
                resultDatatype = getDatatypeFromResolutionHook(obj);
                % Initialize recording parameters
                enableRecording = false;
                params  = [];
                if(nargin>2)
                    % To throw error in case where the hardware do not
                    % support Foreground acquisition  capability and Name Value
                    % parameters are given in readVoltage
                    if(~isa(obj,"matlabshared.hwsdk.ForegroundAcquisitionUtility"))
                        obj.localizedError('MATLAB:maxrhs');
                    end
                    % Function to validate and parse Name Value parameters
                    % of readVoltage
                    [params, enableRecording] = matlabshared.adc.ParserAndValidator.parseAndValidateReadVoltageParameters(varargin{:});
                end
                % Register cleanup if  recording is enabled to check
                % whether the streaming is stopped or not after the end of
                % operation
                if (enableRecording) 
                    c2 = onCleanup(@() cleanUpRecording(obj,obj.Protocol));
                end
                % reading raw bytes
                [counts,timestamps,triggerTime] = readRawVoltage(obj,pinNumber,resultDatatype,enableRecording,params);
                data = sampleToVoltageConverterHook(obj,counts,resultDatatype);
                % Format output if parameters are provided
                if nargin > 2 && strcmpi(params.OutputFormat, 'timetable')
                    data = createTimetable(obj, data, timestamps);
                end
            catch e
                obj.throwCustomErrorHook(e);
            end
        end
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})
        function availableAnalogPins = getAvailableAnalogInputVoltagePins(obj)
            availableAnalogPins = getAvailableAnalogInputVoltagePinsImpl(obj);
            assert(size(availableAnalogPins, 1)==1 && ...    % row based
                   isstring(availableAnalogPins), ...
                   'ASSERT: getAvailableAnalogInputVoltagePinsImpl must return a row based array of strings');
        end

        function pin = validateAnalogInputVoltagePin(obj, pin)
            pin = validateControllerPin(obj.PinValidator, pin, obj.getAvailableAnalogInputVoltagePins(), obj.getBoardNameHook());
            aliasPin = getPinAliasHook(obj, pin);
            if ~isempty(aliasPin)
                pin = aliasPin;
            end
        end
    end
 

    methods(Access = protected)
        function pinNumber = getADCPinNumberHook(obj, pin)
            pinNumber = obj.getPinNumber(pin);
        end
        function voltage = sampleToVoltageConverterHook(obj,counts,resultDatatype)
            maxCount = power(2, getADCResolutionInBitsHook(obj)) - 1;
            normalizedVoltage = double(typecast(uint8(counts), char(resultDatatype))) / maxCount;
            voltage = normalizedVoltage * getReferenceVoltageImpl(obj);
        end
        function recordingPreCheckHook(~)
            return;
        end
        function voltageTimetable = createTimetable(~,voltage, timestamps)
            % Convert timestamps to duration relative to the start time
            timeDurations = seconds(round(timestamps - timestamps(1),6));
            % Create a timetable with voltage and time
            voltageTimetable = timetable(timeDurations', voltage, 'VariableNames', {'Voltage'});
        end
        function [counts,timestamps,triggerTime] = readRawVoltage(obj,pinNumber,resultDatatype,enableRecording,params)
            % Initialize outputs
            timestamps = 0; 
            triggerTime = [];
            counts = [];
            if enableRecording
                % Check whether hardware is ready for foreground
                % acquisition
                recordingPreCheckHook(obj);
                % do all the configuration before registering the request
                % ID to hardware
                preRegistrationConfig(obj,obj.Protocol);
            end
            try
                % Capture the trigger time when the request is sent to
                % hardware for the voltage acquisition
                triggerTime = datetime('now');
                % Define function handle for voltage acquisition
                voltageAcquisitionHandle = @() readResultAnalogInSingleInternal(obj.AnalogDriverObj, obj.Protocol, pinNumber, resultDatatype);
                % Call the function using the handle to get the data in
                % case of On-demand and register the request ID in case of
                % recording
                counts = voltageAcquisitionHandle();
            catch ME
                % Stop configuration of streaming  if the request is sent to the harware
                % for streaming
                if enableRecording
                    stopConfigureStreaming(obj.Protocol);
                end
                throwAsCaller(ME);
            end
            if enableRecording
                % do all the configuration after registering the request
                % ID to hardware
                postRegistrationConfig(obj,obj.Protocol, params.SampleRate, params.NumSamples);
                % trigger time is recorded before the streaming is started
                triggerTime = datetime('now');
                [counts, timestamps] = record(obj,obj.Protocol,voltageAcquisitionHandle);
            end
        end
        
        function resolution = getADCResolutionInBitsHook(~)
            resolution = 10;
        end

        function resultDatatype = getDatatypeFromResolutionHook(obj)
           resolution = getADCResolutionInBitsHook(obj);
            if 8 >= resolution
                resultDatatype = "uint8";
            elseif 16 >= resolution
                resultDatatype = "uint16";
            elseif 32 >= resolution
                resultDatatype = "uint32";
            elseif 64 >= resolution
                resultDatatype = "uint64";
            end
        end
       
    end
end

% LocalWords:  MMM HH
