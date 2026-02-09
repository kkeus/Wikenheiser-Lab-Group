classdef BluetoothConnectionController < matlabshared.hwsdk.internal.connections.ConnectionController
% BLUETOOTHCONNECTIONCONTROLLER handles the controller side of functions which
% is related to Bluetooth connection

%   Copyright 2022-2023 The MathWorks, Inc.

    methods (Hidden)

        function updatePreferences(~, hardwareObj)
            hardwareObj.setPreference(hardwareObj.ConnectionType, ...
                                      hardwareObj.DeviceAddress, ...
                                      [], ...
                                      hardwareObj.TraceOn, ...
                                      getDefaultBaudRate(hardwareObj), ...
                                      hardwareObj.Args.CustomParams);
        end

        function [status, address, port] = validateAddressExistence(~, ~, address, ~)
            status = false;
            port = [];
            if ismac||ispc
                address = strrep(address, '\', '/');
                if contains(address, 'btspp://')
                    address = ['btspp://', upper(address(9:end))];
                end
                try
                    % Retrieve the bluetoothlist warning state set by the user
                    % Suppress the warnings from bluetoothlist API temporarily
                    % userBTListWarningState has the information of the previous warning state
                    userBTListWarningState = warning('off','MATLAB:bluetooth:bluetoothlist:noDeviceFound');
                    devices = bluetoothlist;
                    status = any(ismember(devices.Name(:), address)) || any(ismember(devices.Address(:), upper(address(9:end))));
                    matches = sum(ismember(devices.Name(:), address));
                    % Return to the warnings from bluetoothlist set by the user
                    warning(userBTListWarningState.state,'MATLAB:bluetooth:bluetoothlist:noDeviceFound');
                    % If bluetooth remote names are passed in and there
                    % are more than one bluetooth device with the same
                    % name detected, throw an error and ask for the
                    % unique address
                    if matches > 1
                        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:ambiguousBTName', address);
                    end
                catch
                    % Return to the warnings from bluetoothlist set by the user
                    warning(userBTListWarningState.state,'MATLAB:bluetooth:bluetoothlist:noDeviceFound');
                    status = 0;
                end
            end
        end

        function [addressKey, args] = addConnectionTypeProperties(obj, hardwareObj)
            args = hardwareObj.Args;
            p = addprop(hardwareObj, 'DeviceAddress');
            % Setting Trace to false for BLE, BT, and WiFi as Trace isn't
            % supported on these transports
            args.TraceOn = false;
            % Setting the Serial BaudRate to default value for BT
            % as programmable BaudRate is not supported on BT
            obj.BaudRateSpecified = true;
            args.BaudRate = getDefaultBaudRate(hardwareObj);
            hardwareObj.DeviceAddress = args.Address;
            p.SetAccess = 'private';
            p = addprop(hardwareObj, 'Channel');
            % The supported Bluetooth devices all have one channel
            hardwareObj.Channel = 1;
            p.SetAccess = 'private';
            addressKey = hardwareObj.DeviceAddress;
        end

        function args = parseAdditionalNVParameters(~, ~, ~, ~, args, ~, ~, hardwareName, ~)
        % No configuration is allowed if connect with BLE
        % and Bluetooth
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:wlLibChangeNotSupported',hardwareName, 'Bluetooth');
        end

        function connectionObj = createConnectionObject(~, hardwareObj)
            connectionObj = hardwareObj.bluetoothHook(hardwareObj.DeviceAddress, hardwareObj.Channel);
        end
    end

    methods (Access = protected)
        function addressKey = getAddressKeyHook(~, hardwareObj)
            addressKey = hardwareObj.DeviceAddress;
        end
    end

end
