classdef ConnectBoardScreen < matlab.hwmgr.internal.hwsetup.ManualConfiguration
    %CONNECTBOARDSCREEN Setup screen directing Arduino user to connect
    %their device in MATLAB Online

    % Copyright 2023 The MathWorks, Inc.
    
    properties(Constant, Access = private)
        TitleText = message("MATLAB:arduinoio:general:OnlineBoardConnectTitle").string
        DescriptionText = message("MATLAB:arduinoio:general:OnlineBoardConnectDescription").string
        AboutSelectionText = message("MATLAB:arduinoio:general:OnlineBoardConnectAboutText").string
    end

    properties(Access = private)
        ImageSource (1,1) string
    end

    methods
        function obj = ConnectBoardScreen(workflow)
            arguments
                workflow matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow
            end

            obj@matlab.hwmgr.internal.hwsetup.ManualConfiguration(workflow, matlab.hwmgr.internal.hwsetup.TemplateLayout.GRID);

            obj.setActiveStep(obj.Workflow.getStepIdx(obj.Workflow.SpkgSetupStep));
            
            obj.ImageSource = fullfile(obj.Workflow.ResourcesDir, "arduino_usb_connection.png");

            obj.setTitle();
            obj.setupMainPanel();
            obj.setupHelpPanel();
        end

        function id = getNextScreenID(obj)
            % Go to normal Arduino USB setup screens
            % Only serial connection is supported in MATLAB Online
            id = 'arduinoio.setup.internal.UpdateServerScreen';
        end

        function id = getPreviousScreenID(obj)
            % Get prior screen from workflow
            id = obj.Workflow.getScreenBeforeSpkgSetup();
        end
    end

    methods(Access = private)
        function setTitle(obj)
            obj.Title.Text = obj.TitleText;
        end

        function setupMainPanel(obj)
            obj.ConfigurationInstructions.Text = obj.DescriptionText;
            obj.ConfigurationImage.ImageFile = char(obj.ImageSource);
        end

        function setupHelpPanel(obj)
            obj.HelpText.AboutSelection = obj.AboutSelectionText;
            obj.HelpText.WhatToConsider = "";
            obj.HelpText.Additional = "";
        end
    end
end

