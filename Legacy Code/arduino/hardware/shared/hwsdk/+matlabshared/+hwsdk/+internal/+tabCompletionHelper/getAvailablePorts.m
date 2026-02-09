function ports = getAvailablePorts()

%   Copyright 2018-2024 The MathWorks, Inc.

    % USB Enumerator might trigger web browser popup in MATLAB Online,
    % asking to open MATLAB Connector.
    % Skip the call to USB Enumerator if both the conditions below are true
    % in MATLAB Online.
    % 1. The user has NOT successfully connected to MATLAB Connector via
    % Hardware setup screens before. In this case they might not know what
    % is MATLAB Connector.
    % 2. There is no active connection between MATLAB Online and MATLAB
    % Connector. If there is already a connection, there would not be a web
    % browser popup.
    % TODO The RemoteUtilities does not support MATLAB
    % compiler deployment yet, need to remove the %#exclude
    % below and isdeployed once g3238819 is resolved
    %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
    if ~isdeployed && matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW...
        && ~(ispref('MATLAB_ONLINE', 'INSTALLED_MLC_BEFORE') ...
        && getpref('MATLAB_ONLINE', 'INSTALLED_MLC_BEFORE') == true)
        remoteUtil = matlabshared.remoteconnectivity.internal.RemoteUtilities();
        if ~remoteUtil.isConnected()
            % Skip call to USB enumerator, return empty cell
            ports = cell(0,1);
            return;
        end
    end
    usbDevices = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
    comPorts = usbDevices.getSerialPorts();
    ports = cellstr(char(comPorts));
end

% LocalWords:  matlabshared
