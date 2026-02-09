classdef (Hidden) Node < matlabshared.hwsdk.internal.base
    %NODE Baseclass which low cost hardware working with HWSDK will inherit
    %to get the CAN feature.

    %   Copyright 2019 The MathWorks, Inc.
        
    properties(Access = protected)
        SupportedCANDeviceInfo
    end
    
    properties
        SupportedCANDevices
    end
    
    methods(Abstract, Access = protected)
        supportedCANDeviceInfo = getSupportedCANDeviceInfoImpl(obj);
        canProviderObj = getCANChannelProviderImpl(obj, deviceName, varargin);
    end
    
    methods(Abstract)
        ch = canChannel(obj, varargin);
    end
    
    %% Getters
    methods
        function supportedCANDevices = get.SupportedCANDevices(obj)
            if isempty(obj.SupportedCANDevices)
                % Fetch boards on which each shield is supported (cellarray)
                supBoards = obj.SupportedCANDeviceInfo.SupportedBoards;
                % Find if obj.Board is available in each cell (cellarray)
                boardIndex = cellfun(@(supBoardsForShield) ... % Function handle with Argument indicating boards on which this Shield is supported
                    ismember(obj.Board, supBoardsForShield), ... % Operate on each cell element to find if obj.Board is part of the boards
                    supBoards, ...
                    'UniformOutput', false);
                % Indices where obj.Board is available
                devicesSupportedByThisBoard = cellfun(@any, boardIndex);
                if any(devicesSupportedByThisBoard)
                    obj.SupportedCANDevices = obj.SupportedCANDeviceInfo.Properties.RowNames(devicesSupportedByThisBoard)';
                    obj.SupportedCANDevices(end+1) = {'MCP2515'};
                else
                    % No shields have form factor like these Arduino boards
                    % All boards support MCP2515
                    obj.SupportedCANDevices = {'MCP2515'};
                end
            end
            supportedCANDevices = obj.SupportedCANDevices;
        end
    end
    
    %% Constructor
    methods
        function obj = Node()
            % Fetch a table which has info about supported shields
            obj.SupportedCANDeviceInfo = getSupportedCANDeviceInfoImpl(obj);
            obj.SupportedCANDevices = {};
        end
    end
    
    %% Utility Methods
    methods(Access = {?matlabshared.hwsdk.internal.base})
        function canChipObj = getCANChannelProvider(obj, deviceName, varargin)
            %getCANChannelProvider is called by canChannel to fetch spkg 
            % specific CAN Chip object
            canChipObj = getCANChannelProviderImpl(obj, deviceName, varargin{:});
        end
        
        function device = validateCANDeviceName(obj, deviceName)
            try
                device = validatestring(deviceName, obj.SupportedCANDevices);
            catch
                obj.localizedError('MATLAB:hwsdk:can:invalidDeviceName', obj.Board, matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(obj.SupportedCANDevices, ', '));
            end
        end
    end
end

