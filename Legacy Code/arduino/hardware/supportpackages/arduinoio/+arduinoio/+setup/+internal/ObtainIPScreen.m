classdef ObtainIPScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %OBTAINIPSCREEN The UpdateServerScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The ObtainIPScreen is used to allow users to get the current IP
    % address from an already-programmed Arduino WiFi board

    % Copyright 2016-2022 The MathWorks, Inc.

    properties(Access = public)
        %BoardDropDown - Dropdown menu that selects the board
        BoardDropDown
        %PortDropDown - Dropdown menu that selects the port
        PortDropDown
        %RetrieveProgress - Progress bar that shows status
        RetrieveProgress
        %RetrieveButton - Progress button that starts getting IP
        RetrieveButton
        %BoardLabelText - Label that shows choose board text
        BoardLabelText
        %PortLabelText - Label that shows choose port text
        PortLabelText
        %RetrieveLabelText - Label that shows button text
        RetrieveLabelText
        %ErrorLabelText - Label that shows program error text
        ErrorLabelText
    end
    
    properties(Access = private, Constant = true)
        FontSize = 10
    end

    methods(Access = 'public')
        function obj = ObtainIPScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:ObtainIPScreenTitle').getString;
            obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:ObtainIPScreenAboutSelection').getString;
            obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:ObtainIPScreenWhatToConsider').getString;
            buildContentPane(obj);
            obj.NextButton.Enable = 'off';
        end
        
        function id = getPreviousScreenID(~)
            id = 'arduinoio.setup.internal.SelectConnectionScreen';
        end

        function  id = getNextScreenID(~)
            id = 'arduinoio.setup.internal.TestConnectionScreen';
        end
        
        function reinit(obj)
            if isempty(obj.Workflow.DeviceAddress)
                obj.NextButton.Enable = 'off';
            end
            obj.ErrorLabelText.Text = '';
            updateBoardDropdown(obj);
            updatePortDropdown(obj);
        end
        
        function show(obj)
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj);
            obj.RetrieveProgress.Visible = 'off';
        end
    end

    methods(Access = 'private')       
        function buildContentPane(obj)
            %BUILDCONTENTPANE - constructs all of the elements for the
            %content pane and adds them to the content pane element
            %collection

            obj.BoardLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:chooseBoardText').getString, [20 360 100 20], obj.FontSize);
            obj.PortLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:chooseDevicePortText').getString, [obj.BoardLabelText.Position(1)+230 obj.BoardLabelText.Position(2) 150 20], obj.FontSize);
            %Set up the dropdown menu to select board
            startPosition = obj.BoardLabelText.Position(1);
            if ismac
                startPosition = startPosition -10;
            end
            obj.BoardDropDown = arduinoio.setup.internal.ScreenHelper.buildDropDown(obj.ContentPanel,...
                {'dummy'}, [startPosition obj.BoardLabelText.Position(2)-20 130 20], @obj.updateBoard, 1); 
            updateBoardDropdown(obj);

            %Set up the dropdown menu to select port
            obj.PortDropDown = arduinoio.setup.internal.ScreenHelper.buildDropDown(obj.ContentPanel,...
                {'dummy'}, [startPosition+230 obj.BoardLabelText.Position(2)-20 110 20], @obj.updatePort, 1); 
            updatePortDropdown(obj);
            if ~ispc
                obj.PortDropDown.addWidth(70);
            end
            
            %Set up retrieve label/progress bar/button to retrieve IP and
            %port from board
            obj.RetrieveLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:ObtainIPScreenButtonText').getString, [20 290 430 20], obj.FontSize);
            obj.RetrieveProgress = matlab.hwmgr.internal.hwsetup.ProgressBar.getInstance(obj.ContentPanel);
            obj.RetrieveProgress.Position = [150 260 280 22];
            obj.RetrieveButton = arduinoio.setup.internal.ScreenHelper.buildButton(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:retrieveButtonText').getString, [20 260 100 23], @obj.retrieveIP);
            
            %Set up error text label
            obj.ErrorLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, '', [20 200 400 50], obj.FontSize);
        end
        
        function updateBoardDropdown(obj)
            %Helper function that shows the correct set of boards based on
            %connection type selected.
            obj.BoardDropDown.Items = getSupportedBoards(obj.Workflow.HWInterface, obj.Workflow.ConnectionType);
            obj.BoardDropDown.ValueIndex = 1;
        end
        
        function updatePortDropdown(obj)
            %Helper function that shows the correct set of ports at current screen
            [availablePorts, index] = getAvailableArduinoPorts(obj.Workflow.HWInterface,  obj.Workflow.Port);
            obj.PortDropDown.Items = availablePorts;
            obj.PortDropDown.ValueIndex = index;
            obj.Workflow.Port = obj.PortDropDown.Value;
        end
        
        function updateBoard(obj, src, ~)
            %Function that is invoked when a radio button is selected. This 
            %function updates the selection.
            obj.Workflow.Board = src.Value;
        end
        
        function updatePort(obj, src, ~)
            %Function that is invoked when a radio button is selected. This 
            %function updates the selection.
            obj.Workflow.Port = src.Value;
        end
        
        function retrieveIP(obj, ~, ~)
            %Function that retrieves the IP address and port number from
            %Arduino board
            obj.RetrieveProgress.Visible = 'on';
            disableScreen(obj);
            c = onCleanup(@() cleanup(obj));
            
            ipAddress = [];
            obj.NextButton.Enable = 'off'; % No effect ? Next button always enabled after a click
            obj.RetrieveProgress.Indeterminate = true;
            if strcmpi(obj.Workflow.Port, 'select a value')
                id = 'MATLAB:arduinoio:general:noSerialPort';
                integrateErrorKey(obj.Workflow, id);
                error(id,message(id).getString);
            end
            obj.ErrorLabelText.Text =  message('MATLAB:arduinoio:general:retrieveWiFiText').getString;
            drawnow;
            try
                [ipAddress] = retrieveIPAddress(obj.Workflow.HWInterface, obj.Workflow.Port, obj.Workflow.Board);
                if isempty(ipAddress)
                    obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                    obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:retrieveIPFailed').getString;
                else
                    obj.Workflow.DeviceAddress = ipAddress;
                    obj.ErrorLabelText.FontColor = '--mw-color-success';
                    obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:operationSuccessText').getString;
                end
            catch e
                integrateErrorKey(obj.Workflow, e.identifier);
                obj.ErrorLabelText.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorError;
                obj.ErrorLabelText.Text = e.message;
            end
            
            function cleanup(obj)
                obj.enableScreen();
                try
                    % Reset NextButton Enable property after enableScreen since
                    % enableScreen will show all widgets regardless of its
                    % settings
                    if isempty(ipAddress)
                        obj.NextButton.Enable = 'off';
                    else
                        obj.NextButton.Enable = 'on';
                    end
                    obj.RetrieveProgress.Indeterminate = false;
                    obj.RetrieveProgress.Visible = 'off';
                catch
                end
            end
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
