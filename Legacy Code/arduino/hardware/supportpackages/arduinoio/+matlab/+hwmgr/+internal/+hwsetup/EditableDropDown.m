classdef EditableDropDown < matlab.hwmgr.internal.hwsetup.Widget & ...
        matlab.hwmgr.internal.hwsetup.mixin.EnableWidget
    %matlab.hwmgr.internal.hwsetup.EditableDropDown is a class that defines a HW
    %   Setup DropDown widget. The DropDown will display a list of items
    %   that the user can select from.
    %
    %   EDITABLE DROPDOWN Properties
    %   Position         - Location and size [left bottom width height]
    %   Visible          - Widget visibility specified as 'on' or 'off'
    %   Items            - List of items to be displayed in the dropdown
    %   ValueIndex       - Index of the selected Item
    %   Value (Read-only)- Value of the selected Item
    %   ValueChangedFcn  - Callback to be executed when the Value changes
    %
    %   EDITABLE DROPDOWN Methods
    %   show()          - Displays the widget
    %
    %Examples:
    %   % Create & display a dropdown widget
    %   w = matlab.hwmgr.internal.hwsetup.Window.getInstance();
    %   d = matlab.hwmgr.internal.hwsetup.EditableDropDown.getInstance(w);
    %   d.Position = [20 20 200 20];
    %   d.Items = {'Item1', 'Item2', 'Item3'};
    %   d.show();
    %
    %   % Select the second entry in the dropdown
    %   d.ValueIndex = 2
    %
    %   % Create & attach a callback function to be executed when the
    %   % selected item changes
    %   function dropdownDisp(widget)
    %       widget.Value
    %       widget.ValueIndex
    %   end
    %   d.ValueChangedFcn = @dropdownDisp
    %   d.ValueIndex = 3;

    %   Copyright 2021 The MathWorks, Inc.

    % ToDo: This is temporary solution and will be removed once dependancy in
    % g2474664 is fixed

    properties(Access=public, Dependent)

        % Items - List of items to be displayed in the dropdown menu
        %   specified as a cell array of strings
        Items
    end

    properties(Access=public, Dependent, SetObservable)

        % ValueIndex - The index of the selected item specified as an
        %    integer
        ValueIndex

        % Inherited Properties
        % Visible
        % Tag
        % Position
    end


    properties(Access=public)

        %ValueChangedFcn - The function callback that gets executed when
        %   the Value in the DropDown menu changes
        ValueChangedFcn
    end

    properties(SetAccess = protected, GetAccess = protected)
        % Inherited Properties
        % Peer
    end

    properties(SetAccess = immutable, GetAccess = protected)
        % Inherited Properties
        % Parent
    end

    properties(SetAccess = private, GetAccess = private)
        % Inherited Properties
        % DeleteFcn
    end

    properties (SetAccess = protected, GetAccess = public)

        % Value - The current value that is selected from the list of items
        %    specified as a string
        Value
    end

    %% Constructor
    methods(Access= protected)
        function obj = EditableDropDown(varargin)
            obj@matlab.hwmgr.internal.hwsetup.Widget(varargin{:});
            % Set defaults
            obj.Position = matlab.hwmgr.internal.hwsetup.util.WidgetDefaults.UIControlPosition;
            obj.Items = {'Option1', 'Option2', 'Option3', 'Option4'};
            obj.DeleteFcn = @matlab.hwmgr.internal.hwsetup.Widget.close;
            obj.setCallback();
        end
    end

    methods(Static)
        function obj = getInstance(aParent)
            obj = matlab.hwmgr.internal.hwsetup.Widget.createWidgetInstance(aParent, mfilename);
        end
    end

    %% Property Setters and Getters
    methods
        function set.Items(obj, items)
            if isempty(items)
                % if items are just an empty cell array, then validate
                % attributes will fail, so assign a 1x1 cell with empty
                % content.
                items = {''};
            end
            validateattributes(items, {'cell'}, {'vector'})
            if ~iscellstr(items) && ~isstring(items)
                error(message('hwsetup:widget:InvalidDataType', 'Items',...
                    'cell array of character vectors or string array'))
            end
            obj.setItems(items);
            obj.setValueIndex(1);
        end

        function items = get.Items(obj)
            items = obj.getItems();
        end

        function set.ValueIndex(obj, valIdx)
            validateattributes(valIdx, {'numeric'}, {'nonempty','scalar','>',0,'<=',numel(obj.Items)});
            obj.setValueIndex(valIdx)
        end

        function valIdx = get.ValueIndex(obj)
            valIdx = obj.getValueIndex;
        end

    end

    methods(Abstract)
        % Set the Callback property on the Peer
        setCallback(obj);
        % Manage the ValueChangedFcn callback assigned by the user by
        % passing it to the safeInvokeCallback method
        dropdownCallbackHandler(obj);
        % Set the Value property to the specified "val"
        setValue(obj, val);
        % Set the ValueIndex on the Peer
        setValueIndex(obj, valIdx);
        % Set the Items on the Peer
        setItems(obj, items);
        % Get the Items from the Peer
        items = getItems(obj);
        % Get the ValueIndex from the Peer
        valIdx = getValueIndex(obj);
    end


end