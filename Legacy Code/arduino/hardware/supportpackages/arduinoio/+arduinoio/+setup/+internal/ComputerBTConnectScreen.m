classdef ComputerBTConnectScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %COMPUTERBTCONNECTSCREEN The ComputerBTConnectScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The ComputerBTConnectScreen is used to show users how to connect
    % Bluetooth device to host computer for configuration.
    
    % Copyright 2016-2018 The MathWorks, Inc.

    properties(SetAccess = private, GetAccess = public)
        % Image - Example image showing how to connect Bluetooth device to
        % Arduino
        Image
        TextLabel
        NoteLabel
    end
    
    properties(Access = private, Constant = true)
        FontSize = 10
        DefaultImage = 'arduino_hc0506_ftdi.png'
    end
    
    methods(Access = 'public')
        function obj = ComputerBTConnectScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:ComputerBTConnectScreenTitle').getString;
            
            % Set content text
            obj.TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:ComputerBTConnectScreenDescription').getString, [20 330 430 40], obj.FontSize);
            updateNote(obj);
            
            % Set Image to show connection
            obj.Image = matlab.hwmgr.internal.hwsetup.Image.getInstance(obj.ContentPanel);
            obj.Image.ImageFile = fullfile(obj.Workflow.ResourcesDir, obj.DefaultImage);
            obj.Image.Position = [30 80 430 190];
            obj.Image.Visible = 'on';
             
            obj.HelpText.AboutSelection = '';
            obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:ComputerBTConnectScreenWhatToConsider').getString;
        end

        function id = getPreviousScreenID(~)
            id = 'arduinoio.setup.internal.SelectBTDeviceScreen';
        end
        
        function  id = getNextScreenID(~)
            id = 'arduinoio.setup.internal.ConfigureBTScreen';
        end
        
        function reinit(obj)
            updateNote(obj);
        end
    end
    
    methods(Access = private)
        function updateNote(obj)
            %Function that only shows additional note text if device is 
            %HC-05.
            if obj.Workflow.BluetoothDevice == matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05
                if isempty(obj.NoteLabel)
                    obj.NoteLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,...
                        message('MATLAB:arduinoio:general:ComputerBTConnectScreenHC05Text').getString, [20 280 430 50], obj.FontSize);
                    obj.NoteLabel.FontWeight = 'bold';
                end
            else
                if ~isempty(obj.NoteLabel)
                    obj.NoteLabel.Visible = 'off';
                    delete(obj.NoteLabel);
                    obj.NoteLabel = [];
                end
            end
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
