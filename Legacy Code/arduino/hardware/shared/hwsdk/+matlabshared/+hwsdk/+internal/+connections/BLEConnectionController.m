classdef BLEConnectionController < matlabshared.hwsdk.internal.connections.ConnectionController
% BLECONNECTIONCONTROLLER handles the controller side of functions which
% is related to BLE connection

%   Copyright 2022-2023 The MathWorks, Inc.

    methods (Hidden)

        function updatePreferences(~, hardwareObj)
            hardwareObj.setPreference(hardwareObj.ConnectionType, ...
                                      hardwareObj.Address, ...
                                      [], ...
                                      hardwareObj.TraceOn, ...
                                      [], ...
                                      hardwareObj.Args.CustomParams);
        end

        function [status, address, port] = validateAddressExistence(~, hardwareObj, address, ~)
        % ValidateAddressExistence validates whether the provided address
        % is supported by this transport
        % Inputs:
        % obj - this
        % hardwareObj - hardware object
        % address - BLE address to be validated
        % existingDevices - Known existing devices. Here that input is
        % silenced since HWSDK has a way to detect BLE hardware.
            status = false;
            port = [];
            if ismac||ispc
                if contains(address, ':')
                    address = erase(address,':');
                end
                originalState = warning('off','MATLAB:ble:ble:noDeviceFound');
                try
                    listDevices = getBleListHook(hardwareObj,10);
                    warning(originalState.state,'MATLAB:ble:ble:noDeviceFound');
                    address = upper(address);
                    status = any(ismember(upper(listDevices.Name(:)), address))||any(ismember(listDevices.Address(:),address));
                    %check if user provided device name instead of
                    %address
                    matches = (ismember(upper(listDevices.Name(:)), address));
                    % If ble device names are passed in and there
                    % are more than one ble device with the same
                    % name detected, throw an error and ask for the
                    % unique address
                    ambiguousAddress =[];
                    if sum(matches) > 1
                        for i = 1:size(matches)
                            if(matches(i))
                                ambiguousAddress = [ambiguousAddress listDevices.Address(i)]; %#ok<AGROW>
                            end
                        end
                        matlabshared.hwsdk.internal.localizedError('MATLAB:ble:ble:ambiguousDeviceName', address, char(strjoin(ambiguousAddress,',')));
                    end
                    % replace device name with address
                    if sum(matches)
                        name = address;
                        names =  upper(listDevices.Name);
                        indices = names.matches(string(name));
                        index = find(indices,1);
                        address = listDevices.Address(index);
                    end
                    % Transport confirmed to be BLE than save
                    % bledevicelist to use later in workflow
                    if(status)
                        p = addprop(hardwareObj,'bleDeviceList');
                        hardwareObj.bleDeviceList = listDevices;
                        p.SetAccess = 'private';
                        p.Hidden = true;
                    end
                catch e
                    warning(originalState.state,'MATLAB:ble:ble:noDeviceFound');
                    if strcmpi(e.identifier,'MATLAB:ble:ble:bluetoothOperationRadioNotAvailable')
                        status = 0;
                    elseif strcmpi(e.identifier,'MATLAB:ble:ble:ambiguousDeviceName')
                        throwAsCaller(e);
                    end
                end
            end
        end

        function [addressKey, args] = addConnectionTypeProperties(~, hardwareObj)
        % Setting Trace to false for BLE, BT and WiFi as Trace isn't
        % supported on these transports
            args = hardwareObj.Args;
            args.TraceOn = false;
            p1 = addprop(hardwareObj, 'Name');
            p2 = addprop(hardwareObj, 'Address');
            hardwareObj.Address = char(args.Address);
            Addresses =  hardwareObj.bleDeviceList.Address;
            indices = Addresses.matches(hardwareObj.Address);
            index = find(indices,1);
            hardwareObj.Name = char(hardwareObj.bleDeviceList.Name(index));
            p1.SetAccess = 'private';
            p2.SetAccess = 'private';
            p = addprop(hardwareObj, 'Connected');
            p.GetMethod = @getBLEConnectedStatus;
            p.GetAccess = 'public';
            p.SetAccess = 'protected';
            addressKey = hardwareObj.Address;
        end

        function args = parseAdditionalNVParameters(~, ~, ~, ~, args, ~, ~, hardwareName, ~)
        % No configuration is allowed if connect with BLE
        % and Bluetooth
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:wlLibChangeNotSupported',hardwareName, 'Bluetooth');
        end

        function connectionObj = createConnectionObject(~, hardwareObj)
            connectionObj = hardwareObj.blePeripheralHook(hardwareObj.Address);
        end
    end

    methods (Access = protected)
        function addressKey = getAddressKeyHook(~, hardwareObj)
            addressKey = hardwareObj.Address;
        end
    end

end
