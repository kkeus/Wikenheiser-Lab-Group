classdef arduinoioserver < handle
%Build and Upload the Arduino IO Server.
%
%Input Arguments:
%   board - Arduino Board type (character vector or string, e.g. 'Uno', 'Mega2560', ...)

%   Copyright 2017-2024 The MathWorks, Inc.

    %% Properties
    properties(Access = private)
        Utility
        BoardInfo
        BoardIndex
    end
    
    properties
        AvailableI2CBusIDs
    end
    properties(Access = private, Constant = true)
        % major release/minor release - 25a
        LibVersion = '25.1.0';
    end
    
    methods(Access = public, Hidden)
        function obj = arduinoioserver(varargin)
            try
                obj.Utility = arduinoio.internal.UtilityCreator.getInstance();
                obj.BoardInfo = arduinoio.internal.BoardInfo.getInstance('SimulinkIO');
                b = obj.BoardInfo;
                boardType = validatestring(varargin{1}, {b.Boards.Name});
                obj.BoardIndex = find(arrayfun(@(x) strcmp(x.Name, boardType), b.Boards), 1);
                
                if isequal(boardType,'Due')
                    obj.AvailableI2CBusIDs = [1 2];
                else
                    obj.AvailableI2CBusIDs = 1;
                end
                
            catch e
                throwAsCaller(e);
            end
        end

    end


    %% hwsdk.controller
    methods(Access = public)
        function updateServerImpl(obj, varargin)
            buildInfo = obj.buildInfoServer();  
            buildInfo.ConnectionType = varargin{1};
            buildInfo.Port = varargin{2};
            buildInfo.HWSPPKGVersion = obj.LibVersion;
            buildInfo.TraceOn = 0;
             %Get the Serial Port assigned for Connecte IO
            buildInfo.SerialPort=varargin{3};

            if buildInfo.TraceOn
                buildInfo.ShowUploadResult = true;
            else
                buildInfo.ShowUploadResult = false;
            end            
            updateServer(obj.Utility, buildInfo);
        end
        
        function info = buildInfoServer(obj)
            buildInfo.Board         = obj.BoardInfo.Boards(obj.BoardIndex).Name;
            buildInfo.BoardName     = obj.BoardInfo.Boards(obj.BoardIndex).BoardName;
            buildInfo.Package       = obj.BoardInfo.Boards(obj.BoardIndex).Package;
            buildInfo.CPU           = obj.BoardInfo.Boards(obj.BoardIndex).CPU;
            buildInfo.MemorySize    = obj.BoardInfo.Boards(obj.BoardIndex).MemorySize;
            
            % Pick the Baud Rate from ExtMode.BaudRate field in Model config set.
            % For Arduino Clone boards which uses CH340 or FTDI chip,
            % customer can use codertarget.arduinobase.registry.setBaudRate
            % which modifies the ExtMode.BaudRate field.
            % 
            % Note: Baudrate is not picked from BoardsInfo xml 
            % num2str(obj.BoardInfo.Boards(obj.BoardIndex).BaudRate);
            buildInfo.BaudRate      = simulinkio.getBaudRate;
            
            buildInfo.MCU           = obj.BoardInfo.Boards(obj.BoardIndex).MCU;
            buildInfo.VIDPID        = obj.BoardInfo.Boards(obj.BoardIndex).VIDPID;
            buildInfo.Libraries = string(arduinoio.internal.ArduinoConstants.DefaultLibraries);

            % Arduino IDE doesn't support Servo Library Build, as it throws
            % a conflict with the existing Servo Library in user/libraries
            if ((isequal(buildInfo.Package, "teensy")) || (isequal(buildInfo.Board, "UnoR4WiFi")) || (isequal(buildInfo.Board, "UnoR4Minima")))
                buildInfo.Libraries = ["SPI" "I2C"];
            end
            % Serial lib is not available for all the arduino boards. Add
            % the lib only if the board supports Serial.
            %g3361999:BoardInfo is always populated with field PinSerial, so checking if
            %PinSerial is non-empty to include Serial Library
            if ~isempty(obj.BoardInfo.Boards(obj.BoardIndex).PinsSerial)
                buildInfo.Libraries = [buildInfo.Libraries,{'Serial'}];
                buildInfo.PinsSerial=obj.BoardInfo.Boards(obj.BoardIndex).PinsSerial;
            end

            if ismember( buildInfo.Board , arduinoio.internal.ArduinoConstants.AREF3VBoards)
                DefaultInternalReference = 3.3;
            else
                DefaultInternalReference = 5.0;
            end
            %Default analog reference values
            buildInfo.AnalogReference = DefaultInternalReference;
            buildInfo.AnalogReferenceMode = 'internal';
            
            % Packet size information
            buildInfo.MAXPacketSize = arduinoio.internal.getMaxBufferSizeForBoard(buildInfo.Board);
			% If any user-defined Addon/Custom-Peripherals are present add
            % them to buildinfo
            simAddonObj = codertarget.arduinobase.ioclient.SimulinkAddonLib;
            libList = simAddonObj.getAddonList();
            if ~isempty(libList)
               for index = 1:length(libList)
                   buildInfo.Libraries{end+1} = libList{index}; 
               end
            end
           

            % WiFi blocks are not supported in Connected IO for RP2040
            % - Connect board due to the WiFiNINA version issues (1.8.8 required to SAMD boards and 1.8.14 required for RP2040 Connect).
            % - PICO has no wifi support
            if matches(buildInfo.Board,{'NanoRP2040Connect','RaspberryPiPico'}) && any(contains(buildInfo.Libraries,"WiFi"))
                throwAsCaller(MException(message('arduino:validation:ConnectedIOBlocksNotSupported','WiFi')));
            end

            % WiFi HTTP blocks are not yet supported in Connected IO for Pico W and RP2040 connect
            if matches(buildInfo.Board,{'NanoRP2040Connect','RaspberryPiPicoW'}) && any(contains(buildInfo.Libraries,"WiFiHTTP"))
                throwAsCaller(MException(message('arduino:validation:ConnectedIOBlocksNotSupported','WiFi HTTP')));
            end
            
            % Servo blocks are not supported in Connected IO for Teensy 4.0 and Teensy 4.1
            % Arduino IDE build uses the common Servo library and doesn't use the specific servo library present in Teensy core.            
            if (isequal(buildInfo.Package, "teensy"))
                if any(contains(buildInfo.Libraries,"Servo"))
                throwAsCaller(MException(message('arduino:validation:ConnectedIOBlocksNotSupported','Servo')));
                end
            end
            
            info = buildInfo;    
        end
    end
end

% LocalWords:  hwsdk arduinoio vid
