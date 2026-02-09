classdef ESP32UpdateServerScreenHelper < matlab.hwmgr.internal.hwsetup.TemplateBase
%ESP32UPDATESERVERSCREENHELPER This is a helper class for
%UpdateServerScreen and UpdateServerScreenBLE files which has common functions
% for ESP32 realted workflows

% Copyright 2023 The MathWorks, Inc.

    properties(Access={?matlab.hwmgr.internal.hwsetup.TemplateBase,...
                       ?arduinoio.setup.internal.UpdateServerScreenBLE,...
                       ?arduinoio.setup.internal.UpdateServerScreen})
        %Install 3p selection
        Install3p = true
        %Install ESP32 Servo selection
        InstallServoESP323p = true
        % Install3pLibLabelText - Label that shows install 3p lib text
        Install3pLibLabelText
        % Install3pLibCheckBox - Check box for install 3p lib text
        Install3pLibCheckBox
        % Install3pLibLabelText - Label that shows install 3p lib text
        InstallServoESP323pLibLabelText
        % Install3pLibCheckBox - Check box for install 3p lib text
        InstallServoESP323pLibCheckBox
    end

    methods
        function obj = ESP32UpdateServerScreenHelper(workflow)
        % Call to class constructor
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow)
        end
    end

    methods(Access = protected)
        function update3pWidgets(obj)
        %This function updates the 3p widgets for ESP32 boards

            if ismember(obj.Workflow.Board, arduinoio.internal.ArduinoConstants.ESP32Boards)
                obj.Install3pLibCheckBox.Enable = 'on';
                obj.InstallServoESP323pLibCheckBox.Enable = 'on';

                % Check for ESP core package
                if ~exist(fullfile(arduinoio.CLIRoot,'data','packages','esp32'),'dir')
                    obj.Install3pLibCheckBox.Visible = 'on';
                    obj.Install3pLibLabelText.Visible = 'on';
                else
                    obj.Install3pLibCheckBox.Visible = 'off'; % library exists
                    obj.Install3pLibLabelText.Visible = 'off';
                end

                % Check for ServoESP32 library
                if ~exist(fullfile(arduinoio.CLIRoot,"user","libraries","ServoESP32"),'dir')
                    obj.InstallServoESP323pLibCheckBox.Visible = 'on';
                    obj.InstallServoESP323pLibLabelText.Visible = 'on';
                else
                    obj.InstallServoESP323pLibCheckBox.Visible = 'off'; % library exists
                    obj.InstallServoESP323pLibLabelText.Visible = 'off';
                end

            else
                obj.Install3pLibCheckBox.Visible = 'off';
                obj.Install3pLibLabelText.Visible = 'off';
                obj.InstallServoESP323pLibCheckBox.Visible = 'off';
                obj.InstallServoESP323pLibLabelText.Visible = 'off';
            end
        end

        function status = complete3pInstall(obj)
        % This functions will check if any 3p download is required

            status = 0;
            % Check for ESP32 core installation
            if ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.ESP32Boards) && (~exist(fullfile(arduinoio.CLIRoot,'data','packages','esp32'),'dir'))
                if obj.Install3p
                    obj.ProgramProgress.Visible = 'on';
                    obj.ErrorLabelText.FontColor =  matlab.hwmgr.internal.hwsetup.util.Color.ColorPrimary;
                    obj.ProgramProgress.Indeterminate = true;
                    obj.ErrorLabelText.Text =  getString(message('MATLAB:arduinoio:general:Installing3pLibrary'));
                    drawnow;
                    [status,~] = complete3pInstall(obj.Workflow.HWInterface,obj.Workflow);
                else
                    id = 'MATLAB:arduinoio:general:thirdPartyLibraryRequired';
                    integrateErrorKey(obj.Workflow, id);
                    error(id, message(id,'ESP32').getString);
                end
            end
            % Check for ESP32 Servo installation
            if ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.ESP32Boards) && (~exist(fullfile(arduinoio.CLIRoot,"user","libraries","ServoESP32"),'dir'))
                if obj.InstallServoESP323p
                    obj.ProgramProgress.Visible = 'on';
                    obj.ErrorLabelText.FontColor =  matlab.hwmgr.internal.hwsetup.util.Color.ColorPrimary;
                    obj.ProgramProgress.Indeterminate = true;
                    obj.ErrorLabelText.Text =  getString(message('MATLAB:arduinoio:general:Installing3pLibrary'));
                    drawnow;
                    [status] = completeServoESP323pInstall(obj.Workflow.HWInterface,obj.Workflow);
                else
                    id = 'MATLAB:arduinoio:general:thirdPartyLibraryRequired';
                    integrateErrorKey(obj.Workflow, id);
                    error(id, message(id,'ESP32 Servo').getString);
                end
            end
        end

        function Install3pLibrary(obj, src, ~)
            obj.Install3p = src.Value;
        end

        function InstallServoESP323pLibrary(obj,src,~)
            obj.InstallServoESP323p = src.Value;
        end
    end
end
