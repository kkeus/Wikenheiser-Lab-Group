classdef VL53L0XBlock <    coder.ExternalDependency & matlabshared.sensors.simulink.VL53L0XBlockMask
    % VL53L0X Time of Flight sensor
    % This sensor includes API's provided by ST Microelectronics.
    % VL53L0X block outputs distance of obstacle from microcontroller in mm.

    %   Copyright 2021-2024 The MathWorks, Inc.

    %#codegen

    methods (Static)
        function name = getDescriptiveName(~)
            name = 'VL53L0X Sensor';
        end

        function b = isSupportedContext(context)
            b = context.isCodeGenTarget('rtw');
        end

        function updateBuildInfo(buildInfo, context)
            coder.extrinsic('matlabshared.sensors.simulink.internal.getTargetHardwareName');
            targetname = coder.const(matlabshared.sensors.simulink.internal.getTargetHardwareName);
            % Get the filelocation of the SPKG specific files
            coder.extrinsic('matlabshared.sensors.simulink.internal.getTargetSpecificFileLocationForSensors');
            fileLocation = coder.const(@matlabshared.sensors.simulink.internal.getTargetSpecificFileLocationForSensors,targetname);
            coder.extrinsic('which');
            coder.extrinsic('error');
            coder.extrinsic('message')
            % target author will have to specify the file location in
            % function "'filelocation'.getTargetSensorUtilities"
            funcName = [fileLocation,'.getTargetSensorUtilities'];
            functionPath = coder.const(@which,funcName);
            % Only if the the path exist
            if ~isempty(fileLocation)
                % internal error to see if the target author has provided
                % the expected function in the specified file location
                assert(~isempty(functionPath),message('matlab_sensors:general:FunctionNotAvailableSimulinkSensors','getTargetSensorUtilities'));
                funcHandle = str2func(funcName);
                hwUtilityObject = funcHandle('I2C');
                assert(isa(hwUtilityObject,'matlabshared.sensors.simulink.internal.SensorSimulinkBase'),message('matlab_sensors:general:invalidHwObjSensorSimulink'));
                hwUtilityObject.updateBuildInfo(buildInfo, context);
            else
                hwUtilityObject = '';
            end
            spkgrootDir = matlabshared.sensors.internal.getSensorThirdPartyRootDir;
            buildInfo.addIncludePaths(fullfile(spkgrootDir,'vl53l0x','platform','inc'));
            buildInfo.addIncludePaths(fullfile(spkgrootDir,'vl53l0x','core','inc'));
            buildInfo.addIncludePaths(fullfile(spkgrootDir,'vl53l0x'));
            addSourceFiles(buildInfo,'vl53l0x_platform.cpp',fullfile(spkgrootDir,'vl53l0x','platform','src'));
            addSourceFiles(buildInfo,'vl53l0x_i2c_platform.cpp',fullfile(spkgrootDir,'vl53l0x','platform','src'));
            addSourceFiles(buildInfo,'vl53l0x_api_strings.cpp',fullfile(spkgrootDir,'vl53l0x','core','src'));
            addSourceFiles(buildInfo,'vl53l0x_api_ranging.cpp',fullfile(spkgrootDir,'vl53l0x','core','src'));
            addSourceFiles(buildInfo,'vl53l0x_api_calibration.cpp',fullfile(spkgrootDir,'vl53l0x','core','src'));
            addSourceFiles(buildInfo,'vl53l0x_api.cpp',fullfile(spkgrootDir,'vl53l0x','core','src'));
            addSourceFiles(buildInfo,'vl53l0x_api_core.cpp',fullfile(spkgrootDir,'vl53l0x','core','src'));
            addSourceFiles(buildInfo,'vl53l0x_main.cpp',fullfile(spkgrootDir,'vl53l0x'));
        end
    end


end