classdef arduinoPWMAddLibrary < coder.ExternalDependency
    
    % This file includes the external C/C++ files required to build PWM
    % library for Arduino
    
    % Copyright 2020 The MathWorks, Inc.
    
    %#codegen
    
    methods (Access = public)
        function obj = arduinoPWMAddLibrary()
            coder.allowpcode('plain');
        end
    end
    
    methods (Static)
        function name = getDescriptiveName(~)
            name = 'Arduino PWM';
        end
        
        function b = isSupportedContext(context)
            b = context.isCodeGenTarget('rtw') || context.isCodeGenTarget('sfun');
        end
        
        function updateBuildInfo(buildInfo, context)
            if context.isCodeGenTarget('rtw') || context.isCodeGenTarget('sfun')
                % Digital I/O interface
                svdDir = matlabshared.svd.internal.getRootDir;
                spkgRootDir = codertarget.arduinobase.internal.getBaseSpPkgRootDir;
                addIncludePaths(buildInfo,fullfile(svdDir,'include'));
                addIncludeFiles(buildInfo,'MW_PWM.h');
                addIncludePaths(buildInfo,fullfile(spkgRootDir,'include'));
                addIncludeFiles(buildInfo,'MW_PWMDriver.h');
                addSourcePaths(buildInfo, fullfile(spkgRootDir, 'src'));
                addSourceFiles(buildInfo,'MW_PWM.cpp', fullfile(spkgRootDir, 'src'),'BlockModules');
                addSourceFiles(buildInfo,'MW_PWMDriver.c', fullfile(spkgRootDir, 'src'),'BlockModules');
                addSourceFiles(buildInfo,'ArduinoPinHandleMap.cpp', fullfile(spkgRootDir, 'src'),'BlockModules');
            end
        end
    end
end