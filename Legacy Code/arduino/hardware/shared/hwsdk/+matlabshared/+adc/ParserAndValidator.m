classdef ParserAndValidator <handle
    % helper class for parsing and validating input parameters of functions
    % which are part of matlashared.adc.controller

    % Copyright 2024 The MathWorks, Inc.
    methods(Static)
        function [params, enableRecording] = parseAndValidateReadVoltageParameters(varargin)
            params = [];
            enableRecording = false;
            % Define valid output formats
            validOutputFormats = {'matrix', 'timetable'};

            % Create an input parser
            p = inputParser;
            addParameter(p, 'OutputFormat', 'matrix',  @(x) matlabshared.adc.ParserAndValidator.validateOutputFormat(x, validOutputFormats));
            addParameter(p, 'SampleRate', 100,  @(x) matlabshared.adc.ParserAndValidator.validateSampleRate(x));
            addParameter(p, 'Duration', [], @(x) matlabshared.adc.ParserAndValidator.validateDuration(x));
            addParameter(p, 'NumSamples', [], @(x) matlabshared.adc.ParserAndValidator.validateNumSamples(x));

            % Parse the input arguments
            try
                parse(p, varargin{:});
            catch ME
                switch ME.identifier
                    % Customized error for unmatched parameter
                    case 'MATLAB:InputParser:UnmatchedParameter'
                        Message = ME.message;
                        index = strfind(Message, '''');
                        str = Message(index(1)+1:index(2)-1);
                        error(message('MATLAB:hwsdk:general:invalidNVPropertyName', str ,"readVoltage", matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', ')));
                    otherwise
                        throwAsCaller(ME)
                end
            end
            % Retrieve the parsed parameters
            params = p.Results;
            % Check if SampleRate is explicitly provided by the user
            sampleRateProvided = ~ismember('SampleRate', p.UsingDefaults);
            % Validate the parameters
            % Check if SampleRate is provided, and ensure either Duration or NumSamples is also provided
            if sampleRateProvided && isempty(params.Duration) && isempty(params.NumSamples)
                error(message('MATLAB:hwsdk:general:readVoltageMissingParameter'));
            end

            % Ensure Duration and NumSamples are not provided together
            if ~isempty(params.Duration) && ~isempty(params.NumSamples)
                error(message('MATLAB:hwsdk:general:mutuallyExclusiveParameters', 'NumSamples', 'Duration'));
            end

            % Calculate NumSamples if Duration is provided
            if ~isempty(params.Duration)
                params.NumSamples = floor(params.Duration * params.SampleRate);
            end
            % Determine the recording flag
            enableRecording = ~isempty(params.NumSamples) && params.NumSamples > 1;
        end
        % Output format should be  matrix or timetable
        function validateOutputFormat(x, validFormats)
            if(~ismember(lower(string(x)),validFormats))
                error(message('MATLAB:hwsdk:general:validValues',...
                    matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(validFormats, ', ')));
            end
        end
        % Sample Rate should be between 1 and 500 and double value like 5.5
        % is not allowed
        function validateSampleRate(x)
            if ~(isnumeric(x) && isscalar(x) && x >= 1 && x <= 500 && mod(x, 1) == 0)
                error(message('MATLAB:hwsdk:general:validScalarIntRange','1','500'));
            end
        end
        % NumSamples should be finite integer value
        function validateNumSamples(x)
            if ~(isnumeric(x) && isscalar(x) && x > 0 && isfinite(x) && mod(x, 1) == 0)
                error(message('MATLAB:hwsdk:general:InvalidIntegerFiniteValue'));
            end
        end
        % Duration should be finite double duration value
        function validateDuration(x)
            if ~(isnumeric(x) && isscalar(x) && x > 0 && isfinite(x))
                error(message('MATLAB:hwsdk:general:InvalidDoubleFiniteValue'));
            end
        end
    end


end
