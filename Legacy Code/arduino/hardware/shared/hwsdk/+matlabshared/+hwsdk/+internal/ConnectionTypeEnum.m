%

%   Copyright 2017-2023 The MathWorks, Inc.

classdef ConnectionTypeEnum < double
    enumeration
        Serial    (0)
        WiFi      (1)
        BLE       (2)
        Bluetooth (3)
        PubSub    (4)
        Mock      (5)
    end

    methods
        function errorText = getErrorText(transport)
            m = '';
            errorText = '';
            switch(transport)
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                m = message('MATLAB:hwsdk:general:SerialErrorTextForInvalidAddressPCMac');
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                m = message('MATLAB:hwsdk:general:BluetoothErrorTextForInvalidAddressPCMac');
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                m = message('MATLAB:hwsdk:general:IPErrorTextForInvalidAddressPCMac');
              otherwise
                % No error message for Mock.
            end
            if ~isempty(m)
                errorText = m.getString();
            end
        end

        function connectionController = getConnectionController(transport)
            switch transport
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial
                connectionController = matlabshared.hwsdk.internal.connections.SerialConnectionController;
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth
                connectionController = matlabshared.hwsdk.internal.connections.BluetoothConnectionController;
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.WiFi
                connectionController = matlabshared.hwsdk.internal.connections.WiFiConnectionController;
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE
                connectionController = matlabshared.hwsdk.internal.connections.BLEConnectionController;
              case matlabshared.hwsdk.internal.ConnectionTypeEnum.PubSub
                connectionController = matlabshared.hwsdk.internal.connections.PubSubConnectionController;
            end
        end
    end
end
