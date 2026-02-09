classdef CommonFunctionsFor3pRecipe <handle
%         & coder.ExternalDependency ...
     % Copyright 2022 The MathWorks, Inc.
    %#codegen
    %#ok<*EMCA>
    methods (Static)
        function  updateBuildInfo(buildInfo, context)
            % Update buildInfo
            coder.extrinsic('matlabshared.sensors.simulink.internal.getTargetHardwareName');
            targetname = coder.const(matlabshared.sensors.simulink.internal.getTargetHardwareName);
            % Get the filelocation of the SPKG specific files
            coder.extrinsic('matlabshared.sensors.simulink.internal.getTargetSpecificFileLocationForSensors');
            fileLocation = coder.const(@matlabshared.sensors.simulink.internal.getTargetSpecificFileLocationForSensors,targetname);
            coder.extrinsic('which');
            coder.extrinsic('error');
            coder.extrinsic('message');
            funcName = [fileLocation,'.getTargetSensorUtilities'];
            functionPath = coder.const(@which,funcName);
            % Only if the the path exist
            if ~isempty(fileLocation)
                assert(~isempty(functionPath),message('matlab_sensors:general:FunctionNotAvailableSimulinkSensors','getTargetSensorUtilities'));
                funcHandle = str2func(funcName);
                hwUtilityObject = funcHandle('I2C');
                assert(isa(hwUtilityObject,'matlabshared.sensors.simulink.internal.SensorSimulinkBase'),message('matlab_sensors:general:invalidHwObjSensorSimulink'));
                hwUtilityObject.updateBuildInfo(buildInfo, context);
                sensorFolderrootDir = matlabshared.sensors.internal.getSensorThirdPartyRootDir;
                if contains(fileLocation,'Arduino','IgnoreCase',true)
                else
                    addSourceFiles(buildInfo,'Arduino.cpp',fullfile(sensorFolderrootDir,'3psensors','src'));
                    addSourceFiles(buildInfo,'Wire.cpp',fullfile(sensorFolderrootDir,'3psensors','src'));
                end
            end   
        end
    end
end