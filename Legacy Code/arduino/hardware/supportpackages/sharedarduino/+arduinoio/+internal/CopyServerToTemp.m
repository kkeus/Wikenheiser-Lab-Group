function CopyServerToTemp(connectionType,ArduinoServerDir)
%   Copyright 2017-2019 The MathWorks, Inc.

    ioServerRoot = matlabshared.ioclient.internal.getIOServerRootDir();
    %copy all IOserver Includes
    ioServerIncRoot = fullfile(ioServerRoot,'ioserver','inc');
    copyfile(ioServerIncRoot,ArduinoServerDir);
    %selectively copy IOServer source files   
    ioServerSrcRoot = fullfile(ioServerRoot,'ioserver','src');
    copyfile(fullfile(ioServerSrcRoot,'IO_packet.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_server.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_standardperipherals.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_wrapperAnalogInput.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_wrapperDigitalIO.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_wrapperI2C.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_wrapperPWM.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_wrapperSPI.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_wrapperSCI.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_debug.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_checksum.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'PeripheralToHandle.c'), ArduinoServerDir, 'f');
	copyfile(fullfile(ioServerSrcRoot,'IO_utilities.c'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'IO_addOn.cpp'), ArduinoServerDir, 'f');
    copyfile(fullfile(ioServerSrcRoot,'hardware.cpp'), ArduinoServerDir, 'f'); 
    % copy all SVD includes
    svdRoot = matlabshared.svd.internal.getRootDir;            
    svdIncRoot = fullfile(svdRoot,'include');
    copyfile(svdIncRoot,ArduinoServerDir);
    sharedArduinoRoot = arduinoio.SharedArduinoRoot;
    arduinoServerRoot = fullfile(sharedArduinoRoot,'target','server');
    copyfile(arduinoServerRoot,ArduinoServerDir);  
    connectionTypeRoot = fullfile(sharedArduinoRoot,'target','transport');
    if ismember(connectionType, [matlabshared.hwsdk.internal.ConnectionTypeEnum.Serial, matlabshared.hwsdk.internal.ConnectionTypeEnum.Bluetooth])
        copyfile(fullfile(connectionTypeRoot,'rtiostream_serial_daemon.cpp'),ArduinoServerDir, 'f');
    elseif ismember(connectionType,matlabshared.hwsdk.internal.ConnectionTypeEnum.BLE)
        copyfile(fullfile(connectionTypeRoot,'rtiostream_ble.cpp'),ArduinoServerDir, 'f');
    else
        copyfile(fullfile(connectionTypeRoot,'rtiostream_wifi.cpp'),ArduinoServerDir, 'f');
    end
    
end