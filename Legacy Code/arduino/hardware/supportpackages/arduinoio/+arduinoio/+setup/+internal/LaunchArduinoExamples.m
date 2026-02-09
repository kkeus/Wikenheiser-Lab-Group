classdef LaunchArduinoExamples < matlab.hwmgr.internal.hwsetup.TemplateBase
    % LAUNCHARDUINOEXAMPLES - Arduino specific class to enable the creation of screen
    % to notify the end user that the hardware setup is complete and
    % enable user to launch the support package examples and apps.
    %
    % LAUNCHEXAMPLES Properties
    %   Title(Inherited)  Title for the screen specified as a Label widget
    %   Description       Description for the screen specified as a Label
    %                     widget
    %   LaunchCheckbox    Checkbox to launch the support package examples
    %                     using SSI API
    %   LaunchArduinoExplorerCheckBox   Checkbox to launch the Arduino Explorer app
    %
    %   LAUNCHARDUINOEXAMPLES Methods(Inherited)
    %   show                Display the template/screen
    %   logMessage          log diagnostic messages to a file
    %   getPreviousScreenID Return the Previous Screen ID (name of the class)

    %   Copyright 2021-2024 The MathWorks, Inc.

    properties(Access={?matlab.hwmgr.internal.hwsetup.TemplateBase,...
            ?hwsetuptest.util.TemplateBaseTester})
        % Description - Description for the screen (Label)
        Description
        %LaunchCheckbox - Checkbox to launch the support package examples
        LaunchCheckbox
        % LaunchArduinoExplorerCheckBox - Checkbox to launch the Arduino Explorer app
        LaunchArduinoExplorerCheckBox
    end

    methods
        function obj = LaunchArduinoExamples(varargin)
            % Call to base class constructor
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(varargin{:});

            if obj.TemplateLayout == matlab.hwmgr.internal.hwsetup.TemplateLayout.GRID
                widgetParent = obj.ContentGrid;
            else
                widgetParent = obj.ContentPanel;
            end

            % Create the widgets and parent them to the content panel
            % The text in the description is expected with HTML format
            obj.Description = matlab.hwmgr.internal.hwsetup.HTMLText.getInstance(widgetParent);
            % Set Title
            obj.Title.Text = message('hwsetup:template:LaunchExamplesTitle').getString;

            % Set Description Properties
            obj.Description.Text = message('hwsetup:template:LaunchExamplesDescription', obj.Workflow.Name).getString;

            % Set HelpText properties containing default text("lorem ipsum") to empty strings
            obj.HelpText.AboutSelection = '';
            obj.HelpText.WhatToConsider = '';


            % Get the support package root if it is not created yet issue a
            % warning to the user and do not display the LaunchCheckbox
            % since Examples are not available
            currentSPRoot = matlabshared.supportpkg.internal.getSupportPackageRootNoCreate;
            spPkgBaseCode = obj.Workflow.getBaseCode();

            if isempty(currentSPRoot)
                corruptSPRootMSGID = 'hwsetup:template:LaunchExamplesCorruptSPRoot';
                warning(corruptSPRootMSGID, message(corruptSPRootMSGID).getString)
                return;
            end

            % Keep checkbox enabled if Examples are available
            if ~isempty(spPkgBaseCode)
                % NOTE: Do not remove the exclude pragma.
                % This is responsible for suppressing the
                % compiler warnings associated with
                % matlabshared.supportpkg.internal.ssi.getBaseCodesHavingExamples
                hasExamples = matlabshared.supportpkg.internal.ssi.getBaseCodesHavingExamples(...
                    cellstr(spPkgBaseCode), currentSPRoot); %#exclude matlabshared.supportpkg.internal.ssi.getBaseCodesHavingExamples
                if ~isempty(hasExamples)
                    obj.LaunchCheckbox = matlab.hwmgr.internal.hwsetup.CheckBox.getInstance(widgetParent);

                    % Set LaunchCheckbox Properties
                    obj.LaunchCheckbox.Text = message('hwsetup:template:LaunchExamplesCheckboxText').getString;
                    obj.LaunchCheckbox.Value = true;
                end
            end

            % Initialize the checkbox for launching Arduino Explorer app only if hardware setup is launched outside of the app
            if ~obj.Workflow.LaunchByArduinoExplorer
                obj.LaunchArduinoExplorerCheckBox = matlab.hwmgr.internal.hwsetup.CheckBox.getInstance(widgetParent);
                % Set checkbox Properties
                obj.LaunchArduinoExplorerCheckBox.Text = message('MATLAB:arduinoio:general:launchExplorerApp').getString;
                obj.LaunchArduinoExplorerCheckBox.Value = true;
            end

            % Set callback when finish button is pushed
            obj.NextButton.ButtonPushedFcn = @obj.launchExamplesAndCloseUI;

            if obj.TemplateLayout == matlab.hwmgr.internal.hwsetup.TemplateLayout.GRID
                % set up grid layout
                obj.ContentGrid.RowHeight = {'fit', 'fit', 'fit'};
                obj.ContentGrid.ColumnWidth = {'1x'};

                % arrange widgets
                obj.Description.Row = 1;
                if ~isempty(obj.LaunchCheckbox)
                    obj.LaunchCheckbox.Row = 2;
                    if ~isempty(obj.LaunchArduinoExplorerCheckBox)
                        obj.LaunchArduinoExplorerCheckBox.Row = 3;
                    end
                else
                    if ~isempty(obj.LaunchArduinoExplorerCheckBox)
                        obj.LaunchArduinoExplorerCheckBox.Row = 2;
                    end
                end
            else
                % set widget positions
                obj.Description.Position = [20, 350, 430, 20];% 20 pixel gap from the top of the panel.
                if ~isempty(obj.LaunchCheckbox)
                    obj.LaunchCheckbox.Position = [20 320 430 20];% 30 pixel below Description(20 pixel gap between Description and checkbox)
                    if ~isempty(obj.LaunchArduinoExplorerCheckBox)
                        obj.LaunchArduinoExplorerCheckBox.Position = [20, 300, 430, 20];% 20 pixel gap between checkboxes
                    end
                else
                    if ~isempty(obj.LaunchArduinoExplorerCheckBox)
                        obj.LaunchArduinoExplorerCheckBox.Position = [20, 320, 430, 20];% 30 pixel below Description(20 pixel gap between Description and checkbox)
                    end
                end
                
            end

        end

        function launchExamplesAndCloseUI(obj, ~, ~)
            % LAUNCHEXAMPLESANDCLOSEUI - Callback when finish button is pushed that launches the
            % example page and call finish method to close HW Set up
            % window

            % Get the support package root. If it has not been created yet issue a
            % warning to the user and do not attempt to launch the examples
            currentSPRoot = matlabshared.supportpkg.internal.getSupportPackageRootNoCreate;

            dataToIntegrate = {};
            if isempty(currentSPRoot)
                corruptSPRootMSGID = 'hwsetup:template:LaunchExamplesCorruptSPRoot';
                warning(corruptSPRootMSGID, message(corruptSPRootMSGID).getString)

            elseif ~isempty(obj.LaunchCheckbox) && obj.LaunchCheckbox.Value
                % NOTE: Do not remove the exclude pragma.
                % This is responsible for suppressing the
                % compiler warnings associated with
                % matlabshared.supportpkg.internal.ssi.openExamplesForBaseCodes
                matlabshared.supportpkg.internal.ssi.openExamplesForBaseCodes(...
                    cellstr(obj.Workflow.getBaseCode()), currentSPRoot); %#exclude matlabshared.supportpkg.internal.ssi.openExamplesForBaseCodes
                dataToIntegrate=[dataToIntegrate {'Doc'}];
            end

            % Launch Arduino Explorer app if the checkbox is enabled - Do this only if setup is launched from outside the app
            if ~isempty(obj.LaunchArduinoExplorerCheckBox) && obj.LaunchArduinoExplorerCheckBox.Value
                % NOTE: Do not remove the exclude pragma.
                % This is responsible for suppressing the
                % compiler warnings associated with arduinoExplorer
                arduinoExplorer(); %#exclude arduinoExplorer
                dataToIntegrate=[dataToIntegrate {'Explorer'}];
            end

            integrateData(obj.Workflow, dataToIntegrate);
            matlab.hwmgr.internal.hwsetup.TemplateBase.finish([], [], obj);
        end
    end
end

% LocalWords:  LAUNCHEXAMPLES SSI hwsetup lorem ipsum LAUNCHEXAMPLESANDCLOSEUI
