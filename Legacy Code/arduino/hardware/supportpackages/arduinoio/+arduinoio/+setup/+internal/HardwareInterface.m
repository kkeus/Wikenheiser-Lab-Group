classdef HardwareInterface < handle
    %HARDWAREINTERFACE This interface will be used to execute Arduino
    %Setup functions

    % Copyright 2016-2024 The MathWorks, Inc.
    
    methods
        function ret = installArduinoUSBDriver(~)
            %find the .inf installation files in the current arduino IDE root
            %Directory. Launch the .inf installer for each
            idedir = arduinoio.getArduinoCLIRootDir();
            arduinoinffolder = fullfile(idedir, 'drivers');

            standardInfFile = fullfile(arduinoinffolder, 'arduino.inf');
            orgInfFile = fullfile(arduinoinffolder, 'arduino-org.inf');
            genuinoInfFile = fullfile(arduinoinffolder, 'genuino.inf');

            standardCmdStr = ['rundll32.exe setupapi,InstallHinfSection DefaultInstall 128 ' standardInfFile];
            orgCmdStr = ['rundll32.exe setupapi,InstallHinfSection DefaultInstall 128 ' orgInfFile];
            genuinoCmdStr = ['rundll32.exe setupapi,InstallHinfSection DefaultInstall 128 ' genuinoInfFile];

            %if any of the expected inf files aren't available return a
            %failure
            if ~exist(standardInfFile, 'file') ||...
                    ~exist(orgInfFile, 'file') ||...
                    ~exist(genuinoInfFile, 'file')
                ret=1;
            else
                stdReturn  = system(standardCmdStr, '-runAsAdmin');
                orgReturn  = system(orgCmdStr, '-runAsAdmin');
                genReturn  = system(genuinoCmdStr, '-runAsAdmin');

                %if ret is non-zero there was an error
                ret = abs(stdReturn) + abs(orgReturn) + abs(genReturn);

            end
        end
        
        function [ports, index] = getAvailableArduinoPorts(~, oldPort)
            %find all available serial ports and also return the index 
            %position of the old port in returned cell array
            usbdev = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
            usbEnumPorts = getSerialPorts(usbdev);

            % Get the available serial ports using serialport. Because 
            % ports from USB enumerator doesnt returns port that are being 
            % used.
            if isdeployed || ~matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW()
                portList = serialportlist('available');
            else
                remoteUtilsObj = matlabshared.remoteconnectivity.internal.RemoteUtilities;
                portList = remoteUtilsObj.serialportlist('available');
            end

            % Remove the system default communication ports returned by the
            % serialportlist command.
            ports = convertStringsToChars(intersect(portList,usbEnumPorts));

            if isempty(ports)
                ports = {'select a value'};
            elseif ischar(ports)
                ports = {'select a value',ports};
            else
                ports = [{'select a value'},ports(:)'];
            end
            % If last selected port still exists, use last port. Otherwise,
            % use first item value
            index = find(ismember(ports, oldPort));
            if isempty(index)
                index = 1;
            end
        end
        
        function ports = getAvailableSerialPorts(~)
            %find all available serial ports on the system
            %this includes true serial, serial over bluetooth and USB
            %serial
            if ~matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
                % Logic for MATLAB desktop
                s = serialportlist;
            else
                % Logic for MATLAB Online
                % Only USB-serial device is supported in MATLAB Online
                usbdev = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
                s = string(getSerialPorts(usbdev));
            end
            if isempty(s)
                ports = {'select a value'};
            else
                ports = s.cellstr;
                ports = ['select a value',ports];
            end
        end
        
        function validateKey(~, key)
            %Check if key is valid,e.g 10-bit or 26-bit hex number
            keyLen = numel(key);
            if ((keyLen~=arduinoio.internal.ArduinoConstants.MinKeyNumDigits)&&(keyLen~=arduinoio.internal.ArduinoConstants.MaxKeyNumDigits)) || (any(~isstrprop(key, 'xdigit')))
                id = 'MATLAB:arduinoio:general:invalidKey';
                error(id, message(id).getString);
            end
        end
        
        function validateKeyIndex(~, index)
            %Check if key index is valid,e.g integer numeric
            if any(~isstrprop(index,'digit'))
                id = 'MATLAB:arduinoio:general:invalidKeyIndex';
                error(id, message(id).getString);
            end
        end
        
        function validateTCPIPPort(~, port)
            %Check if TCP/IP port is a 16 bit integer bigger than 1024
            try
                validateattributes(port,{'double'}, {'finite','scalar','integer','>', arduinoio.internal.ArduinoConstants.MinPortValue,'<=', arduinoio.internal.ArduinoConstants.MaxPortValue})
            catch
                id = 'MATLAB:arduinoio:general:invalidWiFiPort';
                error(id, getString(message(id,num2str(arduinoio.internal.ArduinoConstants.MinPortValue),num2str(arduinoio.internal.ArduinoConstants.MaxPortValue))));
            end
        end
        
        function validateIPAddress(~, ip)
            %Check if IP format is valid
            output = regexp(ip, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}','match');
            if isempty(output) || ~strcmp(output, ip)
                id = 'MATLAB:arduinoio:general:invalidIPAddress';
                error(id, message(id).getString);
            end
        end
        
        function validateBTAddress(~, address)
            % Check bluetooth address is 12-bit hex string
            if (numel(address)~=arduinoio.internal.ArduinoConstants.BluetoothAddressLength) || (any(~isstrprop(address, 'xdigit')))
                id = 'MATLAB:arduinoio:general:invalidBTAddress';
                error(id, message(id).getString);
            end
        end
        
        function validateNetworkSettings(~, workflow)
            %Check whether all required network settings parameters have
            %been specified based on the encryption type
            switch workflow.Encryption
                case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WPA
                    % check SSID, Password and Port to be all non-empty
                    if isempty(workflow.SSID) || isempty(workflow.Password) || isempty(workflow.TCPIPPort)
                        id = 'MATLAB:arduinoio:general:emptyWPAParameters';
                        error(id, message(id).getString);
                    end
                case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WEP
                    % check SSID, Key, Key index and Port to be all non-empty
                    if isempty(workflow.SSID) || isempty(workflow.Key)|| isempty(workflow.KeyIndex) || isempty(workflow.TCPIPPort)
                        id = 'MATLAB:arduinoio:general:emptyWEPParameters';
                        error(id, message(id).getString);
                    end
                case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.None
                    % check SSID and Port to be all non-empty
                    if isempty(workflow.SSID) || isempty(workflow.TCPIPPort)
                        id = 'MATLAB:arduinoio:general:emptyNoneParameters';
                        error(id, message(id).getString);
                    end
            end
            if workflow.UseStaticIP
                if isempty(workflow.StaticIP)
                    id = 'MATLAB:arduinoio:general:emptyStaticIPAddress';
                    error(id, message(id).getString);
                end
            end
        end
        
        function [status,result] = complete3pInstall(~,workflow)
            utility = arduinoio.internal.UtilityCreator.getInstance();
            resMgr = arduinoio.internal.ResourceManager(workflow.Board);
            buildInfo = getBuildInfo(resMgr);
            [status,result] = complete3pInstall(utility,buildInfo);
        end

         function [status] = completeServoESP323pInstall(~,workflow)
            utility = arduinoio.internal.UtilityCreator.getInstance();
            resMgr = arduinoio.internal.ResourceManager(workflow.Board);
            buildInfo = getBuildInfo(resMgr);
            [status] = completeServoESP323pInstall(utility,buildInfo);
        end

        function msg = uploadArduinoServer(~, workflow)
            %program Arduino board with proper server based on given
            %workflow
            utility = arduinoio.internal.UtilityCreator.getInstance();
            resMgr = arduinoio.internal.ResourceManager(workflow.Board);
            buildInfo = getBuildInfo(resMgr);
            buildInfo.ConnectionType = workflow.ConnectionType;
            buildInfo.Port = workflow.Port;
            if workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                buildInfo.DeviceName = workflow.DeviceName;
            end
            buildInfo.Libraries = workflow.Libraries;
            % check if alternate 3P header files are available for the
            % specified library and board
            alternateHeaderSearch = areAlternateLibraryHeadersAvailableImpl(utility, buildInfo);
            buildInfo.AlternateLibraryHeadersAvailable = alternateHeaderSearch;
            % Always display compile and upload result
            buildInfo.ShowUploadResult = true;
            buildInfo.TraceOn = false;
            buildInfo.HWSPPKGVersion = workflow.HWSPPKGVersion;
            if ismember(workflow.Board, {'Mega2560', 'MegaADK', 'Due','MKR1000','MKR1010','MKRZero','Nano33IoT','Nano33BLE','ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'})
                buildInfo.MAXPacketSize  = arduinoio.internal.ArduinoConstants.MaxBufferSizeMegaDueMKRMbed;
            elseif ismember(workflow.Board, {'UnoR4WiFi', 'UnoR4Minima'})
                buildInfo.MAXPacketSize  = arduinoio.internal.ArduinoConstants.MaxBufferSizeRenesasUno;
            elseif ismember(workflow.Board, {'Uno','Nano3','DigitalSandbox','ProMini328_3V','ProMini328_5V'})
                buildInfo.MAXPacketSize  = arduinoio.internal.ArduinoConstants.MaxBufferSize2KRAMBoards;
            else
                buildInfo.MAXPacketSize  = arduinoio.internal.ArduinoConstants.MaxBufferSizeOtherBoards;
            end
            if any(ismember(workflow.Board,arduinoio.internal.ArduinoConstants.BaudRateLowBoards))
                buildInfo.BaudRate = num2str(arduinoio.internal.ArduinoConstants.DefaultLowBaudRate);
            else
                buildInfo.BaudRate = num2str(arduinoio.internal.ArduinoConstants.DefaultBaudRate);
            end
            if workflow.ConnectionType == matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                buildInfo.Encryption = workflow.Encryption;
                buildInfo.SSID = workflow.SSID;
                buildInfo.TCPIPPort = workflow.TCPIPPort;
                if workflow.UseStaticIP
                    buildInfo.StaticIP = workflow.StaticIP;
                else
                    buildInfo.StaticIP = '';
                end
                switch buildInfo.Encryption
                    case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WPA
                        buildInfo.Password = workflow.Password;
                    case matlabshared.hwsdk.internal.WiFiEncryptionTypeEnum.WEP
                        buildInfo.Key = workflow.Key;
                        buildInfo.KeyIndex = workflow.KeyIndex;
                end
            end
            %Default internal analog reference voltage
            if ismember(workflow.Board, arduinoio.internal.ArduinoConstants.AREF3VBoards)
                DefaultInternalReference = 3.3;
            else
                DefaultInternalReference = 5.0;
            end
            
            buildInfo.AnalogReference = DefaultInternalReference;
            buildInfo.AnalogReferenceMode = 'internal';
            try
                msg = updateServer(utility, buildInfo);
            catch e
                throwAsCaller(e);
            end
        end
        
        function [boards, index] = getSupportedBoards(~, type, oldBoard)
            %return a cell array of supported boards based on given
            %connection type and also return the index of the old board in
            %the returned board list
            if nargin < 3
                oldBoard = [];
            end
            boards = arduinoio.internal.ArduinoConstants.getSupportedBoards(type);
            index = 1;
            switch type
                % This is being called in Select Board screen where we
                % still don't know difference between BT and BLE connection
                % type
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                    % add BLE boards to the list as well for user to select
                    % it and then based on board type selected by user we
                    % decide whether they want to go for Bluetooth or BLE
                    boards = [arduinoio.internal.ArduinoConstants.BLESupportedBoards boards];
                    boards = ['select a value', boards];
                     if ~ismember(oldBoard, {'MKR1000', 'MKRZero'})
                        index = find(ismember(boards, oldBoard));
                        if isempty(index)
                            index = 1;
                        end
                    end
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                    boards = ['select a value', boards];
                    index = find(ismember(boards, oldBoard));
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                    boards = ['select a value', boards];
                    if ~isempty(oldBoard) && ismember(oldBoard, {'MKR1000','MKR1010','Nano33IoT'})
                        index = find(ismember(boards, oldBoard));
                        if isempty(index)
                            index = 1;
                        end
                    else
                        index = 1;
                    end
            end
        end
        
        function [bleAddress] = retrieveBLEAddress(~, serialport) 
            %Get the currently assigned BLE address of the device which has
            %Arduino server downloaded 
            s =  matlabshared.seriallib.internal.Serial(serialport);
            s.BaudRate = arduinoio.internal.ArduinoConstants.MKR1000SerialBaudRate;
            connect(s);
            pause(1);
            flushInput(s); % Wait for garbage data to flush out
            write(s, 'whatisyouraddress', 'uint8');
            pause(5);
            c = onCleanup(@()cleanup(s));
            t = tic;
            bleAddress = '';
            try
                while(toc(t) < 60)
                    if s.NumBytesAvailable>0
                        bleAddress = read(s, s.NumBytesAvailable,'char');
                        break;
                    end
                    if isempty(bleAddress)
                        id = 'MATLAB:arduinoio:general:FailedToRetrieveAddressNameLib';
                        error(id, getString(message(id,"Address")));
                    end
                end
            catch e
                if ~strcmpi(e.identifier, 'seriallib:serial:connectFailed')
                    throwAsCaller(e);
                end
            end
            % Make sure serial port is closed on exit of the function
            function cleanup(s)
                disconnect(s);
                delete(s);
            end
        end

        function [bleName] = retrieveBLEName(~, serialport)
            %Get the currently assigned BLE local name of the device which has
            %Arduino server downloaded
            s =  matlabshared.seriallib.internal.Serial(serialport);
            s.BaudRate = arduinoio.internal.ArduinoConstants.MKR1000SerialBaudRate;
            connect(s);
            pause(1);
            flushInput(s); % Wait for garbage data to flush out
            write(s, 'whatisyourname', 'uint8');
            pause(5);
            c = onCleanup(@()cleanup(s));
            t = tic;
            bleName = '';
            try
                while(toc(t) < 60)
                    if s.NumBytesAvailable>0
                        bleName = read(s, s.NumBytesAvailable,'char');
                        break;
                    end
                    if isempty(bleName)
                        id = 'MATLAB:arduinoio:general:FailedToRetrieveAddressNameLib';
                        error(id, getString(message(id,"Name")));
                    end
                end
            catch e
                if ~strcmpi(e.identifier, 'seriallib:serial:connectFailed')
                    throwAsCaller(e);
                end
            end
            % Make sure serial port is closed on exit of the function
            function cleanup(s)
                disconnect(s);
                delete(s);
            end
        end

        function [bleLibs] = retrieveBLELibraries(~, serialport) 
            %Get the currently assigned BLE local name of the device which has
            %Arduino server downloaded
            s =  matlabshared.seriallib.internal.Serial(serialport);
            s.BaudRate = arduinoio.internal.ArduinoConstants.MKR1000SerialBaudRate;
            connect(s);
            pause(1);
            flushInput(s); % Wait for garbage data to flush out
            write(s, 'whatisyourlibrarylist', 'uint8');
            pause(5);
            c = onCleanup(@()cleanup(s));
            t = tic;
            bleLibs = '';
            try
                while(toc(t) < 60)
                    if s.NumBytesAvailable>0
                        bleLibs = read(s, s.NumBytesAvailable,'char');
                        break;
                    end
                    if isempty(bleLibs)
                        id = 'MATLAB:arduinoio:general:FailedToRetrieveAddressNameLib';
                        error(id, getString(message(id,"Libraries")));
                    end
                end
            catch e
                if ~strcmpi(e.identifier, 'seriallib:serial:connectFailed')
                    throwAsCaller(e);
                end
            end
            % Make sure serial port is closed on exit of the function
            function cleanup(s)
                disconnect(s);
                delete(s);
            end
        end

        function [ipAddress,port] = retrieveIPAddress(~, serialport,board) 
            %Get the currently assigned IP address of the device which has
            %Arduino server downloaded 
            ipAddress = [];
            port = [];
            s =  matlabshared.seriallib.internal.Serial(serialport);
            s.BaudRate = arduinoio.internal.ArduinoConstants.MKR1000SerialBaudRate;
            connect(s);
            % Wait for at most 5s before flushing buffers
            pause(5);
            % flush if any data is already on serial buffers, this is
            % needed for ESP32 as board writes on serial on reboot
            if (ismember(board,{'ESP32-WROOM-DevKitC','ESP32-WROOM-DevKitV1'}))
                flushInput(s);
                flushOutput(s);
            end
            pause(5);
            write(s, 'whatisyourip', 'uint8');% IOserver expects this byte first and once received it sends the IP Address of the device on Serial
            pause(5);
            c = onCleanup(@()cleanup(s));
            t = tic;
            data = '';
            try
                while(toc(t) < 60)
                    if s.NumBytesAvailable>0
                        data = read(s, s.NumBytesAvailable,'CHAR');
                    end
                    if ~isempty(data)&&strcmp(data(end),'#')
                       data = strsplit(data,';');
                       statusTemp = data{1};
                       status= str2double(statusTemp(end));
                       if status == matlabshared.hwsdk.internal.WiFiStatusEnum.WL_CONNECTED
                        ipAddress = char(data{2});
                        port = str2double(data{3}(1:end-1));
                        break;
                       else
                           switch status
                                case matlabshared.hwsdk.internal.WiFiStatusEnum.WL_NO_SSID_AVAIL
                                    id = 'MATLAB:arduinoio:general:noSSIDAvailable';
                                    error(id, message(id).getString);
                                case matlabshared.hwsdk.internal.WiFiStatusEnum.WL_CONNECT_FAILED
                                    id = 'MATLAB:arduinoio:general:wlConnectFailed';
                                    error(id, message(id).getString);
                                case matlabshared.hwsdk.internal.WiFiStatusEnum.WL_CONNECTION_LOST
                                    id = 'MATLAB:arduinoio:general:wlConnectLost';
                                    error(id, message(id).getString);
                                case matlabshared.hwsdk.internal.WiFiStatusEnum.WL_DISCONNECTED
                                    id = 'MATLAB:arduinoio:general:wlDisconneted';
                                    error(id, message(id).getString);
                            end
                       end                           
                    end
                end
            catch e
                if ~strcmpi(e.identifier, 'seriallib:serial:connectFailed')
                    throwAsCaller(e);
                end
            end
            % Make sure serial port is closed on exit of the function
            function cleanup(s)
                disconnect(s);
                delete(s);
            end
        end
        
        function texts = getBTConfigureSteps(~, type)
            %return a cell array of character vectors containing texts for
            %each step of configuring Bluetooth device based on the type
            texts = [];
            step1 = getString(message('MATLAB:arduinoio:general:ConfigureBTScreenTableText1',arduinoio.internal.ArduinoConstants.PairCode));
            if type == matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC06
                texts = {step1};
            elseif type == matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05
                texts = {message('MATLAB:arduinoio:general:ConfigureBTScreenTableText2').getString, step1};
            end
        end
        
        function [rates, index] = getBTSupportedBaudRates(~, type)
            %return a cell array of supported baud rates for given type and
            %also return the default factory baud rate index in the cell
            %array
            rates = arduinoio.internal.ArduinoConstants.getBTSupportedBaudRates(type);
            index = [];
            if type == matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC06
                % Set pre-selected baud rate to 38400
                index = 6;
            elseif type == matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05 
                % HC-05 always enters the limited AT mode with 38400 baud rate
                index = 1;
            end
        end
        
        function result = configureBTDevice(~, type, port, board, newname)
            %configure Bluetooth device HC05/HC06 at given port to
            %board-specific baudrate via AT commands
            %Example:
            %   configureBTDevice(obj, arduinoio.internal.BluetoothDeviceTypeEnum.HC05, 'COM20', 'Uno')
            %   configureBTDevice(obj, arduinoio.internal.BluetoothDeviceTypeEnum.HC05, 'COM82', 'Uno', 'UnoHC05')
            
            % TODO - if other boards with other baudrate are to be
            % supported, this hardcoded value shall be changed into a map
            % or struct.
            if ismember(board, arduinoio.internal.ArduinoConstants.BluetoothSupportedBoards) 
                newbaudrate = arduinoio.internal.ArduinoConstants.ArduinoBTBaudRate;
            end
            switch type
                case matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05
                    ATScript = {'AT+ROLE=0', ...
                                ['AT+PSWD=',arduinoio.internal.ArduinoConstants.PairCode], ...
                                ['AT+UART=',num2str(newbaudrate),',0,0']};
                    if nargin > 5
                        ATScript = [ATScript, ['AT+NAME=',newname]];
                    end
                    serialObject = matlabshared.seriallib.internal.Serial(port);
                    terminator = [13 10];%append CR/LF terminator
                case matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC06
                    if newbaudrate == 115200 % only use this rate now given the list of boards we support
                        command = 'AT+BAUD8';
                    end
                    ATScript = {['AT+PIN',arduinoio.internal.ArduinoConstants.PairCode], command};
                    if nargin > 5
                        ATScript = [ATScript, ['AT+NAME',newname]];
                    end
                    serialObject = matlabshared.seriallib.internal.Serial(port);
                    terminator = [];
                otherwise
                    result = false;
                    return;
            end
            result = false;
            baudrates = arduinoio.internal.ArduinoConstants.BTSupportedBaudRates(double(type));
            c = onCleanup(@() cleanup(serialObject));
            try
                connect(serialObject);
                for ii = 1:numel(baudrates)
                    % iterate through all supported baud rates for given BT
                    % device and execute the first AT command to see if the
                    % correct baudrate is found.
                    serialObject.BaudRate = str2double(baudrates(ii));
                    result = sendATHelper(serialObject,ATScript{1},terminator);
                    % once the first command executes fine, finish
                    % executing all remaining commands. If any command
                    % fails, return false.
                    index = 2;
                    while result&&index<=length(ATScript)
                        result = sendATHelper(serialObject,ATScript{index},terminator);
                        if ~result
                            return;
                        end
                        index=index+1;
                    end
                    % if all commands execute fine, return true
                    if result
                        return;
                    end
                end
            catch
                result = false;
            end
            
            function out = sendATHelper(serialObject,command,terminator)
                out = false;
                write(serialObject, uint8([command terminator]));
                localTimer = tic;
                while toc(localTimer) < 3
                    if serialObject.NumBytesAvailable > 0
                        output = char(read(serialObject,serialObject.NumBytesAvailable,'uint8'));
                        % Check if result is non-empty and contains OK
                        if contains(output, 'OK')
                            out = true;
                        end
                    end
                end
            end
            
            function cleanup(serialObject)
                disconnect(serialObject);
                delete(serialObject);
            end
        end
        
        function [properties, value] = getDeviceProperties(~, workflow)
            %Return Arduino properties and their values based on connection
            %type
            libs = strjoin(workflow.Libraries,', ');
            switch workflow.ConnectionType
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                    properties = {'Connection Type','Port','Board','Libraries'};
                    value = {'USB',workflow.Port,workflow.Board,libs};
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                        properties = {'Connection Type','Device Address', 'Board','Libraries'};
                        value = {'Bluetooth',workflow.DeviceAddress, workflow.Board,libs};
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                    properties = {'Connection Type','Address', 'Name', 'Board','Libraries'};
                    % For Mac a random device address is assigned for BLE devices
                    % check if there are multiple devices with same name
                    % and error for conflict as there is no way to
                    % establish identity of board that was setup
                    if ismac
                        try
                            deviceList = blelist("Name",workflow.DeviceName);
                            if(height(deviceList)>1)
                                workflow.DeviceAddress = message('MATLAB:arduinoio:general:ErrorObtainingDeviceAddress').getString;
                                value = {'Bluetooth',workflow.DeviceAddress,workflow.DeviceName, workflow.Board,libs};
                                return;
                            else
                                workflow.DeviceAddress=char(deviceList.Address);
                            end
                        catch e
                            if (strcmpi(e.identifier,'MATLAB:ble:ble:invalidMacBluetoothState'))
                                workflow.DeviceAddress = message('MATLAB:arduinoio:general:BTRadioNotAvailableText').getString;
                                value = {'Bluetooth',workflow.DeviceAddress,workflow.DeviceName, workflow.Board,libs};
                                return;
                            end
                        end
                    else % on windows
                        % erase ':' from device address
                        workflow.DeviceAddress = erase(workflow.DeviceAddress,':');
                    end
                    value = {'Bluetooth',upper(workflow.DeviceAddress),workflow.DeviceName, workflow.Board,libs};
                case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                    properties = {'Connection Type','Device Address','Board','Port','Libraries'};
                    value = {'WiFi',workflow.DeviceAddress,workflow.Board,num2str(workflow.TCPIPPort),libs};
            end
        end
        
        function [result,err] = testConnection(~, workflow)
            %Attempts to create arduino connection based on current settings
            result = false;
            err = '';
            try
                switch workflow.ConnectionType
                    case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                        a = arduino(workflow.Port, workflow.Board,'Trace',false); %#ok<NASGU>
                        clear a;
                    case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                        newPref.Address = workflow.DeviceAddress;
                        CustomParams.Board = workflow.Board;
                        newPref.CustomParams = CustomParams;
                        newPref.ConnectionType = workflow.ConnectionType;
                        newPref.Port = '';
                        newPref.TraceOn = false;
                        newPref.BaudRate = 115200;
                        setpref('MATLAB_HARDWARE', 'MATLABIO_Arduino', newPref);
                        a = arduino(workflow.DeviceAddress); %#ok<NASGU>
                        clear a;
                    case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                        address = workflow.DeviceAddress;
                        address = upper(erase(address,':'));
                        newPref.Address = address;
                        CustomParams.Board = workflow.Board;
                        newPref.CustomParams = CustomParams;
                        newPref.ConnectionType = workflow.ConnectionType;
                        newPref.Port = '';
                        newPref.TraceOn = false;
                        newPref.BaudRate = 115200;
                        setpref('MATLAB_HARDWARE', 'MATLABIO_Arduino', newPref);
                        a = arduino(workflow.DeviceAddress); %#ok<NASGU>
                        clear a;
                    case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                        a = arduino(workflow.DeviceAddress, workflow.Board, workflow.TCPIPPort); %#ok<NASGU>
                        clear a;
                end
                result = true;
            catch e
                err = e;
            end
        end

        function saveBluetoothPrefs(~,board,address)
            % Function to save Bluetooth connection preferences

            import arduinoio.internal.ArduinoConstants
            % Check if Bluetooth preference already exists and retrieve it
            if ispref(ArduinoConstants.PrefGroupName,ArduinoConstants.BluetoothPrefName)
                prefs = getpref(ArduinoConstants.PrefGroupName,ArduinoConstants.BluetoothPrefName);
                prefs(string(address)) = string(board);
                rmpref(ArduinoConstants.PrefGroupName,ArduinoConstants.BluetoothPrefName);
            else
                prefs = containers.Map(string(address),string(board));
            end
            addpref(ArduinoConstants.PrefGroupName,ArduinoConstants.BluetoothPrefName, prefs);
        end

        function saveBLEPrefs(~,board,address,name)
            % Function to save BLE connection preferences.

            import arduinoio.internal.ArduinoConstants
            % Check if BLE preference already exists and retrieve it
            if ispref(ArduinoConstants.PrefGroupName,ArduinoConstants.BLEPrefName)
                prefs = getpref(ArduinoConstants.PrefGroupName,ArduinoConstants.BLEPrefName);
                % Save in BoardName(BLE name) format
                prefs(string(address)) = sprintf("%s(%s)",string(board),string(name));
                rmpref(ArduinoConstants.PrefGroupName,ArduinoConstants.BLEPrefName);
            else
                prefs = containers.Map(string(address),sprintf("%s(%s)",string(board),string(name)));
            end
            addpref(ArduinoConstants.PrefGroupName,ArduinoConstants.BLEPrefName,prefs);
        end

        function saveWiFiPrefs(~,isStaticIP,board,address,port)
            % Function to save WiFi connection preferences

            import arduinoio.internal.ArduinoConstants
            % Save preference only for Static Wifi connections
            if ~isStaticIP
                return;
            end

            % Check if WiFi preference already exists and retrieve it
            addressPortPair = sprintf("%s:%d",address,port);
            if ispref(ArduinoConstants.PrefGroupName,ArduinoConstants.WiFiPrefName)
                prefs = getpref(ArduinoConstants.PrefGroupName,ArduinoConstants.WiFiPrefName);
                prefs(string(addressPortPair)) = string(board);
                rmpref(ArduinoConstants.PrefGroupName,ArduinoConstants.WiFiPrefName);
            else
                prefs = containers.Map(string(addressPortPair),string(board));
            end
            addpref(ArduinoConstants.PrefGroupName,ArduinoConstants.WiFiPrefName, prefs);
        end

    end

end

% LocalWords:  rundll setupapi
