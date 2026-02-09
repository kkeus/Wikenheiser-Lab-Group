classdef SelectConnectionScreen < matlab.hwmgr.internal.hwsetup.SelectionWithRadioGroup
    %SELECTCONNECTIONSCREEN The SelectConnectionScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The SelectConnectionScreen is used to allow users to choose the final
    % board and host computer connection type.

    % Copyright 2016-2022 The MathWorks, Inc.

    properties(Access = public)
        % ImageFiles - Cell array of fullpaths to the image files. The
        % number of elements in ImageFiles should be equal to the number of
        % items in the radio group
        ImageFiles = {};
        %NetworkConfigPanel - Panel for all network configuration
        NetworkConfigPanel
        %ReuseConfigCheckboxLabel - Text label for reuse config checkbox
        ReuseConfigCheckboxLabel
        %ReuseConfigCheckbox - Checkbox to reuse existing network configuration
        ReuseConfigCheckbox
        %EncryptionRadioGroup - Radio group for selecting encryption type
        EncryptionRadioGroup
        %KeyEditText - Edit field for Key
        KeyEditText
        %KeyIndexEditText - Edit field for Key Index
        KeyIndexEditText
        %SSIDEditText - Edit field for SSID
        SSIDEditText
        %PasswdEditText - Edit field for password
        PasswdEditText
        %PortEditText - Edit field for TCP/IP port
        PortEditText
        %KeyLabelText - Label that shows specify Key
        KeyLabelText
        %KeyIndexLabelText - Label that shows specify Key Index
        KeyIndexLabelText
        %SSIDLabelText - Label that shows specify ssid text
        SSIDLabelText
        %PasswdLabelText - Label that shows specify password text
        PasswdLabelText
        %PortLabelText - Label that shows specify TCP/IP port text
        PortLabelText
        %StaticIPCheckbox - Checkbox that allows static IP
        StaticIPCheckbox
        %StaticIPEditText - Edit field for static IP address
        StaticIPEditText
        %StaticIPLabelText - Label that shows specify ip address
        StaticIPLabelText
        %BluetoothNoteLabelText - Label that shows Bluetooth connection note
        BluetoothNoteLabelText
        %SelectionRadioDescriptionText - Label that shows connection type note
        SelectionRadioDescriptionText
        %EncryptionRadioDescriptionText - Label that shows WiFi encryption note
        EncryptionRadioDescriptionText
    end
    
    properties(Access = private, Constant = true)
        InitPanelPosition = [20 2 400 150]
        PositionOff = [500 500 30 50]
        FontSize = 13
        NetworkEditFieldsOffset = [0 18 0 0];
        USBBTNotePosition = [20,15,430,40];
    end

    methods(Access = 'public')
        function obj = SelectConnectionScreen(workflow)
            % Validate that only ArduinoWorkflow
            % can access the screen
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.SelectionWithRadioGroup(workflow);
                
            obj.Title.Text = message('MATLAB:arduinoio:general:SelectConnectionScreenTitle').getString;
            obj.Description.Text = message('MATLAB:arduinoio:general:SelectConnectionScreenDescription').getString;
            obj.Description.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            obj.Description.Position = [20 340 430 40];

            
            % Set the ImageFiles property to store all images files to be displayed 
            if strcmpi(computer, 'GLNXA64')
                obj.ImageFiles = {...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_usb_connection.png'),...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_wifi_connection.png')};
            else
                obj.ImageFiles = {...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_usb_connection.png'),...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_bluetooth_connection_Nano33BLE.png'),...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_wifi_connection.png')};
            end

            % create a Label instance to show the connection type note
            obj.SelectionRadioDescriptionText = matlab.hwmgr.internal.hwsetup.Label.getInstance(obj.ContentPanel);
            obj.SelectionRadioDescriptionText.Text = message('MATLAB:arduinoio:general:supportedTypesText').getString;
            obj.SelectionRadioDescriptionText.Position = [20 340 200 20];
            obj.SelectionRadioDescriptionText.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            % Set radio group for type selection
            obj.SelectionRadioGroup.Title =  "";
            obj.SelectionRadioGroup.Items = arduinoio.internal.ArduinoConstants.getSupportedConnectionTypes;
            obj.SelectionRadioGroup.SelectionChangedFcn = @obj.radioSelectCallback;            
            if ispc || ismac
                obj.SelectionRadioGroup.Position = [20 260 200 100];
            else
                obj.SelectionRadioGroup.Position = [20 250 200 100];
            end
            
            % Set up Bluetooth connection note
            obj.BluetoothNoteLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,...
                message('MATLAB:arduinoio:general:SelectConnectionScreenUSBNote').getString, obj.USBBTNotePosition,12);

            if ~ispc && ~ismac
                % Don't show BT note for Linux as BT isn't supported on
                % Linux
                obj.BluetoothNoteLabelText.Visible = 'off';
            end

            % Set up WiFi configuration panel
            obj.NetworkConfigPanel = matlab.hwmgr.internal.hwsetup.Panel.getInstance(obj.ContentPanel);
            obj.NetworkConfigPanel.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            obj.NetworkConfigPanel.Position = obj.InitPanelPosition;
            obj.NetworkConfigPanel.Title = message('MATLAB:arduinoio:general:SelectConnectionScreenEncryptionTitle').getString;
            obj.NetworkConfigPanel.BorderType = 'line';
            obj.NetworkConfigPanel.Visible = 'off';
            % Set up WiFi reuse configuration checkbox
            if ispc||ismac
                 ReuseConfigCheckboxLabelPosition = [40 232 300 40];
                 ReuseConfigCheckboxPosition = [20 254 20 20];
            else
                ReuseConfigCheckboxLabelPosition = [40 240 300 40];
                ReuseConfigCheckboxPosition = [20 260 20 20];
            end
            obj.ReuseConfigCheckboxLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:retrieveIPText').getString, ReuseConfigCheckboxLabelPosition, obj.FontSize);
            obj.ReuseConfigCheckbox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.ContentPanel,'', ReuseConfigCheckboxPosition, @obj.reuseConfigCallback, false);
            obj.ReuseConfigCheckboxLabel.Visible = 'off';
            obj.ReuseConfigCheckbox.Visible = 'off';

            % Set up WiFi encryption radio group         
            types = arduinoio.internal.ArduinoConstants.SupportedEncryptionTypes;
            obj.EncryptionRadioGroup = arduinoio.setup.internal.ScreenHelper.buildRadioGroup(obj.NetworkConfigPanel, ...
                types, message('MATLAB:arduinoio:general:SelectConnectionScreenEncryptionText').getString, [10 35 170 90], @obj.setEncryption, 1);
            % create Label instance to show the Encryption types note
            obj.EncryptionRadioDescriptionText = matlab.hwmgr.internal.hwsetup.Label.getInstance(obj.NetworkConfigPanel);
            obj.EncryptionRadioDescriptionText.Text = message('MATLAB:arduinoio:general:SelectConnectionScreenEncryptionText').getString;
            obj.EncryptionRadioDescriptionText.Position = [10 190 150 20];
            obj.EncryptionRadioDescriptionText.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            % Set the visibility to off once SelectConnectionScreen is constructed
            obj.EncryptionRadioGroup.Visible = 'off';

            % Set up WiFi info edit fields
            obj.SSIDLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'SSID *', [170 100 150 20], obj.FontSize);
            obj.SSIDLabelText.Visible = 'off';
            obj.SSIDEditText = matlab.hwmgr.internal.hwsetup.EditText.getInstance(obj.NetworkConfigPanel);
            obj.SSIDEditText.TextAlignment = 'left';
            obj.SSIDEditText.Position = [260 100 100 20];
            obj.SSIDEditText.Text = '';
            obj.SSIDEditText.ValueChangedFcn = @obj.setSSID;

            % Set up password edit fields
            % PasswdLabelText is visibe only for WPA encryption mode
            obj.PasswdLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'Password *', [170 80 150 20], obj.FontSize);
            obj.PasswdEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '', [260 80 100 20], @obj.setPassword);
            % Set up WiFi key edit fields
            % Visible only for WEP
            obj.KeyLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'Key *', [170 80 150 20], obj.FontSize);
            obj.KeyEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '', [260 80 100 20], @obj.setKey);
            obj.KeyIndexLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'Key Index *', [170 60 150 20], obj.FontSize);
            obj.KeyIndexEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '', [260 60 100 20], @obj.setKeyIndex);
            % Set the visibility to off once SelectConnectionScreen is constructed
            obj.KeyLabelText.Visible = 'off';
            obj.KeyEditText.Visible = 'off';
            obj.KeyIndexLabelText.Visible = 'off';
            obj.KeyIndexEditText.Visible = 'off';
            % Set up port edit fields
            obj.PortLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'Port *', obj.PositionOff, obj.FontSize);
            obj.PortEditText  = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '9500', obj.PositionOff, @obj.setTCPIPPort);
            obj.PortLabelText.Visible = 'off';
            obj.PortEditText.Visible = 'off';
            % Set up static IP edit fields
            obj.StaticIPCheckbox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.NetworkConfigPanel, 'Use static IP address', obj.PositionOff, @obj.staticIPCallback, false);
            obj.StaticIPLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'IP address *', obj.PositionOff, obj.FontSize);
            obj.StaticIPEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '', obj.PositionOff, @obj.setStaticIP);

            obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:SelectConnectionScreenAboutSelection').getString;
            obj.HelpText.WhatToConsider = '';
            % Show default image.
            updateConnectionImage(obj);

            % Disable connection type selection with the right connection type selected,
            % if launched from the Arduino Explorer app.
            % Trigger callback function to show/hide necessary widgets
            % based on the connection type context from the Arduino Explorer app
            if obj.Workflow.LaunchByArduinoExplorer
                connectionIndex = find(ismember(obj.SelectionRadioGroup.Items,...
                    obj.Workflow.ConnectionType));
                obj.SelectionRadioGroup.ValueIndex = connectionIndex;
                obj.SelectionRadioGroup.Enable = "off";
                src.Value = obj.SelectionRadioGroup.Items{obj.SelectionRadioGroup.ValueIndex};
                radioSelectCallback(obj,src);
            end
        end
        
        function  id = getNextScreenID(obj)            
            % If WiFi             
            if obj.Workflow.ConnectionType==matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi 
                if obj.Workflow.SkipProgram
                    id = 'arduinoio.setup.internal.ObtainIPScreen';
                else 
                    if obj.Workflow.UseStaticIP
                        try
                            validateIPAddress(obj.Workflow.HWInterface, obj.StaticIPEditText.Text);
                            obj.Workflow.StaticIP = obj.StaticIPEditText.Text;
                        catch e
                            obj.StaticIPEditText.Text = '';
                            integrateErrorKey(obj.Workflow, e.identifier);
                            throwAsCaller(e);
                        end
                    end
                    checkNetworkSettings(obj);
                    id = 'arduinoio.setup.internal.UpdateServerScreen';
                end
            elseif obj.Workflow.ConnectionType==matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                id = 'arduinoio.setup.internal.BoardSelectionScreen';
            else
                id = 'arduinoio.setup.internal.UpdateServerScreen';
            end
            c = onCleanup(@() integrateData(obj.Workflow, obj.Workflow.ConnectionType));
        end
        
        function show(obj)
            %Overwrite show method to hide Back button if entered with
            %arduinosetup
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj)
            if obj.Workflow.LaunchByArduinoSetup || obj.Workflow.LaunchByArduinoExplorer
                obj.BackButton.Visible = 'off';
            end
        end
    end

    %% Widget callback methods
    methods(Access = private)
        function radioSelectCallback(obj, src, ~)
            %Function that is invoked when a radio button is selected. This 
            %function updates the selection.
            % Turn off the visibility of connection type images
            obj.SelectedImage.Visible = 'off';
            switch src.Value
                case 'USB'
                    obj.Workflow.ConnectionType = matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial;
                    if ispc||ismac % only show Bluetooth verbiage on Windows and Mac
                        showBluetoothNote(obj);
                    end
                    hideNetworkSettings(obj);
                    obj.HelpText.WhatToConsider = '';
                    obj.NextButton.Enable = 'on';
                case 'Bluetooth®'
                    obj.Workflow.ConnectionType = matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth;
                    showBluetoothNote(obj);
                    hideNetworkSettings(obj);
                    obj.HelpText.WhatToConsider = '';
                case 'WiFi'
                    obj.Workflow.ConnectionType = matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi;
                    hideBluetoothNote(obj);
                    showNetworkSettings(obj);
                    if obj.ReuseConfigCheckbox.Value
                        disable(obj.NetworkConfigPanel);
                    end
                    obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:SelectConnectionScreenWhatToConsider').getString;
                    obj.NextButton.Enable = 'on';
            end
            updateConnectionImage(obj);
        end
        
        function updateConnectionImage(obj)
            %Function that updates the image displayed on the screen based
            %on selected connection type
            % Turn off the visibility of connection type images
            obj.SelectedImage.Visible = 'off';
            switch obj.Workflow.ConnectionType
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                    obj.SelectedImage.Position = [20 85 430 215];
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                    obj.SelectedImage.Position = [20 50 430 230];
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                    obj.SelectedImage.Position = [20 65 430 215];
            end
            file = obj.ImageFiles{obj.SelectionRadioGroup.ValueIndex};
            obj.SelectedImage.ImageFile = file;
            % Turn on the visibility of connection type images
            obj.SelectedImage.Visible = 'on';
        end
        
        function reuseConfigCallback(obj, src, ~)
            %Function that updates network settings display
            if src.Value % reuse configuration
                disable(obj.NetworkConfigPanel);
            else % specify new configuration
                enable(obj.NetworkConfigPanel);
            end
            obj.Workflow.SkipProgram = src.Value;
        end
        
        function staticIPCallback(obj, src, ~)
            %Function that shows/hides static ip address edit text
            if src.Value
                obj.Workflow.UseStaticIP = true;
                updateStaticIPSettings(obj);
            else
                obj.Workflow.UseStaticIP = false;
                obj.StaticIPEditText.Position = obj.PositionOff;
                obj.StaticIPLabelText.Position = obj.PositionOff;
                obj.StaticIPEditText.Visible = 'off';
                obj.StaticIPLabelText.Visible = 'off';
            end
        end
        
        function setEncryption(obj, src, ~)
            %Function that updates the encryption type
            switch src.Value
                case 'None'
                    obj.Workflow.Encryption = matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.None;
                case 'WPA/WPA2'
                    obj.Workflow.Encryption = matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WPA;
                case 'WEP'
                    obj.Workflow.Encryption = matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WEP;
            end
            updateStaticIPSettings(obj);
            showNetworkEditFields(obj);
        end
        
        function setSSID(obj, src, ~)
            %Function that sets the SSID to user specified value
            obj.Workflow.SSID = src.Text;
        end
        
        function setPassword(obj, src, ~)
            %Function that sets the password to user specified value
            obj.Workflow.Password = src.Text;
        end
        
        function setKey(obj, src, ~)
            %Function that sets the Key to user specified value
            try
                validateKey(obj.Workflow.HWInterface, src.Text);
                obj.Workflow.Key = src.Text;
            catch e
                obj.KeyEditText.Text = '';
                integrateErrorKey(obj.Workflow, e.identifier);
                throwAsCaller(e);
            end
        end
        
        function setKeyIndex(obj, src, ~)
            %Function that sets the KeyIndex to user specified value
            try
                validateKeyIndex(obj.Workflow.HWInterface, src.Text);
                obj.Workflow.KeyIndex = src.Text;
            catch e
                obj.KeyIndexEditText.Text = '';
                integrateErrorKey(obj.Workflow, e.identifier);
                throwAsCaller(e);
            end
        end
        
        function setTCPIPPort(obj, src, ~)
            %Function that sets the TCPIP port to default/user specified
            %value
            % If user clears the field, it will reset the value to 9500
            if isempty(src.Text)
                port = arduinoio.internal.ArduinoConstants.DefaultTCPIPPort;
                obj.PortEditText.Text = num2str(port);
                obj.Workflow.TCPIPPort = port;
            else
                try
                    value = str2double(src.Text);
                    validateTCPIPPort(obj.Workflow.HWInterface, value);
                    obj.Workflow.TCPIPPort = value;
                catch e
                    obj.PortEditText.Text = '9500';
                    integrateErrorKey(obj.Workflow, e.identifier);
                    throwAsCaller(e);
                end
            end
        end
        
        function setStaticIP(obj, src, ~)
            %Function that sets the static ip address
            try
                validateIPAddress(obj.Workflow.HWInterface, src.Text);
                obj.Workflow.StaticIP = src.Text;
            catch e
                obj.StaticIPEditText.Text = '';
                integrateErrorKey(obj.Workflow, e.identifier);
                throwAsCaller(e);
            end
        end
    end
    
    %% Methods for building/removing/hiding/showing widgets
    methods(Access = 'private')   
        function showBluetoothNote(obj)
            %Function that shows Bluetooth connection note
			if obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
				obj.BluetoothNoteLabelText.Text = message('MATLAB:arduinoio:general:SelectConnectionScreenUSBNote').getString;
            elseif obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
				obj.BluetoothNoteLabelText.Text = message('MATLAB:arduinoio:general:SelectConnectionScreenBTNote').getString;
            end
            obj.BluetoothNoteLabelText.Visible = 'on';
        end
        
        function hideBluetoothNote(obj)
            %Function that hides Bluetooth connection note 
            obj.BluetoothNoteLabelText.Visible = 'off';
        end
        
        function hideNetworkEditFields(obj)
            %Function that hides all edit fields 
            obj.KeyLabelText.Visible = 'off';
            obj.KeyEditText.Visible = 'off';
            obj.KeyIndexLabelText.Visible = 'off';
            obj.KeyIndexEditText.Visible = 'off';
            obj.SSIDEditText.Visible = 'off';
            obj.SSIDLabelText.Visible = 'off';
            obj.PasswdEditText.Visible = 'off';
            obj.PasswdLabelText.Visible = 'off';
            obj.PortLabelText.Visible = 'off';
            obj.PortEditText.Visible = 'off';
        end
        
        function showNetworkEditFields(obj)
            %Function that updates all edit fields positions
            % Turn off the visibility of KeyLabelText, KeyEditText,
            % KeyIndexLabelText and KeyIndexEditText widgets
            % This is required when switching between encryption modes
            % since it is only enabled under WEP mode and
            % hideNetworkEditFields is only called upon selection of either
            % USB or Bluetooth
            obj.KeyLabelText.Visible = 'off';
            obj.KeyEditText.Visible = 'off';
            obj.KeyIndexLabelText.Visible = 'off';
            obj.KeyIndexEditText.Visible = 'off';

            % Set the positions for the port label and edit texts
            PortLabelTextWPAPosition = [170 60 150 20];
            PortEditTextWPAPosition = [260 60 100 20];

            % Turn off the visibility of PortLabelText and PortEditText
            % widgets
            obj.PortLabelText.Visible = 'off';
            obj.PortEditText.Visible = 'off';

            % Turn off the visibility of PasswdEditText and PasswdLabelText
            % widgets
            obj.PasswdEditText.Visible = 'off';
            obj.PasswdLabelText.Visible = 'off';
            switch obj.Workflow.Encryption
                case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.None
                    PortLabelTextPosition = PortLabelTextWPAPosition + obj.NetworkEditFieldsOffset;
                    PortEditTextPosition = PortEditTextWPAPosition + obj.NetworkEditFieldsOffset;
                case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WPA
                    PortLabelTextPosition = PortLabelTextWPAPosition;
                    PortEditTextPosition = PortEditTextWPAPosition;
                    obj.PasswdEditText.Visible = 'on';
                    obj.PasswdLabelText.Visible = 'on';
                case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WEP
                    obj.KeyLabelText.Visible = 'on';
                    obj.KeyEditText.Visible = 'on';
                    obj.KeyIndexLabelText.Visible = 'on';
                    obj.KeyIndexEditText.Visible = 'on';
                    PortLabelTextPosition = PortLabelTextWPAPosition - obj.NetworkEditFieldsOffset;
                    PortEditTextPosition = PortEditTextWPAPosition - obj.NetworkEditFieldsOffset;
            end

            obj.PortLabelText.Position = PortLabelTextPosition;
            obj.PortEditText.Position = PortEditTextPosition;

            % After setting the widget positions, turn off the visibility of PortLabelText and PortEditText
            % widgets
            obj.PortLabelText.Visible = 'on';
            obj.PortEditText.Visible = 'on';

            % Turn on the visibility of SSIDLabelText and SSIDEditText
            % widgets
            obj.SSIDLabelText.Visible = 'on';
            obj.SSIDEditText.Visible = 'on';
        end
        
        function updateStaticIPSettings(obj)
            %Function that updates the static ip checkbox/label/edit text
            %position based on encryption type
            if ~isempty(obj.StaticIPCheckbox)
               obj.StaticIPCheckbox.Visible = 'off';
               obj.StaticIPLabelText.Visible = 'off';
               obj.StaticIPEditText.Visible = 'off';
                switch obj.Workflow.Encryption
                    case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WPA
                        obj.StaticIPCheckbox.Position = [10 10 150 25];
                    case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WEP
                        obj.StaticIPCheckbox.Position = [10 10 150 25];
                    case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.None
                        obj.StaticIPCheckbox.Position = [10 10 150 25];
                end
                if obj.StaticIPCheckbox.Value
                    obj.StaticIPLabelText.Position = [170 13 80 18];
                    obj.StaticIPEditText.Position = [260 13 110 obj.StaticIPLabelText.Position(4)];
                end
                obj.StaticIPCheckbox.Visible = 'on';
                obj.StaticIPLabelText.Visible = 'on';
                obj.StaticIPEditText.Visible = 'on';
            end
        end
        
        function showNetworkSettings(obj)
            %Function that creates/shows all additional widgets for WiFi
            %settings
            obj.NetworkConfigPanel.Position = obj.InitPanelPosition;
            obj.NetworkConfigPanel.Visible = 'on';
            obj.ReuseConfigCheckboxLabel.Visible = 'on';
            obj.ReuseConfigCheckbox.Visible = 'on';
            obj.EncryptionRadioGroup.Visible = 'on';
            obj.EncryptionRadioDescriptionText.Visible = 'on';
            showNetworkEditFields(obj);
            updateStaticIPSettings(obj);
        end
        
        function hideNetworkSettings(obj)
            %Function that hides reuse checkbox and radio group and
            %dynamic edit fields 
            %Due to the complexity and the multiple widgets are involved,
            %hiding the widgets by positioning them off the screen is used
            %instead of the usual creating/deleting widgets dynamically.
            if ~isempty(obj.NetworkConfigPanel)
                obj.NetworkConfigPanel.Visible = 'off';
                obj.ReuseConfigCheckboxLabel.Visible = 'off';
                obj.ReuseConfigCheckbox.Visible = 'off';
                obj.EncryptionRadioGroup.Visible = 'off';
                obj.EncryptionRadioDescriptionText.Visible = 'off';
                hideNetworkEditFields(obj);
                obj.StaticIPCheckbox.Visible = 'off';
                obj.StaticIPEditText.Visible = 'off';
                obj.StaticIPLabelText.Visible = 'off';
            end
        end
        
        function checkNetworkSettings(obj)
            try
                validateNetworkSettings(obj.Workflow.HWInterface, obj.Workflow);
            catch e
                integrateErrorKey(obj.Workflow, e.identifier);
                throwAsCaller(e);
            end
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
