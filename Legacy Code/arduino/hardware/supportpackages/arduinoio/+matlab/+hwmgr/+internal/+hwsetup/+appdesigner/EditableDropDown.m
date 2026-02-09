classdef EditableDropDown <  matlab.hwmgr.internal.hwsetup.EditableDropDown
    % matlab.hwmgr.internal.hwsetup.appdesigner.EditableDropDown is a class that implements a
    % HW Setup dropdown using uidropdown.
    %It exposes all of the settable and gettable properties defined by the
    %interface specification
    %
    %See also  matlab.hwmgr.internal.hwsetup.EditableDropDown
    
    % Copyright 2021 The MathWorks, Inc.
    
    properties(Access = public, Dependent)
        % Inherited Properties
        % Visible
        % Enable
        % Tag
        % Position
        % Title
        % TitlePosition
    end
    
    properties(SetAccess = private, GetAccess = protected)
        % Inherited Properties
        % Parent
    end
    
    properties(GetAccess = protected, SetAccess = protected)
        % Inherited Properties
        % Peer
    end
    
    
    methods(Static)
        function aPeer = createWidgetPeer(parent)
            validateattributes(parent, {'matlab.ui.Figure',...
                'matlab.ui.container.Panel'}, {});
            aPeer = uidropdown('Parent', parent,...
                'Visible', 'on',...
                'Interruptible','off',...
                'Editable', 'on',...
                'FontSize', matlab.hwmgr.internal.hwsetup.util.Font.getPlatformSpecificFontSize());
        end
    end
    
    methods
        function setCallback(obj)
            obj.Peer.ValueChangedFcn = @obj.dropdownCallbackHandler;
        end
        
        function dropdownCallbackHandler(obj, varargin)
            validateattributes(varargin, {'cell'}, {'row', 'ncols', 2});
            validateattributes(varargin{2}, {'event.PropertyEvent', 'event.EventData'}, {});
            obj.safeCallbackInvoke(obj.ValueChangedFcn, varargin{2});
        end
    end
    
    %% Property setters and getters
    methods
        function setValue(obj, value)
            validateattributes(value, {'char'},{});
            obj.Value = obj.Items{obj.ValueIndex};
        end
        
        function setItems(obj, items)
            set(obj.Peer, 'Items', items);
        end
        
        function items = getItems(obj)
            items = get(obj.Peer, 'Items')';
        end
        
        function setValueIndex(obj, valIdx)
            validateattributes(valIdx, {'numeric'}, {'nonempty'});
            obj.Value = obj.Items{valIdx};
            set(obj.Peer, 'Value', obj.Value);
        end
        
        function valIdx =  getValueIndex(obj)
            % obj.Peer.Value reflects the selected entry when UI is updated.
            % Find this entry and return its index.
            valIdx = find(strcmp(obj.Peer.Items, obj.Peer.Value));
        end
    end
    
    methods (Access = {?matlab.hwmgr.internal.hwsetup.Widget})
        function obj = EditableDropDown(varargin)
            obj@matlab.hwmgr.internal.hwsetup.EditableDropDown(varargin{:});
            addlistener(obj, 'ValueIndex', 'PostSet', @obj.dropdownCallbackHandler);
        end
    end
end
% LocalWords:  hwmgr hwsetup
