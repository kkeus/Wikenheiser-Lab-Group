classdef SelectBTDeviceScreen < matlab.hwmgr.internal.hwsetup.SelectionWithRadioGroup
    %SELECTBTDEVICESCREEN The SelectBTDeviceScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The SelectBTDeviceScreen is used to allow users to choose the
    % Bluetooth device for use with Arduino to communicate with host
    % computer wirelessly.

    % Copyright 2016-2022 The MathWorks, Inc.

    properties(Access = public)
        % ContentText - Label that contains the main content text
        ContentText
        % ImageFiles - Cell array of fullpaths to the image files. The
        % number of elements in ImageFiles should be equal to the number of
        % items in the radio group
        ImageFiles = {};
        % Radiogroup indicates whether device has been configured
        HasConfiguredRadioGroup
        % Saved Arduino board selected before leaving the screen
        CurrentArduinoBoard
        BluetoothNoteLabelText
    end
    
    methods(Access = 'public')
        function obj = SelectBTDeviceScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.SelectionWithRadioGroup(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:SelectBTScreenTitle').getString;
            obj.Description.Text = message('MATLAB:arduinoio:general:SelectBTScreenDescription').getString;
            obj.Description.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            
            % Set radio group for type selection
            obj.SelectionRadioGroup.Title = message('MATLAB:arduinoio:general:supportedDevicesText').getString;
            obj.SelectionRadioGroup.Items = arduinoio.internal.ArduinoConstants.getSupportedBTDevices;
            obj.SelectionRadioGroup.SelectionChangedFcn = @obj.radioSelectCallback; 
            obj.SelectionRadioGroup.Visible = 'on';
            % Keep 20 pixels space between the Description text and Radio
            % Buttons
            obj.SelectionRadioGroup.shiftVertically(-20);
            % Increase the height of the RadioGroup panel since the number
            % of items (4) are greater than default number of items (3)
            obj.SelectionRadioGroup.addHeight(20);
            % Set SelectedImage Properties
            obj.SelectedImage.ImageFile = '';
            
            % Set the ImageFiles property to update the image when the Item 
            % in the radio group changes
            keyset = arduinoio.internal.ArduinoConstants.SupportedBTDevices;
            valueset = {fullfile(obj.Workflow.ResourcesDir, 'arduino_bluetooth_hc05.png'),...
                        fullfile(obj.Workflow.ResourcesDir, 'arduino_bluetooth_hc06.png')};
            obj.ImageFiles = containers.Map(keyset, valueset);
            buildRadioGroup(obj);
            % Show default image.
            updateDeviceImage(obj);
        end

        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.UpdateServerScreenBLE';
            obj.CurrentArduinoBoard = obj.Workflow.Board;
        end
        
        function  id = getNextScreenID(obj)
            % Jump to pairing screen if Adafruit selected or user has
            % already configured the other two devices
            if obj.Workflow.SkipConfigure
                id = 'arduinoio.setup.internal.ArduinoBTConnectScreen';
            else
                id = 'arduinoio.setup.internal.ComputerBTConnectScreen';
            end
            obj.CurrentArduinoBoard = obj.Workflow.Board;
            c = onCleanup(@() integrateData(obj.Workflow, obj.CurrentArduinoBoard, char(obj.Workflow.BluetoothDevice), obj.HasConfiguredRadioGroup.Value));
        end
        
        function reinit(obj)
            if ~strcmp(obj.CurrentArduinoBoard, obj.Workflow.Board)
                obj.SelectionRadioGroup.Items = arduinoio.internal.ArduinoConstants.getSupportedBTDevices;
                obj.SelectionRadioGroup.ValueIndex = 1;
                buildRadioGroup(obj);
                updateDeviceImage(obj);
            end
        end
    end

    methods(Access = 'private')
        function radioSelectCallback(obj, src, ~)
            %Function that is invoked when a radio button is selected. This 
            %function updates the selection.
            
            %Clear bluetooth note
            if ~isempty(obj.BluetoothNoteLabelText)
                obj.BluetoothNoteLabelText.Visible='off';
                delete(obj.BluetoothNoteLabelText);
                obj.BluetoothNoteLabelText=[];
            end
            
            obj.NextButton.Enable = 'on';
            switch src.Value
                case 'HC-05'
                    obj.Workflow.BluetoothDevice = matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05;
                    buildRadioGroup(obj);
                case 'HC-06'
                    obj.Workflow.BluetoothDevice = matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC06;
                    buildRadioGroup(obj);
            end
            updateDeviceImage(obj);
        end
        
        function updateDeviceImage(obj) 
            %Function that updates the image displayed on the screen based
            %on selected connection type
            switch obj.Workflow.BluetoothDevice
                case matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05
                    position = [20 40 315 130];
                case matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC06
                    position = [20 30 350 138];
            end
            obj.SelectedImage.Position = position;
            obj.SelectedImage.Visible = 'on';
            file = obj.ImageFiles(obj.SelectionRadioGroup.Value);
            obj.SelectedImage.ImageFile = file;
        end
        
        function hideRadioGroup(obj)
            %Function that destroys the existing dynamic radiogroup
            if ~isempty(obj.HasConfiguredRadioGroup)
                obj.HasConfiguredRadioGroup.Visible = 'off';
                delete(obj.HasConfiguredRadioGroup);
                obj.HasConfiguredRadioGroup = [];
            end
        end
        
        function buildRadioGroup(obj)
            %Function that creates the dynamic radiogroup asking whether
            %the Bluetooth device has been configured before
            % Destroy radiogroup first 
            hideRadioGroup(obj);
            % Reconstruct radiogroup
            if obj.Workflow.SkipConfigure
                index = 1;
                obj.HelpText.AboutSelection = '';
            else
                index = 2;
                obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:SelectBTScreenAboutSelectionHC0506').getString;
            end
            obj.HasConfiguredRadioGroup = arduinoio.setup.internal.ScreenHelper.buildRadioGroup(obj.ContentPanel,...
                {message('MATLAB:arduinoio:general:yesText').getString, message('MATLAB:arduinoio:general:noText').getString}, ...
                message('MATLAB:arduinoio:general:skipConfigureText').getString, [20 150 445 80], @obj.updateSkipConfigFlag, index);
            obj.HasConfiguredRadioGroup.Visible = 'on';
        end
        
        function updateSkipConfigFlag(obj, src, ~)
            %Function that updates the SkipSetup flag to indicate
            %whether to skip board setup or not in the workflow
            if strcmpi(src.Value,'Yes')
                obj.Workflow.SkipConfigure = true;
                obj.HelpText.AboutSelection = '';
            else
                obj.Workflow.SkipConfigure = false;
                obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:SelectBTScreenAboutSelectionHC0506').getString;
            end
        end
    end

end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
