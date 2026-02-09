classdef ScreenHelper < matlab.hwmgr.internal.hwsetup.TemplateBase
    %SCREENHELPER The ScreenHelper class is a helper class that contains
    %utility functions used by all screen classes
    
    % Copyright 2016-2021 The MathWorks, Inc.
    
    methods(Static)
        function textLabel = buildTextLabel(parent, text, position, fontSize)
            %This helper function takes in a text string
            %a 4 element position array a numerical font size and a parent
            %element. A text label with those properties is constructed and
            %it's handle is returned.
            textLabel = matlab.hwmgr.internal.hwsetup.Label.getInstance(parent);
            textLabel.Text = text;
            textLabel.FontSize=fontSize;
            textLabel.Position = position;
            textLabel.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
        end

        function htmlLabel = buildHTMLLabel(parent,text,position)
            htmlLabel = matlab.hwmgr.internal.hwsetup.HTMLText.getInstance(parent);
            htmlLabel.Text = text;
            htmlLabel.Position = position;
        end
        
        function radioGroup = buildRadioGroup(parent, items, title, position, callback, index)
            %Helper function for creating a radio group with index item
            %selected by default
            radioGroup = matlab.hwmgr.internal.hwsetup.RadioGroup.getInstance(parent);
            radioGroup.Items = items;
            radioGroup.Title = title;
            radioGroup.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            radioGroup.SelectionChangedFcn = callback;
            radioGroup.Position = position;
            radioGroup.ValueIndex = index;
        end
        
        function checkbox = buildCheckbox(parent, text, position, callback, value)
            %Helper function for creating checkbox
            checkbox = matlab.hwmgr.internal.hwsetup.CheckBox.getInstance(parent);
            checkbox.Position = position;
            checkbox.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            checkbox.Text = text;
            checkbox.ValueChangedFcn = callback;
            checkbox.Value = value;
        end
        
        function checkboxList = buildCheckboxList(parent, title, text, position, column, callback,values)
            %Helper function for creating checkbox
            checkboxList = matlab.hwmgr.internal.hwsetup.CheckBoxList.getInstance(parent);
            checkboxList.Title = title;
            checkboxList.Items = text;
            checkboxList.Position = position;
            checkboxList.ColumnWidth = column;
            checkboxList.ValueIndex = values;
            checkboxList.ValueChangedFcn = callback;
        end

        function dropdown = buildDropDown(parent, items, position, callback, index)
            %Helper function for creating dropdown
            dropdown = matlab.hwmgr.internal.hwsetup.DropDown.getInstance(parent);
            dropdown.Items = items;
            dropdown.ValueIndex = index;
            dropdown.Position = position;  
            dropdown.ValueChangedFcn = callback;
        end
        
        function editabledropdrown = buildEditableDropDown(parent, items, position, callback, index)
            %Helper function for creating editable dropdown
            editabledropdrown =matlab.hwmgr.internal.hwsetup.appdesigner.EditableDropDown.getInstance(parent);
            editabledropdrown.Items = items;
            editabledropdrown.ValueIndex = index;
            editabledropdrown.Position = position;
            editabledropdrown.ValueChangedFcn = callback;
        end

        function button = buildButton(parent, text, position, callback)
            %Helper function for creating button
            button = matlab.hwmgr.internal.hwsetup.Button.getInstance(parent);
            button.Text = text;
            button.Color = matlab.hwmgr.internal.hwsetup.util.Color.MWBLUE;
            button.FontColor = matlab.hwmgr.internal.hwsetup.util.Color.ColorTertiary;
            button.Position = position;
            button.ButtonPushedFcn = callback;
        end
        
        function editText = buildEditText(parent, text, position, callback)
            %Helper function for creating edit text
            editText = matlab.hwmgr.internal.hwsetup.EditText.getInstance(parent);
            editText.TextAlignment = 'left';
            editText.Position = position;
            editText.Text = text;
            editText.ValueChangedFcn = callback;
        end
        
        function link = buildHelpText(parent, text, position)
            %Helper function for creating a radio group with index item
            %selected by default
            link = matlab.hwmgr.internal.hwsetup.HelpText.getInstance(parent);
            link.Position = position;
            link.AboutSelection = '';
            link.WhatToConsider = '';
            link.Additional = text;
        end
    end
end
