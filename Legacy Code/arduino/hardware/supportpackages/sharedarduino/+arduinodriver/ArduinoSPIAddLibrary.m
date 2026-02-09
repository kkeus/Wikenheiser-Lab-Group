classdef ArduinoSPIAddLibrary < coder.ExternalDependency
    % This file includes the external C/C++ files required to build SPI
    % library for Arduino
    
    % Copyright 2019-2024 The MathWorks, Inc.
    
    %#codegen
    
    methods (Access = public)
        function obj = ArduinoSPIAddLibrary()
            coder.allowpcode('plain');
        end
    end
    
    methods(Static)
        function name = getDescriptiveName(~)
            name = 'SPI WriteRead';
        end
        
        function tf = isSupportedContext(~)
            tf = true;
        end
        
        % Update the build-time buildInfo
        function updateBuildInfo(buildInfo, context)
            if buildInfo.ModelHandle == 0
                return;
            end
            if context.isCodeGenTarget('rtw')|| context.isCodeGenTarget('sfun')
                spkgRootDir = codertarget.arduinobase.internal.getBaseSpPkgRootDir;
                % Include Paths
                addIncludePaths(buildInfo, fullfile(spkgRootDir, 'include'));
                addIncludeFiles(buildInfo, 'MW_SPIwriteRead.h');
                % Source Files
                systemTargetFile = get_param(buildInfo.ModelName,'SystemTargetFile');
                if isequal(systemTargetFile,'ert.tlc')
                    % Add the following when not in rapid-accel simulation
                    addSourcePaths(buildInfo, fullfile(spkgRootDir, 'src'));
                    addSourceFiles(buildInfo, 'MW_SPIwriteRead.cpp', fullfile(spkgRootDir, 'src'), 'BlockModules');
                end
            end
        end
    end
end
