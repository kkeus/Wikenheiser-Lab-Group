function maxBytes = getMaxBufferSizeForBoard(board)
    % GETMAXBUFFERSIZEFORBOARD - Return the maximum buffer size for a given arduino board.
    
    % Copyright 2024 The MathWorks, Inc.

    if ismember(board, {'Mega2560', 'MegaADK', 'Due','MKR1000','MKR1010', 'MKRZero',...
            'Nano33IoT','Nano33BLE','ESP32-WROOM-DevKitV1','ESP32-WROOM-DevKitC','NanoRP2040Connect','RaspberryPiPico','RaspberryPiPicoW'})
        maxBytes = arduinoio.internal.ArduinoConstants.MaxBufferSizeMegaDueMKRMbed;
    elseif ismember(board, {'Uno','Nano3','DigitalSandbox','ProMini328_3V','ProMini328_5V'})
        maxBytes = arduinoio.internal.ArduinoConstants.MaxBufferSize2KRAMBoards;
    elseif ismember(board, {'UnoR4WiFi','UnoR4Minima'})
        maxBytes = arduinoio.internal.ArduinoConstants.MaxBufferSizeRenesasUno;
    else
        maxBytes = arduinoio.internal.ArduinoConstants.MaxBufferSizeOtherBoards;
    end
end
