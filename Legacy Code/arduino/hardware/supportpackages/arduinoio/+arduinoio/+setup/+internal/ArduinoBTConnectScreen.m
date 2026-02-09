classdef ArduinoBTConnectScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %ARDUINOBTCONNECTSCREEN The ArduinoBTConnectScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The ArduinoBTConnectScreen is used to show users how to connect
    % Bluetooth device to Arduino.
    
    % Copyright 2016-2018 The MathWorks, Inc.

    properties(SetAccess = private, GetAccess = public)
        DescriptionText
        % Image - Example image showing how to connect Bluetooth device to
        % Arduino
        Image
    end
    
    properties(Access = private, Constant = true)
        FontSize = 10
    end

    methods(Access = 'public')
        function obj = ArduinoBTConnectScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:ArduinoBTConnectScreenTitle').getString;
            
            obj.DescriptionText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:ArduinoBTConnectScreenDescription').getString,[20 330 430 40],obj.FontSize);
            
            % Set Image to show connection
            obj.Image = matlab.hwmgr.internal.hwsetup.Image.getInstance(obj.ContentPanel);
            updateScreen(obj);
            
            obj.HelpText.AboutSelection = '';
        end

        function id = getPreviousScreenID(obj)
            if obj.Workflow.SkipConfigure
                id = 'arduinoio.setup.internal.SelectBTDeviceScreen';
            else
                id = 'arduinoio.setup.internal.ConfigureBTScreen';
            end
        end
        
        function  id = getNextScreenID(~)
            id = 'arduinoio.setup.internal.PairBTScreen';
        end
        
        function reinit(obj)
            updateScreen(obj);
        end
    end
    
    methods(Access = private)
        function updateScreen(obj)
            obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:ArduinoBTConnectScreenWhatToConsider').getString;
            if strcmpi(obj.Workflow.Board,'Due')
                file = 'arduino_bluetooth_connect_hc0506_due.png';
                obj.Image.Position = [20 70 460 260];
            else
                file = 'arduino_bluetooth_connect_hc0506.png';
                obj.Image.Position = [20 70 460 260];
            end
            obj.Image.ImageFile = fullfile(obj.Workflow.ResourcesDir, file);
            obj.Image.Visible = 'on';
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
