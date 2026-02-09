classdef ArduinoDigitalIO < matlabshared.ioclient.peripherals.DigitalIO & ...
        coder.ExternalDependency
    
    % This file provides internal APIs for IO operation and geretaes code
    % for the same.
    
    % Ideally coder.ExternalDependency should be inherited in
    % matlabshared.devicedrivers.coder.DigitalIO. But that is leading to an
    % error in BaT session during code generation. The reason is not clear.
    % To avoid that, right now the current class is inheriting from
    % coder.ExternalDependency.
    
    % Copyright 2019 The MathWorks, Inc.
    
    %#codegen
    methods(Access = public)
        function obj = ArduinoDigitalIO()
            coder.allowpcode('plain');
        end
    end
    
    methods(Hidden)
        function varargout = configureDigitalPinInternal(obj, varargin)
            if ~coder.target('MATLAB')
                % This is executed during MATLAB and Simulink code generation
                pin = varargin{1};
                mode = varargin{2};
                coder.cinclude('MW_arduino_digitalio.h');
                coder.ceval('digitalIOSetup',uint8(pin), mode);
                
            else
                % This is executed during MATLAB and Simulink IO
                writeStatus = configureDigitalPinInternal@matlabshared.ioclient.peripherals.DigitalIO(obj, varargin{:});
                if(nargout == 1)
                    varargout{1} = writeStatus;
                end
            end
        end
        
        function varargout =  writeDigitalPinInternal(obj, varargin)
            if ~coder.target('MATLAB')
                % This is executed during MATLAB and Simulink code generation
                pin = varargin{1};
                value = varargin{2};
                % Temp fix for bp g3413449. Ideally configurePin needs to
                % be called before calling write/readDigital
                 coder.cinclude('MW_arduino_digitalio.h');
                coder.ceval('writeDigitalPin',uint8(pin),uint8(value));
            else
                % This is executed during MATLAB and Simulink IO
                writeStatus = writeDigitalPinInternal@matlabshared.ioclient.peripherals.DigitalIO(obj, varargin{:});
                if(nargout == 1)
                    varargout{1} = writeStatus;
                end
            end
        end
        
        function [readValue, readStatus,timestamp] = readDigitalPinInternal(obj, varargin)
            timestamp = 0;
            readStatus = 0;
            if ~coder.target('MATLAB')
                % This is executed during MATLAB and Simulink code generation
                pin = varargin{1};
                readValue = coder.nullcopy(false);
                 % Temp fix for bp g3413449. Ideally configurePin needs to
                % be called before calling write/readDigital
				coder.cinclude('MW_arduino_digitalio.h');
                readValue = coder.ceval('readDigitalPin',uint8(pin));
            else
                % This is executed during MATLAB and Simulink IO
                [readValue, readStatus,timestamp] = readDigitalPinInternal@matlabshared.ioclient.peripherals.DigitalIO(obj, varargin{:});
            end
        end
        
        function varargout = unconfigureDigitalPinInternal(obj, varargin)
            if ~coder.target('MATLAB')
                % This is executed during MATLAB and Simulink code generation
                % Do nothing
            else
                % This is executed during MATLAB and Simulink IO
                writeStatus = unconfigureDigitalPinInternal@matlabshared.ioclient.peripherals.DigitalIO(obj, varargin{:});
                if(nargout == 1)
                    varargout{1} = writeStatus;
                end
            end
        end
    end
    
    methods (Static)
        function name = getDescriptiveName(~)
            name = 'DigitalIO';
        end
        
        function b = isSupportedContext(context)
            b = context.isCodeGenTarget('rtw') || context.isCodeGenTarget('sfun');
        end
        
        function updateBuildInfo(buildInfo, context)
            if context.isCodeGenTarget('rtw') || context.isCodeGenTarget('sfun')
                spkgRootDir = codertarget.arduinobase.internal.getBaseSpPkgRootDir;
                % Include Paths
                addIncludePaths(buildInfo, fullfile(spkgRootDir, 'include'));
                addIncludeFiles(buildInfo, 'MW_arduino_digitalio.h');
                if(buildInfo.ModelHandle)
                    % Source Files
                    systemTargetFile = get_param(buildInfo.ModelName,'SystemTargetFile');
                    if isequal(systemTargetFile,'ert.tlc')
                        % Add the following when not in rapid-accel simulation
                        addSourcePaths(buildInfo, fullfile(spkgRootDir, 'src'));
                        addSourceFiles(buildInfo, 'MW_arduino_digitalio.cpp', fullfile(spkgRootDir, 'src'), 'BlockModules');
                    end
                else
                    % In MATLAB targeting there is no Model and hence
                    % buildInfo.ModelHandle is 0
                    addSourcePaths(buildInfo, fullfile(spkgRootDir, 'src'));
                    addSourceFiles(buildInfo, 'MW_arduino_digitalio.cpp', fullfile(spkgRootDir, 'src'), 'BlockModules');
                end
            end
        end
    end
end