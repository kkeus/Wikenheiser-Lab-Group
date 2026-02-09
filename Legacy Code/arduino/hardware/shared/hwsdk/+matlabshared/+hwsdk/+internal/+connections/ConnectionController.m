classdef ConnectionController < handle
% CONNECTIONCONTROLLER is the base class for controller side of functions
% which is related to a connection

%   Copyright 2022-2023 The MathWorks, Inc.

    properties (Hidden)
        BaudRateSpecified = false
    end

    properties (Constant)
        % Maintain a map of created objects to gain exclusive access.
        ConnectionMap = containers.Map()
    end

    methods (Hidden)
        function validateConnection(obj, addressKey)
        % For all connections except for Mocks, check if this request
        % is a duplicate of existing connection
            if isKey(obj.ConnectionMap, addressKey)
                storedBoard = obj.ConnectionMap(addressKey);
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:connectionExists', char(storedBoard), addressKey);
            end
        end

        function storeBoardConnection(obj, hardwareObj, board)
        % For all connections except for Mocks
        % Add current arduino to connectionMap
            addressKey = getAddressKeyHook(obj, hardwareObj);
            obj.ConnectionMap(addressKey) = board;
        end

        function discardBoardStorage(obj, hardwareObj)
        % For all connections except for Mocks
        % Remove association between board and address key.
            addressKey = getAddressKeyHook(obj, hardwareObj);
            if isKey(obj.ConnectionMap, addressKey)
                remove(obj.ConnectionMap, addressKey);
            end
        end

        function showFailedUploadError(~, ~, ~)
        % This method throws exception on upload failure. Only Serial
        % and WiFi needs to implement this as upload in other
        % transports doesn't happen programmatically.
        % INPUTS:
        %   obj - this
        %   boardName - Board Name
        %   port - Port (COM for serial, TCP/IP for WiFi)
        end
    end

    methods (Access = protected)
        function addressKey = getAddressKeyHook(~, hardwareObj)
            addressKey = hardwareObj.Port;
        end
    end

end
