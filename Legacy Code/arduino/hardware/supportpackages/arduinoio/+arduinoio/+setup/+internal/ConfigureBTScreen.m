classdef ConfigureBTScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %CONFIGUREBTSCREEN The ConfigureBTScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    %The ConfigureBTScreen is used to show users how to connect
    %Bluetooth device to host computer for configuration.
    
    % Copyright 2016-2022 The MathWorks, Inc.
    
    properties(Access = public)
        % Main content text
        DescriptionTextLabel
        % Serial port text label
        PortTextLabel
        % Configure text label, progress bar and button
        ConfigureLabelText
        ConfigureProgress
        ConfigureButton
        ConfigureFailureText
        % Port dropdown menu
        PortDropDown
        % Configure result status table
        StatusTable
        % Bluetooth serial settings
        Port
        % BluetoothDevice saved before leaving the screen
        PrevBluetoothDevice
        DocLink
    end
    
    properties(Access = private, Constant = true)
        FontSize = 13;
    end
    
    methods(Access = 'public')
        function obj = ConfigureBTScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:ConfigureBTScreenTitle').getString;
            
            obj.PortTextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:chooseDevicePortText').getString, [20 350 150 20], obj.FontSize);
            
            %Set up the dropdown menu to select port
            obj.Port = 'select a value';
            startPosition = obj.PortTextLabel.Position(1);
            
            obj.PortDropDown = arduinoio.setup.internal.ScreenHelper.buildDropDown(obj.ContentPanel,...
                {'dummy'}, [startPosition obj.PortTextLabel.Position(2)-20 110 20], @obj.updatePort, 1);
            if ~ispc
                addWidth(obj.PortDropDown, 70);
            end
            updatePortDropdown(obj);
            obj.DocLink =  matlab.hwmgr.internal.hwsetup.HTMLText.getInstance(obj.ContentPanel);
            obj.DocLink.Position = [150 343 200 25];
            obj.DocLink.Text = message('MATLAB:arduinoio:general:ConfigureBTScreenDocLinkText').getString;
            
            %Set up button to send AT command to configure Bluetooth device
            obj.ConfigureLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:ConfigureBTScreenButtonText').getString, [20 280 430 20], obj.FontSize);
            obj.ConfigureProgress = matlab.hwmgr.internal.hwsetup.ProgressBar.getInstance(obj.ContentPanel);
            obj.ConfigureProgress.Position = [150 255 280 22];
            obj.ConfigureButton = arduinoio.setup.internal.ScreenHelper.buildButton(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:configureButtonText').getString, [20 255 100 23], @obj.configureDevice);
            
            updateAboutSelection(obj);
            obj.HelpText.WhatToConsider = '';
            obj.NextButton.Enable = 'off';
        end
        
        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.ComputerBTConnectScreen';
            obj.PrevBluetoothDevice = obj.Workflow.BluetoothDevice;
        end
        
        function  id = getNextScreenID(obj)
            id = 'arduinoio.setup.internal.ArduinoBTConnectScreen';
            obj.PrevBluetoothDevice = obj.Workflow.BluetoothDevice;
            c = onCleanup(@() integrateData(obj.Workflow, obj.Workflow.Board));
        end
        
        function reinit(obj)
            clearResult(obj);
            updatePortDropdown(obj);
            updateAboutSelection(obj);
            if obj.PrevBluetoothDevice~=obj.Workflow.BluetoothDevice
                obj.NextButton.Enable = 'off';
            end
        end
    end
    
    methods(Access = private)
        function configureDevice(obj, ~, ~)
            if strcmpi(obj.PortDropDown.Value, 'select a value')
                id = 'MATLAB:arduinoio:general:noSerialPort';
                integrateErrorKey(obj.Workflow, id);
                error(id, message(id).getString);
            end
            % Clear last result on screen
            clearResult(obj);
            
            % Create new status table
            obj.StatusTable = matlab.hwmgr.internal.hwsetup.StatusTable.getInstance(obj.ContentPanel);
            obj.StatusTable.Visible = 'off';
            obj.StatusTable.Steps = getBTConfigureSteps(obj.Workflow.HWInterface, obj.Workflow.BluetoothDevice);
            obj.StatusTable.Position = [20 150 240 80];
            obj.StatusTable.Status = repmat({matlab.hwmgr.internal.hwsetup.StatusIcon.Busy}, 1, numel(obj.StatusTable.Steps));
            obj.StatusTable.ColumnWidth = [20 356];
            
            disableScreen(obj);
            c = onCleanup(@() cleanup(obj));
            obj.ConfigureProgress.Indeterminate = true;
            result = false;
            drawnow;
            
            % All Bluetooth supported Arduino boards use 115200 baud
            % rate for serial
            result = configureBTDevice(obj.Workflow.HWInterface, obj.Workflow.BluetoothDevice, obj.Port, obj.Workflow.Board);
            if result
                obj.StatusTable.Visible = 'on';
                obj.StatusTable.Status = repmat({matlab.hwmgr.internal.hwsetup.StatusIcon.Pass},1,numel(obj.StatusTable.Steps));
                obj.NextButton.Enable = 'on';
            else
                obj.ConfigureFailureText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                    message('MATLAB:arduinoio:general:ConfigureBTScreenFailureText').getString, [20 210 430 40], obj.FontSize);
                obj.ConfigureFailureText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                obj.ConfigureFailureText.Visible = 'on';
                obj.NextButton.Enable = 'off';
            end
            
            function cleanup(obj)
                enableScreen(obj);
                try
                    obj.ConfigureProgress.Indeterminate = false;
                    if result
                        obj.NextButton.Enable = 'on';
                    else
                        obj.NextButton.Enable = 'off';
                    end
                    drawnow;
                catch
                end
            end
        end
        
        function clearResult(obj)
            % Destroy existing status table
            if ~isempty(obj.StatusTable)
                obj.StatusTable.Visible = 'off';
                delete(obj.StatusTable)
                obj.StatusTable = [];
            end
            % Destroy existing failure text label
            if ~isempty(obj.ConfigureFailureText)
                obj.ConfigureFailureText.Visible = 'off';
                delete(obj.ConfigureFailureText)
                obj.ConfigureFailureText = [];
            end
        end
        
        function updateAboutSelection(obj)
            obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:ConfigureBTScreenAboutSelection').getString;
        end
        
        function updatePort(obj, src, ~)
            obj.Port = src.Value;
        end
        
        function updatePortDropdown(obj)
            %Helper function that shows the correct set of ports at current
            %screen
            [availablePorts, index] = getAvailableArduinoPorts(obj.Workflow.HWInterface, obj.Port);
            obj.PortDropDown.Items = availablePorts;
            obj.PortDropDown.ValueIndex = index;
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
