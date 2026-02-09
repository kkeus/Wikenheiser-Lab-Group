function list = arduinolist(varargin)
%   List available Arduino hardware boards
%
%   Syntax:
%   list = arduinolist
%
%   Description:
%   Returns a list of Arduino boards that you connect with USB.
%
%   Example:
%       list = arduinolist;
%
%   Output Arguments:
%   list - A table that lists available Arduino boards
%
%   See also arduino

% Copyright 2023-2024 The MathWorks, Inc.

dduxHelper = arduinoio.internal.ArduinoDataUtilityHelper;

% Validate the lib version of Arduino support package is compatible with
% the core IO server version (shipped with MATLAB)
try
    arduinoio.internal.validateIOServerCompatibility;
catch e
    % Integrate error with DDUX
    integrateErrorKey(dduxHelper, e.identifier);
    rethrow(e);
end

% Constants
defaultTimeout = 20; % In seconds
% TODO Need to list boards not using default baudrates (g3081450)
defaultIOServerBaudRate = 115200;
defaultPauseTimeConnectingIOServer = 2; % In seconds

% The minimum timeout, if the timeout goes below this, arduinolist
% is going to give inaccurate status 
minimumTimeout = 0.1; 

% Parse input parameter
p = inputParser;
p.PartialMatching = false;
p.CaseSensitive = false;
addParameter(p,'Timeout', defaultTimeout, @(x)validateattributes(x, {'numeric'}, {'scalar', 'positive', 'finite'}));

% Integrate DDUX info at function cleanup
c = onCleanup(@()integrateData(dduxHelper, varargin{:}));

try
    parse(p, varargin{:});
catch
    errorIdentifier = 'MATLAB:arduinoio:general:invalidArduinolistParams';
    % Integrate warning with DDUX
    integrateErrorKey(dduxHelper, errorIdentifier);
    matlabshared.hwsdk.internal.localizedError(errorIdentifier);
end
output = p.Results;
timeout = output.Timeout;

if timeout < minimumTimeout
    errorIdentifier = 'MATLAB:arduinoio:general:tooSmallArduinolistTimeout';
    % Integrate warning with DDUX
    integrateErrorKey(dduxHelper, errorIdentifier);
    matlabshared.hwsdk.internal.localizedError(errorIdentifier, num2str(minimumTimeout));
end

% The version of IO server supported by current MATLAB. The format is
% <majorVersion>.<minorVersion>.<patchVersion>. The IO Server version on
% Arduino boards need to exactly match this version number for proper
% compatibility
requiredIOSeverVersion = arduinoio.internal.ArduinoConstants.LibVersion;

% Get the HW info of connected Arduino board via serial
arduinoHWList = arduinoio.internal.ArduinoHWInfo();

if isempty(arduinoHWList)
    list = [];
    % Throws warning
    warningIdentifier = 'MATLAB:arduinoio:general:NoArduinoFound';
    % Integrate warning with DDUX
    integrateErrorKey(dduxHelper, warningIdentifier);
    matlabshared.hwsdk.internal.localizedWarning(warningIdentifier);
    return;
end

numArduinos = numel(arduinoHWList);
tableContentTemplate = strings(numArduinos,1);
tableContentCell = repmat({{''}},numArduinos,1);
list = table(tableContentTemplate, tableContentTemplate, tableContentTemplate, tableContentCell);
list.Properties.Description = message('MATLAB:arduinoio:general:ArduinolistTableDescription').getString;
list.Properties.VariableNames = {'Port', 'Board', 'Status', 'Libraries'};

% Note: we are using a cached version of available serialportlist. The
% main concern is the the time it takes to do serialportlist on every
% for loop (about 0.3-0.5 seconds every time)
% TODO The RemoteUtilities does not support MATLAB
% compiler deployment yet, need to remove the %#exclude
% below and isdeployed once g3238819 is resolved
%#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
if isdeployed || ~matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
    % Logic for MATLAB desktop 
    availableSerialPortList = serialportlist('available');
else
    % Logic for MATLAB online 
    remoteUtils = matlabshared.remoteconnectivity.internal.RemoteUtilities;
    availableSerialPortList = remoteUtils.serialportlist('available');
end

% Create a timer object
timerObj = timer('TimerFcn', @timeoutCallback, 'StartDelay', timeout);
c = onCleanup(@()cleanup(timerObj));

% Start the timer
start(timerObj);
timerObj.UserData.isTimeoutOccurred = false;

% Flag to check if server validation and status are complete
isStatusCheckComplete = false;
for boardIndex = 1:numel(arduinoHWList)
    if ~timerObj.UserData.isTimeoutOccurred
        arduinoInfo = arduinoHWList(boardIndex);
        list.Port(boardIndex) = arduinoInfo.PortNumber;
        list.Board(boardIndex) = erase(arduinoInfo.ProductName, "Arduino ");
        % Check if the serial port is available. If not, skip getting IO server
        % information
        % This is the most efficient way to check if a serial port is available
        % without atempting an active connection. However serialportlist might
        % not give the proper list in MATLAB online. Probably we need a
        % temporary branch to handle things in MATLAB Online
        % Use live query of serialportlist in case the serialport is not been
        % opened in between for-loop iterations
        if ~ismember(arduinoInfo.PortNumber, availableSerialPortList)
            list.Status(boardIndex) = message('MATLAB:arduinoio:general:StatusInUse').getString;
            list.Libraries(boardIndex) = {convertCharsToStrings(message('MATLAB:arduinoio:general:StatusLibraryInfoNotAvailable').getString)};
            continue;
        end
        
        % TODO The RemoteUtilities does not support MATLAB
        % compiler deployment yet, need to remove the %#exclude
        % below and isdeployed once g3238819 is resolved
        %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
        if isdeployed || ~matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
            % Logic for MATLAB desktop
            serialPortNumber = arduinoInfo.PortNumber;
        else
            % Logic for MATLAB online
            remoteUtils = matlabshared.remoteconnectivity.internal.RemoteUtilities;
            % Request virtual serial port
            startupDelay = 3; % Delay in seconds between port connect and first access attempt
            useDedicatedTransport = true;
            try
                virtualSerialPortObj = remoteUtils.createVirtualSerialPort(arduinoInfo.PortNumber, ...
                        num2str(defaultIOServerBaudRate), startupDelay, useDedicatedTransport);
            catch
                % Usually the createVirtualSerialPort fails if the user
                % declines access from MATLAB Connector, or the user does
                % not have permission to access the serial port on the
                % computer
                list.Status(boardIndex) = message('MATLAB:arduinoio:general:StatusAccessPermissionRequired').getString;
                list.Libraries(boardIndex) = {convertCharsToStrings(message('MATLAB:arduinoio:general:StatusLibraryInfoNotAvailable').getString)};
                continue;
            end
            serialPortNumber = virtualSerialPortObj.virtualComport; 
        end

        % Get IO server information
        transportObj = matlabshared.ioclient.transport.TransportLayerUtility.getTransportLayer(...
            char(matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial), ...
            serialPortNumber, 'BaudRate', num2str(defaultIOServerBaudRate));
        IOProtocolObj = matlabshared.ioclient.IOProtocol(transportObj, 'Checksum', 'enable');
        % Protocol timeout is reduced is to avoid race condition with timer
        % callback function. Usually protocol timeout should be < arduinolist timeout
        % otherwise we will see a warning saying timeout occurred.
        % Distributing protocol timeout equally among all boards when no.
        % of boards are > 1. 
        if ~isscalar(arduinoHWList)
            protocolTimeout = timeout/numel(arduinoHWList);
        else
            % If no. of boards is 1 then reduce the timeout to avoid the
            % race conditions.
            protocolTimeout = timeout/2;
        end
        setIOProtocolTimeout(IOProtocolObj, protocolTimeout);
        IOServerExists = connect(IOProtocolObj, defaultPauseTimeConnectingIOServer);

        if IOServerExists == 1
            % IO Server send back proper response
            % Get Board Info
            boardInfo = getBoardInfo(IOProtocolObj);
            % Get IO Server version
            IOServerVersion = getBoardIOServerVersion(IOProtocolObj);
            list.Libraries(boardIndex) = {convertCharsToStrings(cellstr(split(boardInfo.LibraryList, ',')).')};
            if strcmp(IOServerVersion, requiredIOSeverVersion)
                list.Status(boardIndex) = message('MATLAB:arduinoio:general:StatusReady').getString;
            else
                list.Status(boardIndex) = message('MATLAB:arduinoio:general:StatusUpgradeLink').getString;
            end
        else
            % IO Server did not send back proper response
            list.Status(boardIndex) = message('MATLAB:arduinoio:general:StatusSetupLink').getString;
            list.Libraries(boardIndex) = {convertCharsToStrings(message('MATLAB:arduinoio:general:StatusLibraryInfoNotAvailable').getString)};
        end
        % Set the status complete flag
        isStatusCheckComplete = true;
    else
        % Update the status complete flag
        isStatusCheckComplete = false;
        break;
    end
end

% Throw warning and display intermediate results
if timerObj.UserData.isTimeoutOccurred
    % Update the output to contain the information of the boards which are
    % successfully verified.
    if isStatusCheckComplete
        % boardIndex represents the no. of boards that are checked for IO Server.
        % isStatusCheckComplete indicates that current board is completed in
        % checking the IO Server.
        list = list(1:boardIndex,:);
    else
        % If a board didn't complete the check then don't include the info. 
        % boardIndex-1 indicates the no. of boards which are successfully
        % verified the IO Server
        list = list(1:boardIndex-1,:);
    end

    % Throws warning
    warningIdentifier = 'MATLAB:arduinoio:general:arduinolistTimeout';
    % Integrate warning with DDUX
    integrateErrorKey(dduxHelper, warningIdentifier);
    matlabshared.hwsdk.internal.localizedWarning(warningIdentifier);
end
end

% Function to handle the timeout
function timeoutCallback(obj, ~)
obj.UserData.isTimeoutOccurred = true;
end

% Function to cleanup timer objects
function cleanup(obj)
stop(obj);
delete(obj);
end
