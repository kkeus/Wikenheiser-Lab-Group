classdef ArduinoI2CAddLibrary < coder.ExternalDependency
    % This file includes the external C/C++ files required to build I2C
    % library for Arduino
    % Copyright 2019 The MathWorks, Inc.
    
    %#codegen
    
    methods(Access = public)
        function obj = ArduinoI2CAddLibrary()
            coder.allowpcode('plain');
        end
    end
    
    methods (Static)
        function name = getDescriptiveName(~)
            name = 'Arduino I2C';
        end
        
        function b = isSupportedContext(context)
            b = context.isCodeGenTarget('rtw') || context.isCodeGenTarget('sfun');
        end
        
        function updateBuildInfo(buildInfo, context)
            if context.isCodeGenTarget('rtw') || context.isCodeGenTarget('sfun')
                % I2C interface
                spkgrootDir = codertarget.arduinobase.internal.getBaseSpPkgRootDir;
                svdDir = matlabshared.svd.internal.getRootDir;
                %Include Files
                addIncludePaths(buildInfo,fullfile(svdDir,'include'));
                addIncludeFiles(buildInfo,'MW_I2C.h');
                % Source Files
                addSourcePaths(buildInfo, fullfile(spkgrootDir,'src'));
                addSourceFiles(buildInfo,'MW_arduinoI2C.cpp', fullfile(spkgrootDir,'src'),'BlockModules');
                setenv('Arduino_ML_Codegen_I2C', 'Y');
            end
        end
    end
end