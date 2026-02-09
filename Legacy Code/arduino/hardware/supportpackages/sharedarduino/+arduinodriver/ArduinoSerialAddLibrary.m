classdef ArduinoSerialAddLibrary < coder.ExternalDependency
    
    % This file includes the external C/C++ library for build.
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    %#codegen
    
    methods
        function obj = ArduinoSerialAddLibrary()
            coder.allowpcode('plain');
        end
    end
    methods(Static)
        function name = getDescriptiveName(~)
            name = 'Arduino Serial';
        end
        
        function b = isSupportedContext(context)
            b = context.isCodeGenTarget('rtw')||context.isCodeGenTarget('sfun');
        end
        
        function updateBuildInfo(buildInfo, context)
            % Update the build-time buildInfo
            if context.isCodeGenTarget('rtw')
                spkgRootDir = codertarget.arduinobase.internal.getBaseSpPkgRootDir;
                % Include Paths
                addIncludePaths(buildInfo, fullfile(spkgRootDir, 'include'));
                addIncludeFiles(buildInfo, 'MW_SerialRead.h');
                addIncludeFiles(buildInfo, 'MW_SerialWrite.h');
                % Source Files
                systemTargetFile = get_param(buildInfo.ModelName,'SystemTargetFile');
                if isequal(systemTargetFile,'ert.tlc')
                    % Add the following when not in rapid-accel simulation
                    addSourcePaths(buildInfo, fullfile(spkgRootDir, 'src'));
                    addSourceFiles(buildInfo, 'MW_SerialRead.cpp', fullfile(spkgRootDir, 'src'), 'BlockModules');
                    addSourceFiles(buildInfo, 'MW_SerialWrite.cpp', fullfile(spkgRootDir, 'src'), 'BlockModules');
                end
            end
        end
    end
end