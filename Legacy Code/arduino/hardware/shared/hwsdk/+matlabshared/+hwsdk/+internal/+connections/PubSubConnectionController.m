classdef PubSubConnectionController < matlabshared.hwsdk.internal.connections.ConnectionController
% PUBSUBCONNECTIONCONTROLLER handles the controller side of functions which
% is related to PubSub connection

%   Copyright 2023 The MathWorks, Inc.

    methods (Hidden)
        function updatePreferences(~, hardwareObj)
            hardwareObj.setPreference(hardwareObj.ConnectionType, ...
                                      hardwareObj.DeviceAddress, ...
                                      hardwareObj.SerialNumber, ...
                                      hardwareObj.TraceOn, ...
                                      [], ...
                                      hardwareObj.Args.CustomParams);
        end

        function [status, address, port] = validateAddressExistence(~, ~, address, existingDevices)
            arguments
                ~
                ~
                address {mustBeTextScalar,mustBeNonzeroLengthText}
                existingDevices table {isscalar} = table.empty
            end

            status = false;
            port = [];

            if isempty(existingDevices)
                return;
            end
            address = string(address);
            matchNameIndex = find(existingDevices.Name==address, 2);
            matchSerialIndex = find(existingDevices.SerialNumber==address, 2);
            % No name or serial number matched
            if isempty(matchNameIndex) && ...
                    isempty(matchSerialIndex)
                return;
            end
            % Duplicate devices names found
            if length(matchNameIndex) > 1
                return;
            end
            % Either device name or device serial number is matched
            if ~isempty(matchNameIndex) || ~isempty(matchSerialIndex)
                status = true;
            end
        end

        function [addressKey, args] = addConnectionTypeProperties(~, hardwareObj)
            args = hardwareObj.Args;
            p = addprop(hardwareObj, 'DeviceAddress');
            % Setting Trace to false for PubSub connection
            args.TraceOn = false;
            hardwareObj.DeviceAddress = args.Address;
            p.SetAccess = 'private';
            % We have confirmed only on DeviceAddress which is Name on
            % raspi till now.
            addressKey = hardwareObj.DeviceAddress;
        end

        function connectionObj = createConnectionObject(~, hardwareObj)
            connectionObj = hardwareObj.pubSubConnectionHook(hardwareObj.DeviceAddress);
        end
    end

    methods (Access = protected)
        function addressKey = getAddressKeyHook(~, hardwareObj)
            addressKey = hardwareObj.DeviceAddress;
        end
    end

end
