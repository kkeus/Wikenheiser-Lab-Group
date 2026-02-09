classdef ArduinoWorkflow < matlabshared.remoteconnectivity.internal.Remote3pInstallWorkflow &...
                           arduinoio.setup.ddux.DataUtilityHelper

%ARDUINOWORKFLOW The ARDUINOWORKFLOW class is an object that contains
%all of the persistent information for the Arduino Hardware Setup
%screens

% Copyright 2017-2024 The MathWorks, Inc.

    properties
        %LaunchByArduinoSetup - Flag indicates whether workflow is launched by arduinosetup
        LaunchByArduinoSetup
        %LaunchByArduinoExplorer - Flag indicates whether workflow is launched by the Arduino Explorer app
        LaunchByArduinoExplorer
        %DriverEnable - USB driver installation decision from user
        DriverEnable
        %SkipSetup - Flag indicating whether to skip setting up Arduino
        SkipSetup
        %ShowExamples - Example display decision from user
        ShowExamples
        %LaunchExplorerApp - Flag indicating whether Arduino Explorer app should be launched at the end of the setup
        LaunchExplorerApp
        %HWInterface - Interface for HW specific setup callbacks
        HWInterface
        %ResourcesDir - Full path of resources folder in support package
        ResourcesDir
        %ConnectionType - User selected connection type
        ConnectionType
        %Board - User selected board type
        Board
        %Port - User selected port type
        Port
        %Libraries - User selected libraries to be included in server
        Libraries
        %Encryption - User selected WiFi network encryption type
        Encryption
        %Key - User specified WiFi WEP Key
        Key
        %KeyIndex - User specified WiFi WEP KeyIndex
        KeyIndex
        %SSID - User specified WiFi name
        SSID
        %Password - User specified WiFi password
        Password
        %TCPIPPort - Default or user specified TCP/IP port
        TCPIPPort
        %UseStaticIP - Flag indicates users wants to use static IP or not
        UseStaticIP
        %StaticIP - User specified static IP address
        StaticIP
        %BluetoothDevice - User selected Bluetooth device
        BluetoothDevice
        %PairCode - Bluetooth device's pairing code
        PairCode
        %DeviceAddress - Bluetooth/BLE/WiFi address
        DeviceAddress
        %DeviceName - BLE Device name
        DeviceName
        %BluetoothSerialPort - Serial over Bluetooth port
        BluetoothSerialPort
        %SkipProgram - Flag indicates whether to skip programming WiFi board
        SkipProgram
        %TestConnectionResult - Flag indicating status of test connection
        % true indicates successful connection
        TestConnectionResult
        %SkipConfigure - Flag indicates whether to skip configuring Bluetooth device
        SkipConfigure
        %LogFileName - Log file name for the current setup session
        LogFileName
        %Logger - Logger handle
        Logger
    end

    properties
        %Workflow Abstract Properties
        Name = 'Arduino IO'
        FirstScreenID

        SpkgSetupStep = message("MATLAB:arduinoio:general:ArduinoSetupStepName").string
    end

    properties(Access = private)
        % Utility for remote 3p software installation
        DriverUtil

        % First Arduino-specific setup screen
        FirstArduinoSetupScreenID
    end

    properties(Constant)
        BaseCode='ML_ARDUINO'
        HWSPPKGVersion = arduinoio.internal.ArduinoConstants.LibVersion;
    end

    properties(Constant, Access = private)
        InstructionSetName = 'com_mathworks_arduinotools_instrset'
        DesktopBoardConnectScreenID = 'arduinoio.setup.internal.SelectConnectionScreen'
        OnlineBoardConnectScreenID = 'arduinoio.setup.internal.online.ConnectBoardScreen'
        OnlineSetupCompleteScreenID = 'arduinoio.setup.internal.online.SetupCompleteScreen'
    end

    % Properties required by matlabshared.remoteconnectivity.internal.SupportPkgList3pTools
    properties(Constant)
        SpPkgName = message("MATLAB:arduinoio:general:SupportPackageName").string
    end

    % Properties required by matlabshared.remoteconnectivity.internal.SupportPkgList3pTools
    properties(Constant, Access = private)
        ArduinoInstrSets = {'acan2515', 'adafruitmotorshieldv2', 'aekrev2projectfiles', ...
            'arduinoide', 'arduinomatlablibs', 'arduinomotorcarrier'}
    end
    
    % Properties required by matlabshared.remoteconnectivity.internal.SupportPkgList3pTools
    properties(SetAccess = private)
       InstructionSetInfo
    end

    properties(Access = private)
        FirstScreenAfterLicense
    end

    methods
        function obj = ArduinoWorkflow(varargin)
        % register error message catalog
            m = message('MATLAB:arduinoio:general:invalidPort', 'test');
            try
                m.getString();
            catch
                vendorMFilePath = fileparts(arduinoio.SPPKGRoot);
                toolboxIndex = strfind(arduinoio.SPPKGRoot, [filesep, 'toolbox', filesep]);
                supportPackageBasePath = vendorMFilePath(1:toolboxIndex);
                matlab.internal.msgcat.setAdditionalResourceLocation(supportPackageBasePath);
            end
            obj@matlabshared.remoteconnectivity.internal.Remote3pInstallWorkflow(varargin{:});

            % Initialize clean up function. Needed this for arduinoSetup
            % command integration
            c = onCleanup(@() integrateData(obj));

            % Parse the input arguments
            p = inputParser;
            tripwireValidate = @(x)(ischar(x) || isstring(x));
            connectionValidate = @(x)(isa(x,'matlabshared.hwsdk.internal.ConnectionTypeEnum')&&...
                                      ismember(x,enumeration('matlabshared.hwsdk.internal.ConnectionTypeEnum')));
            addParameter(p, 'tripwire', '', tripwireValidate);
            addOptional(p, 'ConnectionType', '', connectionValidate);
            % Optional argument to provide RemoteUtilities (for test)
            addOptional(p, 'RemoteUtilities', []);
            % Ignore any other parameter inputs that the derived classes
            % might have defined
            p.KeepUnmatched = true;
            p.parse(varargin{:});
            obj.LaunchByArduinoSetup = isequal(p.Results.tripwire, 'setup');
            obj.LaunchByArduinoExplorer = isequal(p.Results.tripwire, 'arduinoExplorer');

            initProperties(obj);
            % Change connection type if launched from Arduino Explorer app
            if obj.LaunchByArduinoExplorer
                obj.ConnectionType = p.Results.ConnectionType;
            end

            % Leave RemoteUtilities empty for now if not provided.
            if ~isempty(p.Results.RemoteUtilities)
                obj.RemoteUtilities = p.Results.RemoteUtilities;
            end

            obj.FirstScreenID = getFirstScreenID(obj);

            % Overwrite steps to add 3p install step
            obj.Steps = obj.getSteps();
        end

        function delete(obj)
            try
                delete(obj.Logger);
                % Delete log file created on opening setup but is empty
                s = dir(obj.LogFileName);
                if s.bytes==0
                    delete(obj.LogFileName);
                end
            catch
            end
        end

        function screenID = getBoardSelectionScreen(obj)
            % Utility function to get Arduino board selection screen based
            % on environment
            if ~obj.isUsingRemoteHW()
                screenID = obj.DesktopBoardConnectScreenID;
            else
                screenID = obj.OnlineBoardConnectScreenID;
            end
        end

        function screenID = getOnlineSetupCompleteScreen(obj)
            % Utility function to get ID for Setup Complete screen.
            screenID = obj.OnlineSetupCompleteScreenID;
        end
        
        % Method required by matlabshared.remoteconnectivity.internal.SupportPkgList3pTools
        function screenID = getFirstScreenAfterLicense(obj)
            % Get Screen ID based on environment
            oldScreenID = obj.FirstScreenAfterLicense;
            screenID = obj.getFirstScreenIDForEnvironment(oldScreenID);
            if isequal(oldScreenID, screenID) && obj.isUsingRemoteHW
                % If oldScreenID and screenID are the same for Remote
                % Hardware case, that means the MATLAB Connector is up and
                % running, and connected to MATLAB Online The MATLAB
                % Connector steps is skipped.
                % checkAndSet3PScreen is going to check the exisitence of
                % the required 3P software. If install is needed, it's
                % going to return the screen ID of 3P install. Otherwise
                % it's going to return the screen supposed to happen after
                % 3P software install.
                % If the 3p Install screen is shown, the back button from
                % first screen is going to direct the user to the 3P
                % license screen of support package. The same behavior as
                % when the Install MATLAB screen is shown.
                screenID = obj.checkAndSet3PScreen(obj.licenseScreen, obj.OnlineBoardConnectScreenID);
            end
        end

        function screenID = getScreenAfterOnlineConnection(obj)
            % Override function (declared in RemoteHardwareSetupWorkflow)
            % to get next screen after HW Connector installation for online workflow.
            if obj.isConnectedToMLConnector
                % If the connection to MATLAB Connector gets through. The
                % call below is going to check if the 3P software install
                % step is needed. If the 3P software already exists, it's
                % going to skip the installation step.
                obj.setSpkgScreenOrder(obj.ConnectToConnectorScreen, obj.getScreenBeforeSpkgSetup());
            end
            screenID = obj.ScreenAfterMSHConnection;
        end
    end

    methods(Access = protected)
        % Implement abstract methods for Remote3pInstallWorkflow
        function bundleName = getBundleName(obj)
            % Workflow must provide the name of the Bundle of 3p tools it uses.
            bundleName = obj.InstructionSetName;
        end

        function initProperties(obj)
            try
                %The default selection for DriverEnable is 1 indicating the
                %user wishes to install the Arduino USB Drivers
                obj.DriverEnable = true;
                obj.SkipSetup = false;
                obj.SkipConfigure = false;
                obj.ShowExamples = true;
                obj.LaunchExplorerApp = false;
                obj.ResourcesDir = fullfile(arduinoio.SPPKGRoot, 'resources');
                obj.ConnectionType = matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial;
                obj.Board = 'select a value';
                obj.Port = 'select a value';
                obj.BluetoothDevice = matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05;
                obj.Libraries = arduinoio.internal.ArduinoConstants.DefaultLibraries;
                obj.PairCode = str2double(arduinoio.internal.ArduinoConstants.PairCode);
                obj.BluetoothSerialPort = 'select a value';
                obj.TCPIPPort = arduinoio.internal.ArduinoConstants.DefaultTCPIPPort;
                obj.Encryption = matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WPA;
                obj.UseStaticIP = false;
                obj.TestConnectionResult = true;
                obj.HWInterface = arduinoio.setup.internal.HardwareInterface();
                obj.LogFileName = fullfile(tempdir,['MWArduinoLog-',char(datetime('now','format','yyMMddHHmmss')),'.txt']);
                obj.Logger = matlab.hwmgr.internal.logger.Logger(obj.LogFileName);
            catch err
                throwAsCaller(err);
            end
        end

        function steps = getSteps(obj)
            if ~obj.isUsingRemoteHW()
                steps = {};
            else
                % Override implementation to add 3p install step before Spkg
                % setup
                steps = cellstr({obj.HWConnectorConnectionStep, obj.TpInstallStep, obj.SpkgSetupStep});
            end
        end

        function screenID = getFirstScreenID(obj)
        % Function to return the first screen ID based on the
        % context in which the setup was invoked

        % If launched using arduinosetup or from Wifi configure tab of Arduino Explorer app
            if obj.LaunchByArduinoSetup || (obj.LaunchByArduinoExplorer && isequal(obj.ConnectionType,...
                                                                                   matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi))
                screenID = 'arduinoio.setup.internal.SelectConnectionScreen';
                % If launched from any other configure modal tab of the Arduino Explorer app
                % Skip to upload screen since connection type is already known
            elseif obj.LaunchByArduinoExplorer
                screenID = 'arduinoio.setup.internal.UpdateServerScreen';
                % If Bluetooth connection type is chosen in the Arduino Explorer app
                if isequal(obj.ConnectionType,...
                           matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth)
                    screenID = 'arduinoio.setup.internal.BoardSelectionScreen';
                end
                % If launched from the setup icon in MATLAB's manage add-ons
            else
                screenID = 'arduinoio.setup.internal.SelectConnectionScreen';
            end
            
            obj.FirstScreenAfterLicense = screenID;
            
            % Determine if license screen for 3P software is needed.
            % It is only required to show the license screen for MATLAB
            % Online, because the 3P software is pre-installed with the
            % support package.
            % It is only required to show the licnese screen once for every
            % support package version.
            if obj.isUsingRemoteHW
                % Get the info of the instrsets (required by matlabshared.remoteconnectivity.internal.SupportPkgList3pTools)
                % Note: Currently we need the InstructionSetInfo regardless
                % whether the license screen is skipped. Because the
                % license screen is hardcoded as the first screen in
                % matlabshared.remoteconnectivity.internal.Remote3pInstallWorkflow
                % Even the license screen is skipped. There is a back
                % button in the actual first screen which can lead the
                % sequence back to the licence screen which needs the
                % InstructionSetInfo to display properly.
                obj.InstructionSetInfo = matlabshared.remoteconnectivity.internal.getSupportPkgInstructionSet(obj.ArduinoInstrSets);
                
                % Check if the license setup screen has been shown with the 
                % current version of support package. 
                % validateHWSetupComplete errors out if license setup
                % screen has not been shown with the current spkg version. 
                try 
                    matlabshared.remoteconnectivity.internal.RemoteUtilities.validateHWSetupComplete(obj.BaseCode);
                catch
                    screenID = 'matlabshared.remoteconnectivity.internal.SupportPkgList3pTools';
                    % Update the preference to mark the license screen has
                    % been shown. The current version is going to be saved
                    % as the latest version the license screen has been
                    % shown.
                    matlabshared.remoteconnectivity.internal.RemoteUtilities.setHWSetupCompleteFlag(obj.BaseCode);
                    return;
                end
            end
            
            % Get the screen ID if no need to show the licnese setup screen
            screenID = obj.getFirstScreenAfterLicense;
        end

        function setSpkgScreenOrder(obj, screenIDBeforeSpkgSetup, ~)
            % Override function (declared in Remote3pInstallWorkflow) to 
            % set up 3p screens after HW Connector installation for online
            % workflow.

            % Capture that Connector Screen should show before 3p install
            % screen and that MO Board Connect screen should show after.
            tpInstallScreenID = obj.checkAndSet3PScreen(screenIDBeforeSpkgSetup, obj.OnlineBoardConnectScreenID);

            % Set 3p install screen to show after Connector installation screen.
            obj.setScreenAfterOnlineConnection(tpInstallScreenID);
            obj.setScreenBeforeSpkgSetup(tpInstallScreenID);
        end
    end

end

% LocalWords:  arduinoio
