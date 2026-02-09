classdef WiFiConnectionController < matlabshared.hwsdk.internal.connections.ConnectionController
% WIFICONNECTIONCONTROLLER handles the controller side of functions which
% is related to WiFi connection

%   Copyright 2022-2023 The MathWorks, Inc.

    properties (Constant, Access = private)
        MinPortValue = 1024;
        MaxPortValue = 65535;
    end

    methods (Hidden)

        function updatePreferences(~, hardwareObj)
            hardwareObj.setPreference(hardwareObj.ConnectionType, ...
                                      hardwareObj.DeviceAddress, ...
                                      hardwareObj.Port, ...
                                      hardwareObj.TraceOn, ...
                                      [], ...
                                      hardwareObj.Args.CustomParams);
        end

        function [status, address, port] = validateAddressExistence(~, hardwareObj, address, ~)
            status = hardwareObj.validateWiFiAddressHook(address);
            port = getTCPIPPortHook(hardwareObj);
        end

        function [addressKey, args] = addConnectionTypeProperties(~, hardwareObj)
            args = hardwareObj.Args;
            p = addprop(hardwareObj, 'DeviceAddress');
            % Setting Trace to false for BLE, BT and WiFi as Trace isn't
            % supported on these transports
            args.TraceOn = false;
            hardwareObj.DeviceAddress = args.Address;
            p.SetAccess = 'private';
            p = addprop(hardwareObj, 'Port');
            % port parameter will not be the part of args when raspi object
            % is created without any arguments
            if (isfield(args,'Port') && ~isempty(args.Port)) 
                hardwareObj.Port = args.Port;
            else
                hardwareObj.Port = getTCPIPPortHook(hardwareObj);
            end
            p.SetAccess = 'private';
            addressKey = hardwareObj.DeviceAddress;
        end

        function args = parseAdditionalNVParameters(obj, ~, ~, args, nInputs, nCustomParams, hardwareName, varargin)
        % Only an optional parameter Port is
        % allowed to be specified other than board
        % and address
            if isdeployed && ispref('MATLAB_HARDWARE','HostIOServerEnabled') && getpref('MATLAB_HARDWARE','HostIOServerEnabled')
                % Deployment workflow which has additional ArduinoIDEPath
                % NV pair is supported for WiFi only in HostIOServer
                maxNumofInputParams = 4+nCustomParams;
            else
                maxNumofInputParams = 2+nCustomParams;
            end
            if nInputs > maxNumofInputParams
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:wlLibChangeNotSupported',hardwareName, 'WiFi');
            end
            try
                validateattributes(varargin{3},{'double'}, {'finite','scalar','integer','>', obj.MinPortValue, '<', obj.MaxPortValue})
                args.Port = varargin{3};
            catch
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidWiFiPort',num2str(obj.MinPortValue),num2str(obj.MaxPortValue));
            end
        end

        function connectionObj = createConnectionObject(~, hardwareObj)
            connectionObj = hardwareObj.tcpClientHook(hardwareObj.DeviceAddress, hardwareObj.Port);
        end

        function showFailedUploadError(~, boardName, port)
        % This method throws exception on upload failure.
        % Here port is TCP/IP - numeric
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:failedUpload', char(boardName), num2str(port));
        end
    end

    methods (Access = protected)
        function addressKey = getAddressKeyHook(~, hardwareObj)
            addressKey = hardwareObj.DeviceAddress;
        end
    end

end
