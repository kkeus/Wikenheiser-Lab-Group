classdef ArduinoConstants
%ARDUINOCONSTANTS This static class contains all constants used by arduino
%source and setup app.

% Copyright 2016-2024 The MathWorks, Inc.

    properties(GetAccess = public, Constant = true)
        AREF3VBoards = {'Due', 'DigitalSandbox', 'MKR1000','MKR1010','MKRZero','ProMini328_3V','Nano33IoT','Nano33BLE','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
        ExternalAREFUnsupportedBoards = {'Due','Nano33BLE','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
        BaudRateLowBoards = {'DigitalSandbox','ProMini328_3V'}
        SerialLibrarySupportBoards = {'Mega2560','MegaADK', 'MKR1000','MKR1010','MKRZero','Leonardo','Micro','Due','Nano33IoT','Nano33BLE','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
        RotaryEncoderSupportedBoards = {'Uno','UnoR4WiFi','UnoR4Minima','Nano3','Nano33IoT','Mega2560','MegaADK','MKR1000','MKR1010','MKRZero','Leonardo','Micro','Due','ProMini328_5V','ProMini328_3V','DigitalSandbox','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
        MKRMotorCarrierLibrarySupportedBoards = {'MKR1000','MKR1010','MKRZero'};
        MotorCarrierLibrarySupportedBoards = {'MKR1000','MKR1010','MKRZero','Nano33IoT'};
        AlternateLibraryHeaderSupport = {{'MotorCarrier', arduinoio.internal.ArduinoConstants.MKRMotorCarrierLibrarySupportedBoards}};
        NanoCarrierSupportedBoards = {'Nano33IoT'}; % nano carrier boards to be added in this list
        AdafruitMotorShieldSupportedBoards = {'Uno','Due','Mega2560','MegaADK','Leonardo'};
        BoardsNotSupportedinMLIO = {'NanoRP2040Connect','RaspberryPiPico','RaspberryPiPicoW','Teensy41','Teensy40'};
        BoardsRequireShortPause = {'Micro', 'Leonardo','Nano33IoT','MKR1000','MKR1010','Nano33BLE','NanoRP2040Connect','RaspberryPiPico','RaspberryPiPicoW','UnoR4Minima','UnoR4WiFi'};
        BoardsRequireLongPause = {'MKR1000','MKR1010','Nano33IoT'};
        DefaultBaudRate = 115200
        DefaultLowBaudRate = 57600
        LibVersion = '25.1.0';
        LinuxSupportedConnectionTypes = {'USB', 'WiFi'}
        WinMacSupportedConnectionTypes = {'USB', 'Bluetooth®', 'WiFi'}
        SupportedEncryptionTypes = {'WPA/WPA2', 'WEP', 'None'}
        DefaultTCPIPPort = 9500
        MinKeyNumDigits = 10
        MaxKeyNumDigits = 26
        MinPortValue = 1024
        MaxPortValue = 65535
        MaxBufferI2CSAMDMBEDESP = 144
        MaxBufferI2CAVRSAM = 32
        MaxBufferSPIAllboards = 144
        MaxPWMServoESP32 = 16
        %Serial
        MaxBufferSerialAVR = 64
        MaxBufferSerialSAMD = 144
        MaxBufferSerialSAM = 128
        MaxBufferSerialMbedESP = 255 % write works only for 239 bytes and read works for 255 bytes of data for Nano 33 BLE, ESP32 says 256 in Arduino code need to verify
        MaxBufferSize2KRAMBoards = 57
        MaxBufferSizeMegaDueMKRMbed = 720
        MaxBufferSizeOtherBoards = 150
        MaxBufferSizeRenesasUno = 512

        WiFiSupportedBoards = {'UnoR4WiFi','MKR1000','MKR1010','Nano33IoT','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
        WEPNotSupportedBoards = {'ESP32-WROOM-DevKitV1', 'ESP32-WROOM-DevKitC','UnoR4WiFi'};
        ESP32Boards = {'ESP32-WROOM-DevKitV1', 'ESP32-WROOM-DevKitC'}
        BluetoothSupportedBoards = {'Uno', 'Mega2560', 'Nano3', 'Due', 'Leonardo', 'Micro'}% Bluetooth does not support MKR1000 since Serial pins are not broken out on board. TX/RX are Serial1
        BLESupportedBoards = {'Nano33BLE','MKR1010','Nano33IoT','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'}
        BoardsRequireCompileAndUploadCommandsSeperately = {'ESP32-WROOM-DevKitV1', 'ESP32-WROOM-DevKitC'};
        DefaultLibraries = {'I2C', 'Servo', 'SPI'}
        ShippingLibraries = {'I2C', 'SPI', 'Servo', 'Ultrasonic', 'RotaryEncoder', 'ShiftRegister','Serial','NeoPixel'}
        BTSupportedBaudRates = containers.Map(double([matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC05,matlabshared.hwsdk.internal.BluetoothDeviceTypeEnum.HC06]),...
                                              {{'38400'}, {'38400','9600','115200','1200','2400','4800','19200','57600'}})
        SupportedBTDevices  = {'HC-05', 'HC-06'};
        BluetoothAddressLength = 12
        PairCode = '1234'
        ArduinoBTBaudRate = 115200
        MKR1000SerialBaudRate = 9600

        %BLE parameters
        ServiceUUID = 'BEC069d9-E1DC-34B4-8A05-F24198ED6E57'
        ReadCharacteristicUUID = 'F9EAB5DE-92E7-457E-B640-8BC64FC6ED7C'
        WriteCharacteristicUUID = '3236DE8B-F993-48D0-9688-0C6C9ED5F6D1'


        ServoReservedPins = {'D9', 'D10'};
        ServoReservedPinsMega = {'D11', 'D12'};
        MaxServos = 12;
        MaxServosMega = 48;
        MaxServosDue = 52;
        MaxServosNano33BLE = 22;
        MaxServosESP32 = 16;
        ServoCountCutOffESP32 = 16;
        ServoCountCutOff = 0;
        ServoCountCutOffMega = 12;
        %serial peripheral constants for Arduino
        SupportedBaudRates = [300 600 1200 2400 4800 9600 14400 19200 28800 38400 57600 115200]
        SupportedDataBits = [5 6 7 8];
        SupportedStopBits = [1 2]
        SupportedParityTypes = {'none','odd','even'}

        %analog reference voltages
        InternalAnalogReferenceAVR = {1.1,2.56};
        InternalAnalogReferenceSAMD = {1.0,1.65,2.23};

        % CAN
        SupportedCANShields = ["MKR CAN Shield", "Sparkfun CAN-Bus Shield", "Seeed Studio CAN-Bus Shield V2"];
        ChipSelectMKR = "D3";
        InterruptMKR = "D7";
        ChipSelectSparkfun = "D10";
        InterruptSparkfun = "D2";
        ChipSelectSeeed = "D9";
        InterruptSeeed = "D2";
        OscillatorFreqForSupportedShields = 16e6;
        BoardsSupportingMKR = ["MKR1000", "MKR1010", "MKRZero"];
        BoardsSupportingSparkfun = ["Uno", "UnoR4WiFi", "UnoR4Minima"];
        BoardsSupportingSeeed = ["Uno", "UnoR4WiFi", "UnoR4Minima", "Mega2560", "MegaADK", "Due", "Leonardo"];
        OscillatorFrequenciesMCP2515 = [8e6, 10e6, 16e6];
        BusSpeedsMCP2515 = [5e3, 8e3, 10e3, 12.5e3, 20e3, 31.25e3, 40e3, 50e3, 62.5e3, 100e3, 125e3, 200e3, 250e3, 500e3, 1e6];
        ESP32InputOnlyTerminals = [34,35,36,37,38,39];
        ESP32OutputOnlyTerminals = [0];
        Nano3AndProMiniAnalogOnlyTerminals = [20, 21];

        % MATLAB preference name for saved Arduino device
        % info for use in the Arduino Explorer app
        PrefGroupName = "MATLAB_HARDWARE"
        % Preference name for Arduino Bluetooth device addresses
        BluetoothPrefName = "ARDUINOIO_BT_PREFS"
        % Preference name for Arduino BLE device addresses
        BLEPrefName = "ARDUINOIO_BLE_PREFS"
        % Preference name for Arduino WiFi device addresses
        WiFiPrefName = "ARDUINOIO_WIFI_PREFS"

        % Properties to store core and library versions
        CoreVersions = dictionary('avr','1.8.3', 'sam','1.6.12', 'samd','1.8.9', ...
                                  'mbed','1.3.2','esp','2.0.11','renesas_uno','1.0.2');
        LibVersions = dictionary('Servo','1.1.8','ACAN2515','2.0.2', 'Adafruit Motor Shield V2 Library','1.0.4',...
                                 'ArduinoBLE','1.2.0','ArduinoMotorCarrier','2.0.0','MKRMotorCarrier','1.0.1', ...
                                 'ServoESP32','1.0.3','WiFi101','0.16.0','WiFiNINA','1.8.8');
        % Arduino CLI version number
        CLIVersion = '1.0.2'

        % 3P URLs
        ThirdPartyURLs = dictionary('ESP32','https://espressif.github.io/arduino-esp32/package_esp32_index.json');

        % Online
        BoardsNotSupportedInOnline = {'ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC'};
    end

    properties(GetAccess = public, Constant = true, Hidden)
        %Peripherals whose wrappers are generated using
        %iobuilder for Connected I/O
        AutogeneratedLibraries = ["AnalogOutput", "InputCapture","WiFiTCP","WiFiUDP","WiFiMQTT","WiFiHTTP","EEPROM","WiFiThingspeak"];
    end

    methods(Static)
        function devices = getSupportedConnectionTypes
        %Return supported connection types based on OS
            if strcmpi(computer, 'GLNXA64')
                devices = arduinoio.internal.ArduinoConstants.LinuxSupportedConnectionTypes;
            else
                devices = arduinoio.internal.ArduinoConstants.WinMacSupportedConnectionTypes;
            end
        end

        function boards = getSupportedBoards(type)
        %Return supported boards based on connection type
            boards = [];
            switch type
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                % Support all boards for ethernet testing using Host IO Server
                if ispref('MATLAB_HARDWARE','HostIOServerEnabled') && getpref('MATLAB_HARDWARE','HostIOServerEnabled')
                    boards = arduinoio.internal.TabCompletionHelper.getSupportedBoards;
                else
                    boards = arduinoio.internal.ArduinoConstants.WiFiSupportedBoards;
                end
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                boards = arduinoio.internal.ArduinoConstants.BluetoothSupportedBoards;
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                boards = arduinoio.internal.TabCompletionHelper.getSupportedBoards;
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                boards = arduinoio.internal.ArduinoConstants.BLESupportedBoards;
            end
        end

        function devices = getSupportedBTDevices
            devices = arduinoio.internal.ArduinoConstants.SupportedBTDevices;
        end

        function rates = getBTSupportedBaudRates(type)
        %Return supported baud rates based on Bluetooth device
            rates = [];
            if arduinoio.internal.ArduinoConstants.BTSupportedBaudRates.isKey(double(type))
                rates = arduinoio.internal.ArduinoConstants.BTSupportedBaudRates(double(type));
            end
        end

        function libs = getDefaultLibraries(varargin)
            libs = arduinoio.internal.ArduinoConstants.DefaultLibraries;
        end
    end
end

% LocalWords:  Fio MKR Wi Bluetooth WPA WEP Uno Nano SPI Adafruit Bluefruit EZ BLE WROOM ADK nano
% LocalWords:  HC BEC
