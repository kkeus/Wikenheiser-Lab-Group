classdef UpdateServerScreenBLE < arduinoio.setup.internal.ESP32UpdateServerScreenHelper
%UPDATESERVERSCREENBLE The UpdateServerScreenBLE is one screen that is meant
%to be included in a package of screens that make up a setup app. There
%is a Workflow object that is passed from screen to screen to keep
%workflow specific persistent variables available throughout the entire
%sequence.
%
% The UpdateServerScreenBLE is used to allow users to choose Arduino board
% related information, including device name and libraries, so that it
% programs the board with correct server.

% Copyright 2021-2023 The MathWorks, Inc.

    properties(SetAccess = private, GetAccess = public)
        %NameLabel - label to show name label drop down
        NameLabel
        %EnterNameLabel - enter name label
        EnterNameLabel
        %DeviceListDropDown -Editable Device List drop down
        DeviceListDropDown
        %CheckBoxList - CheckBox list that selects libraries
        CheckBoxList
        %ProgramProgress - Progress bar that shows status
        ProgramProgress
        %ProgramButton - Progress button that starts programming
        ProgramButton
        %ProgramNote - Note to remove Bluetooth device
        ProgramNote
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
        %CurrentServer - Server settings saved after last successful upload
        CurrentServer
        % HelpText for log link
        LogLink
        % Busy Overlay widget displays progress while getting ble list
        BusyOverlay
        %ErrorLabelText - Label that shows program error text
        ErrorLabelText
    end

    properties(Access = private, Constant=true)
        FontSize = 13
        LibraryLabelTextPositionBLE = [20 310 430 20]
        LibraryLabelTextPositionBT = [20 340 430 20]
        CheckBoxListPositionBT = [20 140 350 167]
        CheckBoxListPositionBLE = [20 143 350 125]
        Install3pLibLabelTextPosition = [40 295 300 20]
        Install3pLibCheckBoxPosition = [20 295 30 20]
        InstallServoESP323pLibLabelTextPosition = [40 280 320 20]
        InstallServoESP323pLibCheckBoxPosition = [20 280 30 20]
    end

    properties(Access = private)
        % map to retain info retained from board while reconfiguring
        DeviceInfoMap = containers.Map();
    end

    methods(Access = 'public')
        function obj = UpdateServerScreenBLE(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@arduinoio.setup.internal.ESP32UpdateServerScreenHelper(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:UpdateServerScreenTitle').getString;
            obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:UpdateServerScreenAboutSelection').getString;
            if obj.Workflow.ConnectionType==matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:UpdateServerScreenBLEWhatToConsider').getString;
            else
                obj.HelpText.WhatToConsider = '';
            end
            % Disable the NextButton before building the content pane.
            % This eliminates the possibility for executing the next button
            % callback (see matlab.hwmgr.internal.hwsetup.TemplateBase)
            % multiple number of times in case the Next button on the
            % BoardSelectionScreen is clicked much faster than the time it
            % takes for the UpdateServerScreenBLE object to construct.
            % If NexButton is enabled after buildContentPane here, the next
            % screen ID is incorrectly fetched as SelectBTDeviceScreen
            % instead of UpdateServerScreenBLE if the next button on the
            % BoardSelectionScreen is clicked rapidly multiple number
            % of times. This happens because the Next button on the
            % UpdateServerScreenBLE is now already enabled before its
            % object could even get constructed.
            obj.NextButton.Enable = 'off';
            buildContentPane(obj);
        end

        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.BoardSelectionScreen';
            saveCurrentSettings(obj);
        end

        function  id = getNextScreenID(obj)
            switch obj.Workflow.ConnectionType
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                id = 'arduinoio.setup.internal.TestConnectionScreen';
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                id = 'arduinoio.setup.internal.SelectBTDeviceScreen';
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                id = 'arduinoio.setup.internal.TestConnectionScreen';
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                id = 'arduinoio.setup.internal.TestConnectionScreen';
            end
            saveCurrentSettings(obj);
            c = onCleanup(@() integrateData(obj.Workflow, obj.Workflow.Board, obj.Workflow.ConnectionType, obj.CheckBoxList.Values));
        end

        function reinit(obj)
        % Rerender screen when connection type has changed or any WiFi
        % settings has changed
            if (obj.PrevConnectionType ~= obj.Workflow.ConnectionType)
                obj.CurrentServer = '';
                obj.NextButton.Enable = 'off';
                obj.ErrorLabelText.Text = '';
                obj.ErrorLabelHTMLText.Visible = 'off';
                if ~isempty(obj.LogLink)
                    obj.LogLink.Visible = 'off';
                    delete(obj.LogLink);
                    obj.LogLink=[];
                end
                updateWidgets(obj);
            end
            checkExistingServer(obj);
            update3pWidgets(obj);
            if obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:UpdateServerScreenBLEWhatToConsider').getString;
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
            obj.NameLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                 message('MATLAB:arduinoio:general:SelectorEnterNameText').getString, [20 355 430 20], obj.FontSize);
            obj.EnterNameLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                      message('MATLAB:arduinoio:general:EnterNameText').getString, [20 330 100 20], obj.FontSize);
            obj.DeviceListDropDown = arduinoio.setup.internal.ScreenHelper.buildEditableDropDown(obj.ContentPanel, ...
                                                                                                 {'Item1', 'Item2'},[60 330 250 20],@obj.selectDeviceCallBack,1);

            %Set up the checkbox list for selecting libraries
            obj.LibrariesLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                          message('MATLAB:arduinoio:general:UpdateServerScreenLibraryText').getString, [20 290 430 20], obj.FontSize);

            availableLibs = listArduinoLibraries;
            index = contains(availableLibs, arduinoio.internal.ArduinoConstants.DefaultLibraries);
            values = [];
            for i=1:numel(index)
                if(index(i)==1)
                    values = [values i];%#ok<AGROW>
                end
            end
            obj.CheckBoxList = arduinoio.setup.internal.ScreenHelper.buildCheckboxList(obj.ContentPanel, ...
                                                                                       message('MATLAB:arduinoio:general:SelectAllLibrariesTitle').getString, availableLibs', [20 180 350 125], [30, 300], @obj.selectIncludedLibrary, values);

            % Check if the board is ESP32
            if ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.ESP32Boards)
                % Setup widgets for installing 3p for ESP32 boards
                obj.Install3pLibLabelText = arduinoio.setup.internal.ScreenHelper.buildHTMLLabel(obj.ContentPanel, ...
                                                                                                 message('MATLAB:arduinoio:general:install3pLibText').getString, obj.Install3pLibLabelTextPosition);
                obj.Install3pLibCheckBox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.ContentPanel, ...
                                                                                               '',obj.Install3pLibCheckBoxPosition,@obj.Install3pLibrary,true);
                obj.Install3pLibCheckBox.Visible = 'off';
                obj.Install3pLibLabelText.Visible = 'off';
                obj.Install3pLibCheckBox.Enable = 'on';

                obj.InstallServoESP323pLibLabelText = arduinoio.setup.internal.ScreenHelper.buildHTMLLabel(obj.ContentPanel, ...
                                                                                                           message('MATLAB:arduinoio:general:installServoESP323pLibText').getString, obj.InstallServoESP323pLibLabelTextPosition);
                obj.InstallServoESP323pLibCheckBox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.ContentPanel, ...
                                                                                                         '',obj.InstallServoESP323pLibCheckBoxPosition,@obj.InstallServoESP323pLibrary,true);
                obj.InstallServoESP323pLibCheckBox.Visible = 'off';
                obj.InstallServoESP323pLibLabelText.Visible = 'off';
                obj.InstallServoESP323pLibCheckBox.Enable = 'on';
            end

            %Set up program label/progress bar/button to upload server
            obj.ProgramButton = arduinoio.setup.internal.ScreenHelper.buildButton(obj.ContentPanel, ...
                                                                                  message('MATLAB:arduinoio:general:programButtonText').getString, [20 100 100 23], @obj.uploadServer);
            obj.ProgramLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                                                                                        message('MATLAB:arduinoio:general:UpdateServerScreenButtonText').getString, [20 125 430 20], obj.FontSize);
            obj.ProgramProgress = matlab.hwmgr.internal.hwsetup.ProgressBar.getInstance(obj.ContentPanel);
            obj.ProgramProgress.Position = [obj.ProgramButton.Position(1)+130 obj.ProgramButton.Position(2) 280 22];

            %Set up error text label
            obj.ErrorLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, '', [20 50 450 50], obj.FontSize);
            obj.ErrorLabelHTMLText = matlab.hwmgr.internal.hwsetup.StatusTable.getInstance(obj.ContentPanel);
            obj.ErrorLabelHTMLText.Status = {''};
            obj.ErrorLabelHTMLText.Steps = {''};
            obj.ErrorLabelHTMLText.Position = [20 30 420 60];
            obj.ErrorLabelHTMLText.Visible = 'off';

            obj.BusyOverlay = matlab.hwmgr.internal.hwsetup.BusyOverlay.getInstance(obj.ContentPanel);
            obj.BusyOverlay.Text =  message('MATLAB:arduinoio:general:DetectingDeviceList').getString;
            obj.BusyOverlay.Visible = 'off';
            updateWidgets(obj);
            checkExistingServer(obj);
            update3pWidgets(obj);
        end

        function updateWidgets(obj)
            if obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                % create ble name dropdown with current devices detected and
                % the default name
                obj.BusyOverlay.Visible = 'on';
                obj.show();
                items = getDeviceList(obj);
                obj.DeviceListDropDown.Items = items;
                % set default value for DeviceName
                obj.Workflow.DeviceName = obj.DeviceListDropDown.Value;
                obj.LibrariesLabelText.Position = obj.LibraryLabelTextPositionBLE;
                obj.CheckBoxList.Position = obj.CheckBoxListPositionBLE;
            else % Bluetooth
                obj.NameLabel.Visible = 'off';
                obj.EnterNameLabel.Visible = 'off';
                obj.DeviceListDropDown.Visible = 'off';
                obj.LibrariesLabelText.Position = obj.LibraryLabelTextPositionBT;
                obj.CheckBoxList.Position = obj.CheckBoxListPositionBT;
            end
        end

        function items = getDeviceList(obj)
            obj.NameLabel.Visible = 'off';
            obj.EnterNameLabel.Visible = 'off';
            obj.DeviceListDropDown.Visible = 'off';
            obj.LibrariesLabelText.Visible = 'off';
            obj.CheckBoxList.Visible = 'off';
            obj.ProgramButton.Visible = 'off';
            bleDeviceList = [];
            % Turn-off no BT radio detected warning as this step isn't
            % customer visible
            originalState =  warning('off','MATLAB:ble:ble:noDeviceFound');
            % get device list
            try
                if ismac % On mac, blelist with service UUID doesnt contains empty name field
                    bleDeviceList = blelist("Services",arduinoio.internal.ArduinoConstants.ServiceUUID);
                else
                    bleDeviceList = blelist;
                end
            catch
                %do nothing
            end
            warning(originalState.state,'MATLAB:ble:ble:noDeviceFound');
            % get default name
            [~,username] = system('whoami');
            username = username(1:end-1);
            if(isempty(username))
                username = 'MyArduino';
            else
                % find if special characters are there in username if so,
                % delete them only allowed to use alphanumeric chars and
                % space and braces
                index= [];
                index = regexp(username,'[^A-Za-z0-9() ]');
                if ~isempty(index)
                    for i=1:numel(index)
                        username = eraseBetween(username,index(i),index(i));
                    end
                end
                username =[username,'Arduino'];
            end
            % create the list of items for the editable dropdown
            if(~isempty(bleDeviceList))
                % Get the address for devices which has no names
                deviceNamesChars = (convertStringsToChars(bleDeviceList.Name'));
                if isa(deviceNamesChars,'char')
                    deviceNamesChars = {deviceNamesChars};
                end
                emptyNameCells = cellfun(@isempty,deviceNamesChars);
                addressNameChars = convertStringsToChars(bleDeviceList.Address(emptyNameCells)');
                deviceNamesChars = [deviceNamesChars(~emptyNameCells) addressNameChars];
                if ~isempty(deviceNamesChars)
                    dupStrIndex = contains(deviceNamesChars,username);
                    dupStr =[];
                    if(any(dupStrIndex))
                        for i=1:numel(dupStrIndex)
                            if(dupStrIndex(i)) % this is the index of duplicate name
                                dupStr = [dupStr deviceNamesChars(i)];
                            end
                        end
                    end
                    if(~isempty(dupStr))
                        sort(dupStr);
                        endVal = char(dupStr(end));
                        endVal = endVal(end);
                        if ~isnan(str2double(endVal))
                            appendVal = char(endVal+1);
                        else
                            appendVal = '1';
                        end
                        username = [username appendVal];
                    end
                    if numel(username) > 29
                        removeChars = numel(username) - 29;
                        username = username(1+removeChars:end);
                    end
                    items = [{username},deviceNamesChars];
                else
                    items = {username};
                end
            else
                items = {username};
            end
            obj.BusyOverlay.Visible = 'off';
            obj.NameLabel.Visible = 'on';
            obj.EnterNameLabel.Visible = 'on';
            obj.DeviceListDropDown.Visible = 'on';
            obj.LibrariesLabelText.Visible = 'on';
            obj.CheckBoxList.Visible = 'on';
            obj.ProgramButton.Visible = 'on';
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
            end
            checkExistingServer(obj);

            function checkedLibraryBox
            % 1 subtracted from event.Indices to get library index in src.Items as first index is select all

            %update the workflow libraries to include the selected
            %library
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

            function uncheckedLibraryBox
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

        function obj = enableDeviceCallback(obj)
            % This function reenables the callback associated to DeviceListDropDown
            obj.DeviceListDropDown.ValueChangedFcn = @obj.selectDeviceCallBack;
        end

        function selectDeviceCallBack(obj,varargin)
            % Disable callback otherwise this will result in recurrsive
            % calls to the same function
            obj.DeviceListDropDown.ValueChangedFcn = [];
            c = onCleanup(@()enableDeviceCallback(obj));
            
            if(ismember(varargin{2}.Value,obj.DeviceListDropDown.Items)) % user selects default name or an existing device to reconfigure
                if(obj.DeviceListDropDown.ValueIndex == 1)
                    obj.DeviceListDropDown.setValue(obj.DeviceListDropDown.Items{obj.DeviceListDropDown.ValueIndex});

                    obj.Workflow.DeviceName = varargin{2}.Value;
                else % User is trying to reconfigure a board, validate name and check the libraries from the library list already on board
                     % check if info already in container if not then get
                     % info
                    if isKey(obj.DeviceInfoMap,varargin{2}.Value)
                        obj.Workflow.DeviceName = varargin{2}.Value;
                        libList = obj.DeviceInfoMap.values({obj.Workflow.DeviceName});
                    else
                        deviceName = retrieveBLEName(obj.Workflow.HWInterface, obj.Workflow.Port);
                        if(~ismember(deviceName,obj.DeviceListDropDown.Items(obj.DeviceListDropDown.ValueIndex)))
                            obj.DeviceListDropDown.ValueIndex = 1;
                            id = 'MATLAB:arduinoio:general:BLEDeviceNameMisMatch';
                            integrateErrorKey(obj.Workflow, id);
                            error(id, message(id).getString);
                        end

                        % use this device name in workflow if the name on board
                        % matched the selected local name
                        obj.DeviceListDropDown.setValue(obj.DeviceListDropDown.Items{obj.DeviceListDropDown.ValueIndex});
                        obj.Workflow.DeviceName = varargin{2}.Value;
                        % get library list from board and check the libraries
                        % that are already present
                        obj.BusyOverlay.show();
                        obj.BusyOverlay.Text =  message('MATLAB:arduinoio:general:DetectingDeviceConfiguration').getString;
                        libList = retrieveBLELibraries(obj.Workflow.HWInterface, obj.Workflow.Port);
                        obj.DeviceInfoMap = containers.Map(obj.Workflow.DeviceName,libList);
                    end
                    libraryList = split(libList,',')';
                    if strcmpi(libraryList,"") %If empty string convert to empty cell array, being handled throughout code for empty Libraries
                        libraryList = {};
                    end
                    availableLibs = listArduinoLibraries;
                    index = contains(availableLibs, libraryList);
                    values = [];
                    for i=1:numel(index)
                        if(index(i)==1)
                            values = [values i];%#ok<AGROW>
                        end
                    end
                    obj.CheckBoxList.ValueIndex = [obj.CheckBoxList.ValueIndex values];
                    obj.BusyOverlay.Visible = 'off';
                end
            else % new device name entered by user
                if(numel(varargin{2}.Value)>29)
                    obj.DeviceListDropDown.ValueIndex = 1;
                    id = 'MATLAB:arduinoio:general:MaxDeviceNameLength';
                    integrateErrorKey(obj.Workflow, id);
                    error(id, message(id).getString);
                end
                if(~isempty(regexp(varargin{2}.Value,'[^A-Za-z0-9() ]',"once")))
                    obj.DeviceListDropDown.ValueIndex = 1;
                    id = 'MATLAB:arduinoio:general:InvalidBLEDeviceName';
                    error(id, message(id).getString);
                end
                obj.Workflow.DeviceName = varargin{2}.Value;
            end
            checkExistingServer(obj);
        end

        function uploadServer(obj, ~, ~)
        %Function that programs the board with Arduino server based on
        %user-selected information
            disableScreen(obj);
            customDisableCheckboxList(obj);
            obj.ProgramProgress.Visible = 'on';
            c = onCleanup(@() cleanup(obj));
            successFlag = false;
           
            obj.ProgramProgress.Indeterminate = true;
            if ismember(obj.Workflow.Board,{'Leonardo','Micro'}) && ismember('Serial',obj.Workflow.Libraries) && (obj.Workflow.ConnectionType ==  matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth)
                id = 'MATLAB:hwsdk:general:notSupportedInterfaceBT';
                integrateErrorKey(obj.Workflow, id);
                error(id, message(id,'Serial',obj.Workflow.Board).getString);
            elseif ~ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.SerialLibrarySupportBoards) && ismember('Serial',obj.Workflow.Libraries)
                id = 'MATLAB:arduinoio:general:notSupportedInterfaceHardwareSetupScreen';
                integrateErrorKey(obj.Workflow, id);
                error(id, message(id,'Serial',obj.Workflow.Board).getString);
            elseif ~ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.RotaryEncoderSupportedBoards) && ismember('RotaryEncoder',obj.Workflow.Libraries)
                id = 'MATLAB:arduinoio:general:notSupportedLibraryHardwareSetupScreen';
                integrateErrorKey(obj.Workflow, id);
                error(id, message(id,'RotaryEncoder',obj.Workflow.Board).getString);
            elseif ~ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.MotorCarrierLibrarySupportedBoards) && ismember('MotorCarrier',obj.Workflow.Libraries)
                id = 'MATLAB:arduinoio:general:unsupportedMCLibrary';
                integrateErrorKey(obj.Workflow, id);
                error(id, message(id, obj.Workflow.Board).getString);
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
                    integrateErrorKey(obj.Workflow, id);
                    error(id, message(id, libPrint).getString);
                end
            end
            obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorPrimary;
            obj.ErrorLabelText.Text =  getString(message('MATLAB:arduinoio:general:programmingArduino', obj.Workflow.Board, obj.Workflow.Port));
            if ~isempty(obj.LogLink)
                obj.LogLink.Visible = 'off';
                delete(obj.LogLink);
                obj.LogLink = [];
            end
            drawnow;

            status = complete3pInstall(obj);
            if status
                obj.ErrorLabelHTMLText.Status= {matlab.hwmgr.internal.hwsetup.StatusIcon.Fail};
                obj.ErrorLabelHTMLText.Steps = {getString(message('MATLAB:arduinoio:general:FailedToInstall3pLibrary'))};
                obj.ErrorLabelText.Visible = 'off';
                obj.ErrorLabelHTMLText.Visible = 'on';
                obj.ProgramProgress.Indeterminate = false;
                obj.ProgramProgress.Visible = 'off';
                obj.Install3pLibCheckBox.Enable = 'off';
                obj.Install3pLibLabelText.Enable = 'off';
                obj.InstallServoESP323pLibCheckBox.Enable = 'off';
                obj.InstallServoESP323pLibLabelText.Enable = 'off';
                return;
            end
            try
                msg = uploadArduinoServer(obj.Workflow.HWInterface,obj.Workflow);
                if ~isempty(msg)
                    obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                    obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:programArduinoFailed'));
                    log(obj.Workflow.Logger, msg);
                    obj.LogLink = matlab.hwmgr.internal.hwsetup.HTMLText.getInstance(obj.ContentPanel);
                    obj.LogLink.Text =  getString(message('MATLAB:arduinoio:general:programLogLinkText',obj.Workflow.LogFileName,obj.Workflow.LogFileName));
                    obj.LogLink.Position =  [20 20 400 25];
                    return;
                end

                if  obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                    obj.ErrorLabelText.Text =  message('MATLAB:arduinoio:general:obtainingBLE').getString;
                    drawnow;
                    bleAddress = retrieveBLEAddress(obj.Workflow.HWInterface, obj.Workflow.Port);
                    if isempty(bleAddress)
                        obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:obtainBLEFailed').getString;
                    else
                        obj.Workflow.DeviceAddress = bleAddress;
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
                checkExistingServer(obj);
                update3pWidgets(obj);
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
                        (~isequal(sort(obj.CurrentServer.Libraries),sort(obj.Workflow.Libraries))) || ...
                        (~isequal(obj.CurrentServer.DeviceName, obj.Workflow.DeviceName))
                    obj.NextButton.Enable = 'off';
                    obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                    obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:reprogramArduinoText').getString;
                else
                    obj.NextButton.Enable = 'on';
                    obj.ErrorLabelText.FontColor =  '--mw-color-success';
                    obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:operationSuccessText').getString;
                end
            end
        end

        function saveServerSettings(obj)
            obj.CurrentServer.Board = obj.Workflow.Board;
            obj.CurrentServer.Port = obj.Workflow.Port;
            obj.CurrentServer.DeviceName = obj.Workflow.DeviceName;
            obj.CurrentServer.Libraries = obj.Workflow.Libraries;
        end

        function saveCurrentSettings(obj)
            obj.PrevConnectionType = obj.Workflow.ConnectionType;
            obj.PrevBoard = obj.Workflow.Board;
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
