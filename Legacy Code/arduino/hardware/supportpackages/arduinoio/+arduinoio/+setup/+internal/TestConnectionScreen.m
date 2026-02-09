classdef TestConnectionScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %TESTCONNECTIONSCREEN The TestConnectionScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The TestConnectionScreen is used to allow users to review the Arduino
    % settings and also test the connection before using it at command
    % line.
    
    % Copyright 2016-2022 The MathWorks, Inc.

    properties(Access = public)
        % Label that shows text for settings table
        SettingsText
        % Label that contains the main content text
        ContentText
        % Button to allow a user to test connection
        TestConnButton
        % Progress bar shows testing status
        TestConnProgress
        % Label that shows result text after testing connection
        ResetLabelText
        % Table that shows a summary of connection info
        DeviceInfoTable        
        % StatusTable - Steps, Status and additional information per step
        % for each activity performed when testing the connection to the
        % device (StatusTable)
        StatusTable
    end

    properties(Access = private, Constant = true)
        FontSize = 13
    end
    
    methods(Access = 'public')
        function obj = TestConnectionScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            % Using grid based approach for positioning the widgets. See g2753532 for more info.
            % https://confluence.mathworks.com/display/HSM/Grid+Layout+Transition+Recipe
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow, matlab.hwmgr.internal.hwsetup.TemplateLayout.GRID);
            obj.Title.Text = message('MATLAB:arduinoio:general:TestConnectionScreenTitle').getString;
            obj.HelpText.AboutSelection = '';
            obj.HelpText.WhatToConsider = '';
            % 'fit' and '1x' are the default values for Row height and Column width. 
            obj.ContentGrid.RowHeight = {'fit', 100,22,'fit'}; %100,22 are the custom height for second and third rows
            obj.ContentGrid.ColumnWidth = {120, '1x'}; %120 is the custom column width for first column
            
            % Set the DeviceInfoTable
            obj.SettingsText = matlab.hwmgr.internal.hwsetup.Label.getInstance(obj.ContentGrid);
            obj.SettingsText.Row =1;
            obj.SettingsText.Column = [1,2];
            obj.SettingsText.Text = 'Current Settings:';
            obj.DeviceInfoTable = matlab.hwmgr.internal.hwsetup.DeviceInfoTable.getInstance(obj.ContentGrid);
            obj.DeviceInfoTable.Row =2;
            obj.DeviceInfoTable.Column = [1 2];

            % Set the Test Connection Button
            obj.TestConnButton = matlab.hwmgr.internal.hwsetup.Button.getInstance(obj.ContentGrid);
            obj.TestConnButton.ButtonPushedFcn = @obj.buttonCallback;
            obj.TestConnButton.Row =3;
            obj.TestConnButton.Column = 1;
            obj.TestConnButton.Text = message('MATLAB:arduinoio:general:testButtonText').getString;
            obj.TestConnButton.Color = matlab.hwmgr.internal.hwsetup.util.Color.MWBLUE; 
            obj.TestConnButton.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorTertiary;

            obj.TestConnProgress = matlab.hwmgr.internal.hwsetup.ProgressBar.getInstance(obj.ContentGrid);
            obj.TestConnProgress.Row =3;
            obj.TestConnProgress.Column = 2;

            % Set the StatusTable
            obj.StatusTable = matlab.hwmgr.internal.hwsetup.StatusTable.getInstance(obj.ContentGrid);
            obj.StatusTable.Status = {''};
            obj.StatusTable.Steps = {''};
            obj.StatusTable.Row =4;
            obj.StatusTable.Column = [1 2];
            obj.StatusTable.Visible = 'off';
            updateDeviceInfoTable(obj);
            if strcmpi(obj.Workflow.DeviceAddress,message('MATLAB:arduinoio:general:ErrorObtainingDeviceAddress').getString) || strcmpi(obj.Workflow.DeviceAddress,message('MATLAB:arduinoio:general:BTRadioNotAvailableText').getString)
                displayAddressNotObtainedMsg(obj);
            end
        end

        function id = getPreviousScreenID(obj)
            if obj.Workflow.SkipProgram
                id = 'arduinoio.setup.internal.ObtainIPScreen';
            else
                switch obj.Workflow.ConnectionType
                    case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                        id = 'arduinoio.setup.internal.UpdateServerScreen';
                    case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                        id = 'arduinoio.setup.internal.PairBTScreen';
                    case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                        id = 'arduinoio.setup.internal.UpdateServerScreen';
                    case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                        id = 'arduinoio.setup.internal.UpdateServerScreenBLE';
                end
            end
        end
        
        function  id = getNextScreenID(obj)
            if obj.Workflow.isUsingRemoteHW()
                id = obj.Workflow.getOnlineSetupCompleteScreen();
            else
                id = 'arduinoio.setup.internal.SetupCompleteScreen';
            end
            c = onCleanup(@() integrateData(obj.Workflow, obj.Workflow.Board, obj.Workflow.ConnectionType, obj.StatusTable.Status));
        end
        
        function reinit(obj)
            updateDeviceInfoTable(obj);
            % upon reentry, reset result text and what to
            % consider text
            obj.StatusTable.Visible = 'off';
            obj.StatusTable.Status = {''};
            obj.StatusTable.Steps = {''};
            obj.HelpText.WhatToConsider = '';
            % switch TestConnButton to 'on' in case it was off earlier due to
            % error obtaining device address on Mac
            if ismac
                obj.TestConnButton.Enable = 'on';
            end
            if strcmpi(obj.Workflow.DeviceAddress,message('MATLAB:arduinoio:general:ErrorObtainingDeviceAddress').getString) || strcmpi(obj.Workflow.DeviceAddress,message('MATLAB:arduinoio:general:BTRadioNotAvailableText').getString)
                displayAddressNotObtainedMsg(obj);
            end
        end
        
        function show(obj)
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj);
            obj.TestConnProgress.Visible = 'off';
        end
    end

    methods(Access = 'private')
        function updateDeviceInfoTable(obj)
            %Function that renders the current settings table
            [properties, value] = getDeviceProperties(obj.Workflow.HWInterface, obj.Workflow);
            obj.DeviceInfoTable.Labels = properties;
            obj.DeviceInfoTable.Values = value;
            obj.DeviceInfoTable.ColumnWidth = 230;
        end
        
        function displayAddressNotObtainedMsg(obj)
            obj.TestConnButton.Enable = 'off';
            obj.StatusTable.Visible = 'on';
            if strcmpi(obj.Workflow.DeviceAddress,message('MATLAB:arduinoio:general:ErrorObtainingDeviceAddress').getString) 
                obj.StatusTable.Steps = {message('MATLAB:arduinoio:general:ConflictingBLEDeviceName').getString};
            else % (strcmpi(obj.Workflow.DeviceAddress,message('MATLAB:arduinoio:general:BTRadioNotAvailableText').getString))
                obj.StatusTable.Steps = {message('MATLAB:ble:ble:invalidMacBluetoothState').getString};
            end
            obj.StatusTable.Status = {matlab.hwmgr.internal.hwsetup.StatusIcon.Fail};
        end
        function buttonCallback(obj, ~, ~)
            %Function that is invoked when the button is clicked. This 
            %function trys to create an Arduino object.
            
            % Disable screen during test connection
            obj.TestConnProgress.Visible = 'on';
            c = onCleanup(@() cleanup(obj));
            disableScreen(obj);
            obj.TestConnProgress.Indeterminate = true;
            drawnow;
            obj.HelpText.WhatToConsider = '';
            [result, err] = testConnection(obj.Workflow.HWInterface, obj.Workflow);
            obj.Workflow.TestConnectionResult = logical(result);
            
            % set StatusTable Visible on
            obj.StatusTable.Visible = 'on';
            obj.StatusTable.Status = {''};    
            
            if result             
                obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:TestConnectionScreenWhatToConsider').getString;
                if obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                    obj.StatusTable.Steps = {message('MATLAB:arduinoio:general:testConnectionSuccessSerial').getString};
                    obj.StatusTable.Status = {matlab.hwmgr.internal.hwsetup.StatusIcon.Pass};
                else
                    obj.StatusTable.Steps = {message('MATLAB:arduinoio:general:testConnectionSuccess').getString};                    
                    obj.StatusTable.Status = {matlab.hwmgr.internal.hwsetup.StatusIcon.Pass};
                end
            else                
                if strcmpi(err.identifier, 'MATLAB:hwsdk:general:connectionExists')
                    obj.StatusTable.Steps = {message('MATLAB:arduinoio:general:testConnectionFailedConnectionExists',err.message).getString};
                    obj.StatusTable.Status = {matlab.hwmgr.internal.hwsetup.StatusIcon.Fail};
                    integrateErrorKey(obj.Workflow, 'MATLAB:arduinoio:general:testConnectionFailedConnectionExists',obj.Workflow.Board, obj.Workflow.ConnectionType,obj.StatusTable.Status);
				elseif strcmpi(err.identifier, 'MATLAB:hwsdk:general:invalidSPPKGVersion')
                    obj.StatusTable.Steps = {message('MATLAB:arduinoio:general:invalidSPPKGVersionHWSETUP').getString};
                    obj.StatusTable.Status = {matlab.hwmgr.internal.hwsetup.StatusIcon.Fail};
                    integrateErrorKey(obj.Workflow, 'MATLAB:arduinoio:general:invalidSPPKGVersionHWSETUP',obj.Workflow.Board, obj.Workflow.ConnectionType,obj.StatusTable.Status);
                else
                    obj.StatusTable.Steps = {message('MATLAB:arduinoio:general:testConnectionFailed').getString};
                    obj.StatusTable.Status = {matlab.hwmgr.internal.hwsetup.StatusIcon.Fail};
                    integrateErrorKey(obj.Workflow, 'MATLAB:arduinoio:general:testConnectionFailed',obj.Workflow.Board, obj.Workflow.ConnectionType,obj.StatusTable.Status);
                end
            end
            
            function cleanup(obj)
                enableScreen(obj);
                try
                    obj.TestConnProgress.Indeterminate = false;
                    obj.TestConnProgress.Visible = 'off';
                    drawnow;
                catch
                end
            end
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
