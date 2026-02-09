classdef ArduinoAnalogInput < matlabshared.ioclient.peripherals.AnalogInput ...
        & coder.ExternalDependency
    
    % This file is the device driver component for analog input for Arduino
    % hardware. It defines the internal APIs for IO and Codegen. device
    % driver classes for Simulink block and HWSDK should access this class.
    
    % It also includes external C/C++ files required to build arduino
    % analog library
    
    % Copyright 2019 The MathWorks, Inc.
    
    %#codegen
    methods
        function obj = ArduinoAnalogInput()
            coder.allowpcode('plain');
        end
    end
    
    methods(Access = public)
        % Overload the functions, which is not present on the target to
        % void
        function setTriggerSourceAnalogInInternal(~, varargin)
            % Do nothing
        end
        
        function enableNotificationAnalogInInternal(~, varargin)
            % Do nothing
        end
        
        function disableNotificationAnalogInInternal(~, varargin)
            % Do nothing
        end
        
        function status = getStatusAnalogInInternal(~, varargin)
            % Do nothing
            status = uint8(0);
        end
        
        function startAnalogInConversionInternal(~, varargin)
            % Do nothing
        end
        
        function stopAnalogInConversionInternal(~, varargin)
            % Do nothing
        end
    end
    
    methods (Static)
        function name = getDescriptiveName(~)
            name = 'Arduino Analog Input';
        end
        
        function b = isSupportedContext(context)
            b = context.isCodeGenTarget('rtw') || context.isCodeGenTarget('sfun');
        end
        
        function updateBuildInfo(buildInfo, context)
            if context.isCodeGenTarget('rtw') || context.isCodeGenTarget('sfun')
                svdDir = matlabshared.svd.internal.getRootDir();
                addIncludePaths(buildInfo,fullfile(svdDir,'include'));
                addIncludeFiles(buildInfo,'MW_AnalogIn.h');
                addSourcePaths(buildInfo, fullfile(codertarget.arduinobase.internal.getBaseSpPkgRootDir, 'src'));
                addSourceFiles(buildInfo,'MW_AnalogInput.cpp', fullfile(codertarget.arduinobase.internal.getBaseSpPkgRootDir, 'src'),'BlockModules');
                addSourceFiles(buildInfo,'ArduinoPinHandleMap.cpp', fullfile(codertarget.arduinobase.internal.getBaseSpPkgRootDir, 'src'),'BlockModules');
            end
        end
    end
end