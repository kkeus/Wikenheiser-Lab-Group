classdef PlatformUtility < arduinoio.internal.Utility
    %   Utility class used on all OS platforms

    %   Copyright 2014-2023 The MathWorks, Inc.

    methods(Access = {?arduinoio.internal.UtilityCreator, ?arduino.accessor.UnitTest})
        % Private constructor with limited access to only utility factory class
        % and test class
        function obj = PlatformUtility
        end
    end

    methods(Access = public)
        function buildInfo = setProgrammer(~, buildInfo)
            buildInfo.Programmer = fullfile(buildInfo.CLIPath, 'arduino-cli');
            if isunix && ~ismac
                buildInfo.TempDirPath = fullfile(tempdir,getenv('USER'), strcat('ArduinoServer',buildInfo.Board));
            else
                buildInfo.TempDirPath = fullfile(tempdir,strcat('ArduinoServer',buildInfo.Board));
            end
            buildInfo.ConfigurationFile = fullfile(buildInfo.CLIPath, 'arduino-cli.yaml');            
        end
    end
end
