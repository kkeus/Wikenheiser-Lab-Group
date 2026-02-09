function arduinosetup()
%Launch Arduino setup screens
%
%Syntax:
%arduinosetup
%
%Description:
%Launches the Arduino setup screens for configuring Arduino connection.

%   Copyright 2018-2024 The MathWorks, Inc.

    % Error out if the RemoteConnectivity feature is not enabled in MATLAB
    % Online
    % It is going to terminate early to prevent user from going too far
    % into setup workflow and later find out the feature is not available
    % for them
    % TODO The RemoteUtilities does not support MATLAB
    % compiler deployment yet, need to remove the %#exclude
    % below and isdeployed once g3238819 is resolved
    %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
    if ~isdeployed && matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
        if matlab.internal.feature("RemoteConnectivity") == 0
            matlabshared.hwsdk.internal.localizedError('remote_connectivity:general:RemoteConnectivityNotEnabled');
        end
    end

    workflow = matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow('tripwire', 'setup');
    workflow.launch;
end