classdef SetupCompleteScreen < arduinoio.setup.internal.LaunchArduinoExamples
    %SETUPCOMPLETESCREEN This is an Arduino specific implementation of a
    %Launch Examples screen. This screen will be displayed at the end of
    %the Arduino Setup to give the installer an option to open the examples
    %page for Arduino

    % Copyright 2016-2024 The MathWorks, Inc.

    methods
        function obj = SetupCompleteScreen(workflow)
            obj@arduinoio.setup.internal.LaunchArduinoExamples(workflow, ...
                matlab.hwmgr.internal.hwsetup.TemplateLayout.GRID);
            obj.customizeScreen();

            % Save the device preference for use by the explorer app if the
            % hardware setup was launched from outside the app.
            % Test connection status is true by default and we save prefs
            % if the user skips test connection or test connection is successful.
            % Don't bother saving preference if test connection failed.
            if ~obj.Workflow.LaunchByArduinoExplorer && ...
                    obj.Workflow.TestConnectionResult
                saveBoardConnectionInfo(obj);
            end
        end

        function id = getPreviousScreenID(obj)
            if isa(obj.Workflow, 'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow') && obj.Workflow.SkipSetup
                id = 'arduinoio.setup.internal.DriverInstallResultScreen';
            else
                id = 'arduinoio.setup.internal.TestConnectionScreen';
            end
        end

        function customizeScreen(obj)
            % Use HTMLText instead of Label to get HTML format
            % interpretation
            obj.Description.Text = message('MATLAB:arduinoio:general:ArduinoCompleteDescription').getString;

            %If the LaunchCheckbox is empty then there are no examples to
            %display. Set the ShowExamples property as is appropriate.
            if ~isempty(obj.LaunchCheckbox)
                obj.LaunchCheckbox.ValueChangedFcn = @obj.checkboxCallback;
                obj.LaunchCheckbox.Value=obj.Workflow.ShowExamples; 
            else
                obj.Workflow.ShowExamples = false;
            end

            % Show "Launch Arduino Explorer" app if launched from outside the app
            if ~isempty(obj.LaunchArduinoExplorerCheckBox)
                % Create checkBox for launching Arduino Explorer app
                obj.LaunchArduinoExplorerCheckBox.ValueChangedFcn = @obj.launchAppCheckboxCallback;
                obj.LaunchArduinoExplorerCheckBox.Value = obj.Workflow.LaunchExplorerApp;
            end

        end
    end

    methods(Access = 'private')
        function checkboxCallback(obj, src, ~)
            obj.Workflow.ShowExamples = src.Value;
        end

        function launchAppCheckboxCallback(obj,src,~)
            obj.Workflow.LaunchExplorerApp = src.Value;
        end

        function saveBoardConnectionInfo(obj)
            % Function to save board connection preference so that the Arduino
            % Explorer app can enumerate these devices
            connectionType = obj.Workflow.ConnectionType;
            switch (connectionType)
                % Save Bluetooth connection preference
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                    obj.Workflow.HWInterface.saveBluetoothPrefs(obj.Workflow.Board,obj.Workflow.DeviceAddress);
                    % Save BLE connection preference
                    % Save BLE preference only on Windows. mac assigns a random BLE address
                    % every time it connects to the hardware.
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                    if ispc
                        obj.Workflow.HWInterface.saveBLEPrefs(obj.Workflow.Board,...
                            obj.Workflow.DeviceAddress,obj.Workflow.DeviceName);
                    end
                    % Save WiFi connection settings
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                    obj.Workflow.HWInterface.saveWiFiPrefs(obj.Workflow.UseStaticIP,obj.Workflow.Board,...
                        obj.Workflow.DeviceAddress,obj.Workflow.TCPIPPort);
            end
        end
    end

end

% LocalWords:  arduinoio
