classdef PairBTScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %PAIRBTSCREEN The PairBTScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The PairBTScreen is used to show users how to pair the Bluetooth
    % device with their host computer
    
    % Copyright 2016-2022 The MathWorks, Inc.
    
    properties(Access = public)
        % HelpText for Doc link
        DocLink1
        DocLink2
        % Text label that contains information for pairing instructions
        PairStep1TextLabel
        PairStep2TextLabel
        PairStep3TextLabel
        PairStep4TextLabel
        % Dropdown that selects the Bluetooth serial port
        PortDropDown
        % Button that repopulates the port lists
        RefreshButton
        % Edit text that indicates entering device address
        AddressEditText
        % Bluetooth device stored when leaving the screen
        CurrentBluetoothDevice
    end
    
    properties(Access = private, Constant = true)
        FontSize = 13
    end
    
    methods(Access = 'public')
        function obj = PairBTScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:PairBTScreenTitle').getString;
            
            % Set step text labels
            obj.PairStep1TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,...
                message('MATLAB:arduinoio:general:PairBTStep1Text').getString,[20 330 430 45],obj.FontSize);
            link1 = message('MATLAB:arduinoio:general:PairBTScreenDocLink1Text').getString;
            link2 = message('MATLAB:arduinoio:general:PairBTScreenDocLink2Text').getString;
            if ispc
                link1 = replace(link1, 'DOCLINK','bluetooth_pair_windows');
                link2 = replace(link2, 'DOCLINK','bluetooth_address_windows');
            elseif ismac
                link1 = replace(link1, 'DOCLINK','bluetooth_pair_mac');
                link2 = replace(link2, 'DOCLINK','bluetooth_address_mac');
            end
            obj.PairStep2TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,'',[20 300 430 20],obj.FontSize);
            obj.DocLink1 =  matlab.hwmgr.internal.hwsetup.HTMLText.getInstance(obj.ContentPanel);
            obj.DocLink1.Position = [20 270 430 25];
            obj.DocLink1.Text = link1;
            obj.PairStep3TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,'',[20 230 430 20],obj.FontSize);
            obj.DocLink2 =  matlab.hwmgr.internal.hwsetup.HTMLText.getInstance(obj.ContentPanel);
            obj.DocLink2.Position = [20 200 430 25];
            obj.DocLink2.Text = link2;
            obj.PairStep4TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,'',[20 160 430 20],obj.FontSize);
            updateScreenSteps(obj);
            
            obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:PairBTScreenWhatToConsider').getString;
            obj.HelpText.AboutSelection = '';
        end
        
        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.ArduinoBTConnectScreen';
            obj.CurrentBluetoothDevice = obj.Workflow.BluetoothDevice;
        end
        
        function  id = getNextScreenID(obj)           
            if any(obj.Workflow.BluetoothDevice==[matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05,...
                    matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC06])
                try
                    validateBTAddress(obj.Workflow.HWInterface, obj.AddressEditText.Text);
                catch e
                    integrateErrorKey(obj.Workflow, e.identifier);
                    throwAsCaller(e);
                end
                obj.Workflow.DeviceAddress = strcat('btspp://', obj.AddressEditText.Text);
            end
            id = 'arduinoio.setup.internal.TestConnectionScreen';
            obj.CurrentBluetoothDevice = obj.Workflow.BluetoothDevice;
            c = onCleanup(@() integrateData(obj.Workflow, obj.Workflow.Board));
        end
        
        function reinit(obj)
            % if Bluetooth device changes, empty the address field and
            % disable next button
            if obj.CurrentBluetoothDevice ~= obj.Workflow.BluetoothDevice
                updateScreenSteps(obj);
            end
        end
    end
    
    methods(Access = 'private')
        function updateScreenSteps(obj)
            %Helper function that updates the steps to pair the device
            %based on the currently selected bluetooth device and OS
            if ~isempty(obj.PortDropDown)
                delete(obj.PortDropDown);
                obj.PortDropDown = [];
                delete(obj.RefreshButton);
                obj.RefreshButton = [];
            end
            if ~isempty(obj.AddressEditText)
                delete(obj.AddressEditText);
                obj.AddressEditText = [];
            end
            
            id1 = 'MATLAB:arduinoio:general:PairBTStep2HC0506Text';
            id2 = 'MATLAB:arduinoio:general:PairBTStep3HC0506Text';
            id3 = 'MATLAB:arduinoio:general:PairBTStep4HC0506Text';
            
            obj.PairStep2TextLabel.Text =  message(id1).getString;
            obj.PairStep3TextLabel.Text =  message(id2).getString;
            obj.PairStep4TextLabel.Text =  message(id3).getString;
            % Set Edit field to ask for Bluetooth address or name
            pos = [270, 160, 110, 20];
            obj.AddressEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.ContentPanel, '', pos, @obj.dummyCallback);
        end
        
        function updatePort(obj, src, ~)
            %Callback function for port dropdown
            obj.Workflow.BluetoothSerialPort = src.Value;
            if strcmp(src.Value, 'None')
                obj.NextButton.Enable = 'off';
            else
                obj.NextButton.Enable = 'on';
            end
        end
        
        function updatePortDropdown(obj, ~, ~)
            %Helper function that shows the correct set of ports at current
            %screen
            obj.PortDropDown.Items = getAvailableSerialPorts(obj.Workflow.HWInterface);
            obj.PortDropDown.ValueIndex = 1;
        end
        
        function dummyCallback(~, ~, ~)
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
