classdef UpdateServerScreen < arduinoio.setup.internal.ESP32UpdateServerScreenHelper
%UPDATESERVERSCREEN The UpdateServerScreen is one screen that is meant
%to be included in a package of screens that make up a setup app. There
%is a Workflow object that is passed from screen to screen to keep
%workflow specific persistent variables available throughout the entire
%sequence.
%
% The UpdateServerScreen is used to allow users to choose Arduino board
% related information, including board, port and libraries, so that it
% programs the board with correct server.

% Copyright 2016-2024 The MathWorks, Inc.

    properties(SetAccess = private, GetAccess = public)
        %ConnectUSBLabelText - Label that shows connect USB
        ConnectUSBLabelText
        %BoardDropDown - Dropdown menu that selects the board
        BoardDropDown
        %CheckBoxList - CheckBox list that selects libraries
        CheckBoxList
        %PortDropDown - Dropdown menu that selects the port
        PortDropDown
        %ProgramProgress - Progress bar that shows status
        ProgramProgress
        %ProgramButton - Progress button that starts programming
        ProgramButton
        %ProgramNote - Note to remove Bluetooth device
        ProgramNote
        %BoardLabelText - Label that shows choose board text
        BoardLabelText
        %PortLabelText - Label that shows choose port text
        PortLabelText
        %LibrariesLabelText - Label that shows choose library text
        LibrariesLabelText
        %ProgramLabelText - Label that shows program text
        ProgramLabelText
        %ErrorLabelHTMLText - Label that shows program error text with HTMLText
        ErrorLabelHTMLText
        %PrevConnectionType - Connection type saved before leaving the screen
        PrevConnectionType
        %PrevBoard - Board saved before leaving the screen
        PrevBoard
        %PrevEncryption - Encryption type saved before leaving the screen
        PrevEncryption
        %PrevSSID - SSID saved before leaving the screen
        PrevSSID
        %PrevPassword - Password saved before leaving the screen
        PrevPassword
        %PrevPort - TCPIPPort saved before leaving the screen
        PrevPort
        %PrevKeyIndex - Key index saved before leaving the screen
        PrevKeyIndex
        %PrevKey - Key saved before leaving the screen
        PrevKey
        %CurrentServer - Server settings saved after last successful upload
        CurrentServer
        % HelpText for log link
        LogLink
        %ErrorLabelText - Label that shows program error text
        ErrorLabelText
    end

    properties(Access = private, Constant=true)
        FontSize = 12
    end

    methods(Access = 'public')
        function obj = UpdateServerScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@arduinoio.setup.internal.ESP32UpdateServerScreenHelper(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:UpdateServerScreenTitle').getString;
            obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:UpdateServerScreenAboutSelection').getString;
            if obj.Workflow.ConnectionType~=matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:UpdateServerScreenWhatToConsider').getString;
            else
                obj.HelpText.WhatToConsider = '';
            end
            obj.NextButton.Enable = 'off';
            buildContentPane(obj);
        end

        function id = getPreviousScreenID(obj)
            if obj.Workflow.isUsingRemoteHW()
                % Logic for MATLAB Online
                id = 'arduinoio.setup.internal.online.ConnectBoardScreen';
            else
                % Logic for MATLAB Desktop 
                id = 'arduinoio.setup.internal.SelectConnectionScreen';
            end
            saveCurrentSettings(obj);
        end

        function  id = getNextScreenID(obj)
            switch obj.Workflow.ConnectionType
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                id = 'arduinoio.setup.internal.TestConnectionScreen';
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                id = 'arduinoio.setup.internal.SelectBTDeviceScreen';
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                id = 'arduinoio.setup.internal.TestConnectionScreen';
            end
            saveCurrentSettings(obj);
            c = onCleanup(@() integrateData(obj.Workflow, obj.Workflow.Board, obj.Workflow.ConnectionType, obj.CheckBoxList.Values));
        end

        function reinit(obj)
        % Rerender screen when connection type has changed or any WiFi
        % settings has changed
            if (obj.PrevConnectionType ~= obj.Workflow.ConnectionType) || ...
                    (obj.PrevPort~=obj.Workflow.TCPIPPort)||...
                    (~isequal(obj.PrevEncryption, obj.Workflow.Encryption))||...
                    (~isequal(obj.PrevSSID, obj.Workflow.SSID)) || ...
                    (~isequal(obj.PrevPassword, obj.Workflow.Password)) ||...
                    (~isequal(obj.PrevKey, obj.Workflow.Key)) ||...
                    (~isequal(obj.PrevKeyIndex, obj.Workflow.KeyIndex))
                obj.CurrentServer = '';
                obj.NextButton.Enable = 'off';
                obj.ErrorLabelText.Text = '';
                obj.ErrorLabelText.Visible = 'on';
                obj.ErrorLabelHTMLText.Visible = 'off';
                if ~isempty(obj.LogLink)
                    obj.LogLink.Visible = 'off';
                    delete(obj.LogLink);
                    obj.LogLink=[];
                end
            end
            updateBoardDropdown(obj);
            updatePortDropdown(obj);
            if obj.Workflow.ConnectionType~=matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:UpdateServerScreenWhatToConsider').getString;
            else
                obj.HelpText.WhatToConsider = '';
            end
        end

        function show(obj)
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj);
            obj.ProgramProgress.Visible = 'off';
        end
    end

    methods(Access = 'private')
        function buildContentPane(obj)
        %BUILDCONTENTPANE - constructs all of the elements for the
        %content pane and adds them to the content pane element
        %collection
            obj.ConnectUSBLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                           message('MATLAB:arduinoio:general:UpdateServerScreenConnectUSBText').getString, [20 365 300 20], obj.FontSize);
            obj.BoardLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                      message('MATLAB:arduinoio:general:chooseBoardText').getString, [20 340 100 20], obj.FontSize);
            obj.PortLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                     message('MATLAB:arduinoio:general:chooseArduinoPortText').getString, [obj.BoardLabelText.Position(1)+230 obj.BoardLabelText.Position(2) 100 20], obj.FontSize);
            %Set up the dropdown menu to select board
            startPosition = obj.BoardLabelText.Position(1);
            if ismac
                startPosition = startPosition-10;
            end
            obj.Install3pLibLabelText = arduinoio.setup.internal.ScreenHelper.buildHTMLLabel(obj.ContentPanel, ...
                                                                                             message('MATLAB:arduinoio:general:install3pLibText').getString, [40 295 300 20]);
            obj.Install3pLibCheckBox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.ContentPanel, ...
                                                                                           '',[20 295 30 20],@obj.Install3pLibrary,true);
            obj.Install3pLibCheckBox.Visible = 'off';
            obj.Install3pLibLabelText.Visible = 'off';

            obj.InstallServoESP323pLibLabelText = arduinoio.setup.internal.ScreenHelper.buildHTMLLabel(obj.ContentPanel, ...
                                                                                                       message('MATLAB:arduinoio:general:installServoESP323pLibText').getString, [40 280 320 20]);
            obj.InstallServoESP323pLibCheckBox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.ContentPanel, ...
                                                                                                     '',[20 280 30 20],@obj.InstallServoESP323pLibrary,true);
            obj.InstallServoESP323pLibCheckBox.Visible = 'off';
            obj.InstallServoESP323pLibLabelText.Visible = 'off';

            obj.BoardDropDown = arduinoio.setup.internal.ScreenHelper.buildDropDown(obj.ContentPanel,...
                                                                                    {'dummy'}, [startPosition obj.BoardLabelText.Position(2)-20 180 20], @obj.updateBoard, 1);
            updateBoardDropdown(obj);

            %Set up the dropdown menu to select port
            obj.PortDropDown = arduinoio.setup.internal.ScreenHelper.buildDropDown(obj.ContentPanel,...
                                                                                   {'dummy'}, [startPosition+230 obj.BoardLabelText.Position(2)-20 110 20], @obj.updatePort, 1);
            updatePortDropdown(obj);
            if ~ispc
                obj.PortDropDown.addWidth(70);
            end

            %Set up the checkbox list for selecting libraries
            obj.LibrariesLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                          message('MATLAB:arduinoio:general:UpdateServerScreenLibraryText').getString, [20 255 430 20], obj.FontSize);

            availableLibs = listArduinoLibraries;
            index = contains(availableLibs, arduinoio.internal.ArduinoConstants.DefaultLibraries);

            values = [];
            for i=1:numel(index)
                if(index(i)==1)
                    values = [values i];%#ok<AGROW>
                end
            end

            obj.CheckBoxList = arduinoio.setup.internal.ScreenHelper.buildCheckboxList(obj.ContentPanel, ...
                                                                                       message('MATLAB:arduinoio:general:SelectAllLibrariesTitle').getString, availableLibs', [20 155 350 100], [30, 350], @obj.selectIncludedLibrary, values);

            %Set up program label/progress bar/button to upload server
            obj.ProgramButton = arduinoio.setup.internal.ScreenHelper.buildButton(obj.ContentPanel, ...
                                                                                  message('MATLAB:arduinoio:general:programButtonText').getString, [20 100 100 23], @obj.uploadServer);
            obj.ProgramLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                        message('MATLAB:arduinoio:general:UpdateServerScreenButtonText').getString, [20 130 430 20], obj.FontSize);
            obj.ProgramProgress = matlab.hwmgr.internal.hwsetup.ProgressBar.getInstance(obj.ContentPanel);
            obj.ProgramProgress.Position = [obj.ProgramButton.Position(1)+130 obj.ProgramButton.Position(2) 280 22];

            %Set up error text label
            obj.ErrorLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, '', [20 50 450 50], obj.FontSize);
            obj.ErrorLabelHTMLText = matlab.hwmgr.internal.hwsetup.StatusTable.getInstance(obj.ContentPanel);
            obj.ErrorLabelHTMLText.Status = {''};
            obj.ErrorLabelHTMLText.Steps = {''};
            obj.ErrorLabelHTMLText.Position = [20 30 420 60];
            obj.ErrorLabelHTMLText.Visible = 'off';
        end

        function updateBoardDropdown(obj)
        %Helper function that shows the correct set of boards based on
        %connection type selected.
            [boards, index] = getSupportedBoards(obj.Workflow.HWInterface, obj.Workflow.ConnectionType, obj.Workflow.Board);
            if obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi && obj.Workflow.Encryption == matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WEP
                % WEP not supported for ESP32 and Uno R4 boards
                boards = setdiff(boards,arduinoio.internal.ArduinoConstants.WEPNotSupportedBoards,'stable');
            end
            if obj.Workflow.isUsingRemoteHW()
                % MATLAB Online does not support ESP32 boards
                boards = setdiff(boards,{'ESP32-WROOM-DevKitV1', 'ESP32-WROOM-DevKitC'},'stable');
            end
            obj.BoardDropDown.Items = boards;
            obj.BoardDropDown.ValueIndex = index;
        end

        function updatePortDropdown(obj)
        %Helper function that shows the correct set of ports at current
        %screen
        %Keep the same selected port if board has not changed
            if strcmpi(obj.PrevBoard, obj.Workflow.Board)
                [availablePorts, index] = getAvailableArduinoPorts(obj.Workflow.HWInterface, obj.Workflow.Port);
            else %Reset port to "select a value" if board has changed
                [availablePorts, index] = getAvailableArduinoPorts(obj.Workflow.HWInterface, 'select a value');
            end
            obj.PortDropDown.Items = availablePorts;
            obj.PortDropDown.ValueIndex = index;
            obj.Workflow.Port = obj.PortDropDown.Value;
        end

        function updateBoard(obj, src, ~)
        %Function that is invoked when a radio button is selected. This
        %function updates the selection.
            obj.Workflow.Board = src.Value;
            checkExistingServer(obj);
            if ismember(obj.Workflow.Board ,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'})
                if ~exist(fullfile(arduinoio.CLIRoot,'data','packages','esp32'),'dir')
                    obj.Install3pLibCheckBox.Visible = 'on';
                    obj.Install3pLibLabelText.Visible = 'on';
                else
                    obj.Install3pLibCheckBox.Visible = 'off'; % library exists
                    obj.Install3pLibLabelText.Visible = 'off';
                end

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

        function updatePort(obj, src, ~)
        %Function that is invoked when a dropdown is selected. This
        %function updates the selection.
            obj.Workflow.Port = src.Value;
            checkExistingServer(obj);
        end

        function selectIncludedLibrary(obj, src, event)
        %Function that is invoked when a checkbox is updated in the
        %checkbox list for selecting libraries
            if(~strcmpi(event.EventName,'PostSet') && event.Indices(1) ~= 1)
                % get additioanl dependant libs if any
                % 1 subtracted from event.Indices to get library index in src.Items as first index is select all
                libs = arduinoio.internal.getFullLibraryList(src.Items(event.Indices(1)-1));

                % cell selection event invokes call back
                if(strcmpi(event.EventName,'CellSelection'))
                    if ~ismember(event.Indices(1)-1, src.ValueIndex)
                        % unchecked box
                        uncheckedLibraryBox;
                    else
                        %checked box
                        checkedLibraryBox;
                    end
                    % call back invoked on check box check/uncheck
                elseif(event.EditData)
                    % checked box
                    checkedLibraryBox;
                else % unchecked box
                    uncheckedLibraryBox;
                end
            elseif(strcmpi(event.EventName,'PostSet')) % PostSet event
                libs = src.Values;
                depLibs = arduinoio.internal.getFullLibraryList(libs);
                index = contains(src.Items, depLibs);
                for i=1:numel(index)
                    if(index(i)==1)
                        src.ValueIndex = union(src.ValueIndex,i);
                    end
                end
                obj.Workflow.Libraries = src.Values;
            else% In case of first index, library list is equal to src.Values
                obj.Workflow.Libraries = src.Values;
                % Check and uncheck the libraries when "Select All" is
                % selected
                if(event.EditData)
                    % checked box
                    checkedLibraryBox;
                else % unchecked box
                    uncheckedLibraryBox;
                end
            end
            checkExistingServer(obj);

            function checkedLibraryBox
            % Check when "Servo" library is checked, this will help in checking "Servo 3p" library for ESP32
                if(event.Indices(1) == 1)  % Indicates "Select All" is checked
                    isServoChecked = true;
                elseif strcmpi(src.Items(event.Indices(1)-1),'Servo') % Indicates when "Servo" library is checked
                    isServoChecked = true;
                else
                    isServoChecked = false; % other scenarios
                end
                % Show Servo install  checkbox if servo selected
                if ismember(obj.Workflow.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}) && (isServoChecked)
                    obj.InstallServoESP323pLibCheckBox.Visible = 'on';
                    obj.InstallServoESP323pLibLabelText.Visible = 'on';
                    if ~obj.InstallServoESP323p
                        obj.InstallServoESP323p = true;
                        obj.InstallServoESP323pLibCheckBox.Value = 1;
                    end
                end
                % 1 subtracted from event.Indices to get library index in src.Items as first index is select all

                %update the workflow libraries to include the selected
                %library
                if(event.Indices(1) ~= 1)
                    obj.Workflow.Libraries = union(obj.Workflow.Libraries, src.Items(event.Indices(1)-1));
                    if numel(libs)>1 % checked lib has dependent libs
                        for index1=1:numel(src.Items)
                            if ismember(src.Items(index1),libs)
                                src.ValueIndex = union(src.ValueIndex,index1);
                                obj.Workflow.Libraries = union(obj.Workflow.Libraries, src.Values);
                            end
                        end
                    end
                end
            end

            function uncheckedLibraryBox
            % Check when "Servo" library is unchecked, this will help in unchecking "Servo 3p" library for ESP32
                if(event.Indices(1) == 1) % Indicates "Select All" is unchecked
                    isServoUnChecked = true;
                elseif strcmpi(src.Items(event.Indices(1)-1),'Servo') % Indicates when "Servo" library is unchecked
                    isServoUnChecked = true;
                else
                    isServoUnChecked = false; % other scenarios
                end
                % Hide Servo install  checkbox if servo unselected
                if ismember(obj.Workflow.Board,{'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}) && isServoUnChecked
                    obj.InstallServoESP323pLibCheckBox.Visible = 'off';
                    obj.InstallServoESP323pLibLabelText.Visible = 'off';
                    if obj.InstallServoESP323p
                        obj.InstallServoESP323p = false;
                    end
                end
                % check if lib to be removed is dependent by any checked lib
                % 1 subtracted from event.Indices to get library index in src.Items as first index is select all
                for index2=1:numel(obj.Workflow.Libraries)
                    libs = arduinoio.internal.getFullLibraryList(obj.Workflow.Libraries(index2));
                    if numel(libs)>1&&~strcmpi(src.Items(event.Indices(1)-1),obj.Workflow.Libraries{index2})&&ismember(src.Items(event.Indices(1)-1),libs)
                        src.ValueIndex = [src.ValueIndex event.Indices(1)-1];
                        return;
                    end
                end
                obj.Workflow.Libraries = src.Values;
            end
        end

        function uploadServer(obj, ~, ~)
        %Function that programs the board with Arduino server based on
        %user-selected information
            obj.ProgramProgress.Visible = 'on';
            c = onCleanup(@() cleanup(obj));
            successFlag = false;
           
            obj.ProgramProgress.Indeterminate = true;
            if strcmpi(obj.Workflow.Port, 'select a value')
                id = 'MATLAB:arduinoio:general:noSerialPort';
                integrateErrorKey(obj.Workflow, id);
                error(id, message(id).getString);
            end
            if strcmpi(obj.Workflow.Board, 'select a value')
                id = 'MATLAB:arduinoio:general:noBoardSelected';
                integrateErrorKey(obj.Workflow, id);
                error(id, message(id).getString);
            end

            if ismember(obj.Workflow.Board,{'Leonardo','Micro'}) && ismember('Serial',obj.Workflow.Libraries) && (obj.Workflow.ConnectionType ==  matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth)
                id = 'MATLAB:hwsdk:general:notSupportedInterfaceBT';
                integrateErrorKey(obj.Workflow, id, obj.BoardDropDown.Value, obj.Workflow.ConnectionType,obj.CheckBoxList.Values);
                error(id, message(id,'Serial',obj.Workflow.Board).getString);
            elseif ~ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.SerialLibrarySupportBoards) && ismember('Serial',obj.Workflow.Libraries)
                id = 'MATLAB:arduinoio:general:notSupportedInterfaceHardwareSetupScreen';
                integrateErrorKey(obj.Workflow, id, obj.BoardDropDown.Value, obj.Workflow.ConnectionType,obj.CheckBoxList.Values);
                error(id, message(id,'Serial',obj.Workflow.Board).getString);
            elseif ~ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.RotaryEncoderSupportedBoards) && ismember('RotaryEncoder',obj.Workflow.Libraries)
                id = 'MATLAB:arduinoio:general:notSupportedLibraryHardwareSetupScreen';
                integrateErrorKey(obj.Workflow, id, obj.BoardDropDown.Value, obj.Workflow.ConnectionType, obj.CheckBoxList.Values);
                error(id, message(id,'RotaryEncoder',obj.Workflow.Board).getString);
            elseif ~ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.MKRMotorCarrierLibrarySupportedBoards) && ismember('MKRMotorCarrier',obj.Workflow.Libraries)
                id = 'MATLAB:arduinoio:general:unsupportedMKRMCLibrary';
                integrateErrorKey(obj.Workflow, id, obj.BoardDropDown.Value, obj.Workflow.ConnectionType,obj.CheckBoxList.Values);
                error(id, message(id, obj.Workflow.Board).getString);
            elseif ~ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.MotorCarrierLibrarySupportedBoards) && ismember('MotorCarrier',obj.Workflow.Libraries)
                id = 'MATLAB:arduinoio:general:unsupportedMCLibrary';
                integrateErrorKey(obj.Workflow, id, obj.BoardDropDown.Value, obj.Workflow.ConnectionType,obj.CheckBoxList.Values);
                error(id, message(id, obj.Workflow.Board).getString);
            elseif ~ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.AdafruitMotorShieldSupportedBoards) && ismember('Adafruit/MotorShieldV2',obj.Workflow.Libraries)
                id = 'MATLAB:arduinoio:general:notSupportedLibraryHardwareSetupScreen';
                integrateErrorKey(obj.Workflow, id, obj.BoardDropDown.Value, obj.Workflow.ConnectionType,obj.CheckBoxList.Values);
                error(id, message(id,'Adafruit/MotorShieldV2',obj.Workflow.Board).getString);
            elseif ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.MKRMotorCarrierLibrarySupportedBoards)
                % Error out if both of the libraries 'MotorCarrier' and 'Arduino/MKRMotorCarrier' from libOptions are
                % selected for MKR boards in the Hardware Setup Screen
                % NOTE: Only one of the libOptions libraries is allowed to be specified
                % Since MKRMotorCarrier library has been removed from R2021b onward, the
                % libOptions do not contain it anymore (had it till R2021a)
                libOptions = {'MotorCarrier','Arduino/MKRMotorCarrier'};
                % Find out the indices of specified motor carrier libraries
                libIndex = double(ismember(libOptions, obj.Workflow.Libraries));
                if nnz(libIndex) == 2
                    % If both of the libraries are specified, throw a
                    % conflictingLibrary error
                    libPrint = ['both ', libOptions{1}, ' and ', libOptions{2}];
                    id = 'MATLAB:arduinoio:general:conflictingLibrary';
                    integrateErrorKey(obj.Workflow, id, obj.Workflow.Board, obj.Workflow.ConnectionType, obj.BoardDropDown.Value,obj.CheckBoxList.Values);
                    error(id, message(id, libPrint).getString);
                end
            end

            disableScreen(obj);
            customDisableCheckboxList(obj);
            status = complete3pInstall(obj);
            obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorPrimary;
            if status
                obj.ErrorLabelHTMLText.Status= {matlab.hwmgr.internal.hwsetup.StatusIcon.Fail};
                obj.ErrorLabelHTMLText.Steps = {getString(message('MATLAB:arduinoio:general:FailedToInstall3pLibrary'))};
                obj.ErrorLabelText.Visible = 'off';
                obj.ErrorLabelHTMLText.Visible = 'on';
                enableScreen(obj);
                customEnableCheckboxList(obj);
                obj.ProgramProgress.Indeterminate = false;
                obj.ProgramProgress.Visible = 'off';
                return;
            else
                obj.Install3pLibCheckBox.Visible = 'off';
                obj.Install3pLibLabelText.Visible = 'off';
                obj.InstallServoESP323pLibCheckBox.Visible = 'off';
                obj.InstallServoESP323pLibLabelText.Visible = 'off';
            end

            obj.ErrorLabelText.Text =  getString(message('MATLAB:arduinoio:general:programmingArduino', obj.Workflow.Board, obj.Workflow.Port));
            if ~isempty(obj.LogLink)
                obj.LogLink.Visible = 'off';
                delete(obj.LogLink);
                obj.LogLink = [];
            end
            drawnow;
            try
                msg = uploadArduinoServer(obj.Workflow.HWInterface,obj.Workflow);
                if ~isempty(msg)
                    obj.ErrorLabelText.FontColor =matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                    obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:programArduinoFailed'));
                    log(obj.Workflow.Logger, msg);
                    obj.LogLink = matlab.hwmgr.internal.hwsetup.HTMLText.getInstance(obj.ContentPanel);
                    obj.LogLink.Text =  getString(message('MATLAB:arduinoio:general:programLogLinkText',obj.Workflow.LogFileName,obj.Workflow.LogFileName));
                    obj.LogLink.Position =  [20 20 400 25];
                    return;
                end
                if obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                    obj.ErrorLabelText.Text =  message('MATLAB:arduinoio:general:obtainingIP').getString;
                    drawnow;
                    ipAddress = retrieveIPAddress(obj.Workflow.HWInterface, obj.Workflow.Port,obj.Workflow.Board);
                    if isempty(ipAddress)
                        obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:obtainIPFailed').getString;
                    else
                        obj.Workflow.DeviceAddress = ipAddress;
                        successFlag = true;
                        obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:operationSuccessText').getString;
                    end
                else
                    obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:operationSuccessText').getString;
                    successFlag = true;
                end
                if successFlag
                    obj.ErrorLabelText.FontColor = '--mw-color-success';
                else
                    obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                end
            catch e
                integrateErrorKey(obj.Workflow, e.identifier);
                obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                switch e.identifier
                  case 'MATLAB:arduinoio:general:openFailed'
                    obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:openArduinoFailed', obj.Workflow.Port, obj.Workflow.Board));
                  case 'MATLAB:RMDIR:NoDirectoriesRemoved'
                    obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:NoDirectoriesRemoved', fullfile(tempdir, 'ArduinoServer')));
                  case 'MATLAB:arduinoio:general:invalidCLIPath'
                    obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:invalidCLIPathNoLink', arduinoio.CLIRoot));
                  otherwise
                    obj.ErrorLabelText.Text = e.message;
                end
            end

            function cleanup(obj)
                enableScreen(obj);
                customEnableCheckboxList(obj);
                try
                    obj.ProgramProgress.Indeterminate = false;
                    obj.ProgramProgress.Visible = 'off';
                    if successFlag
                        obj.NextButton.Enable = 'on';
                        saveServerSettings(obj);
                    else
                        obj.NextButton.Enable = 'off';
                    end
                catch
                end
            end
        end

        function checkExistingServer(obj)
            if ~isempty(obj.CurrentServer)
                if (~isequal(obj.CurrentServer.Board, obj.Workflow.Board)) || ...
                        (~isequal(obj.CurrentServer.Port, obj.Workflow.Port)) ||...
                        (~isequal(sort(obj.CurrentServer.Libraries), sort(obj.Workflow.Libraries)))
                    obj.NextButton.Enable = 'off';
                    obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                    obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:reprogramArduinoText').getString;
                else
                    obj.NextButton.Enable = 'on';
                    obj.ErrorLabelText.FontColor = '--mw-color-success';
                    obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:operationSuccessText').getString;
                end
            end
        end

        function saveServerSettings(obj)
            obj.CurrentServer.Board = obj.Workflow.Board;
            obj.CurrentServer.Port = obj.Workflow.Port;
            obj.CurrentServer.Libraries = obj.Workflow.Libraries;
        end

        function saveCurrentSettings(obj)
            obj.PrevConnectionType = obj.Workflow.ConnectionType;
            obj.PrevBoard = obj.Workflow.Board;
            obj.PrevSSID = obj.Workflow.SSID;
            obj.PrevPassword = obj.Workflow.Password;
            obj.PrevKey = obj.Workflow.Key;
            obj.PrevKeyIndex = obj.Workflow.KeyIndex;
            obj.PrevPort = obj.Workflow.TCPIPPort;
            obj.PrevEncryption = obj.Workflow.Encryption;
        end

        function customDisableCheckboxList(obj)
            obj.CheckBoxList.Enable = 'off';
        end
        function customEnableCheckboxList(obj)
            obj.CheckBoxList.Enable = 'on';
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
