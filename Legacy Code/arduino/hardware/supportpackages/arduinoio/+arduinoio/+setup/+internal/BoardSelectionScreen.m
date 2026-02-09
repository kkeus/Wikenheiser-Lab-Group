classdef BoardSelectionScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %BoardSelectionScreen The BoardSelectionScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The BoardSelectionScreen is used to allow users to configure Arduino
    % board for Bluetooth and Bluetooth Low Energy Connection type

    % Copyright 2021-2022 The MathWorks, Inc.

    properties(SetAccess = private, GetAccess = public)
        %BoardDropDown - Dropdown menu that selects the board
        BoardDropDown
        %CheckBoxList - CheckBox list that selects libraries        
        PortDropDown
        %BoardLabelText - Label that shows choose board text
        BoardLabelText
        %PortLabelText - Label that shows choose port text
        PortLabelText
        %PrevConnectionType - Connection type saved before leaving the screen
        PrevConnectionType
        %PrevBoard - Board saved before leaving the screen
        PrevBoard
    end

    properties(Access = private, Constant=true)
        FontSize = 13
    end

    methods(Access = 'public')
        function obj = BoardSelectionScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:BoardSelectionScreenTitle').getString;
            obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:BoardSelectionScreenAboutSelection').getString;
                obj.HelpText.WhatToConsider = '';
            buildContentPane(obj);
            obj.NextButton.Enable = 'off';
        end
 
        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.SelectConnectionScreen';
            if(obj.Workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE)
                obj.Workflow.ConnectionType = matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth;
            end
            saveCurrentSettings(obj);
        end

        function  id = getNextScreenID(obj)
            id = 'arduinoio.setup.internal.UpdateServerScreenBLE';
            saveCurrentSettings(obj);
            c = onCleanup(@() integrateData(obj.Workflow, obj.BoardDropDown.Value));
        end

        function reinit(obj)
            % Reset ConnectionType to Bluetooth if BLE
            if obj.PrevConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                obj.Workflow.ConnectionType = matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth;
            end
            updateBoardDropdown(obj);
            updatePortDropdown(obj);
            obj.HelpText.WhatToConsider = '';
        end

        function show(obj)
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj);
        end
    end

    methods(Access = 'private')
        function buildContentPane(obj)
            %BUILDCONTENTPANE - constructs all of the elements for the
            %content pane and adds them to the content pane element
            %collection
            obj.BoardLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:chooseBoardText').getString, [20 340 100 20], obj.FontSize);
            obj.PortLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:chooseArduinoPortText').getString, [obj.BoardLabelText.Position(1)+230 obj.BoardLabelText.Position(2) 100 20], obj.FontSize);
            %Set up the dropdown menu to select board
            startPosition = obj.BoardLabelText.Position(1);
            if ismac
                startPosition = startPosition-10;
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
        end
 
        function updateBoardDropdown(obj)
            %Helper function that shows the correct set of boards based on
            %connection type selected.
            [boards, index] = getSupportedBoards(obj.Workflow.HWInterface, obj.Workflow.ConnectionType, obj.Workflow.Board);
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
            if ismember(obj.Workflow.Board,arduinoio.internal.ArduinoConstants.BLESupportedBoards)
                obj.Workflow.ConnectionType = matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE;
            else
                obj.Workflow.ConnectionType = matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth;
            end
            if(strcmpi(obj.Workflow.Board,'select a value'))
                obj.NextButton.Enable = 'off';
            elseif(~strcmpi(obj.Workflow.Port,'select a value'))
                obj.NextButton.Enable = 'on';
            end
        end

        function updatePort(obj, src, ~)
            %Function that is invoked when a radio button is selected. This
            %function updates the selection.
            obj.Workflow.Port = src.Value;
            if(strcmpi(obj.Workflow.Port,'select a value'))
                obj.NextButton.Enable = 'off';
            elseif(~strcmpi(obj.Workflow.Board,'select a value'))
                obj.NextButton.Enable = 'on';
            end
        end        

        function saveCurrentSettings(obj)
            obj.PrevConnectionType = obj.Workflow.ConnectionType;
            obj.PrevBoard = obj.Workflow.Board;
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
