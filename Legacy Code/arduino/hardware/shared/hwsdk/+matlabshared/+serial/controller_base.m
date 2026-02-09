
classdef (Abstract) controller_base < matlabshared.hwsdk.internal.base
    % User Interface
    %
    
    %   Copyright 2019-2023 The MathWorks, Inc.
    properties(Abstract, GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableSerialPortIDs double
    end
    % Developer Interface
    %
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base, ?matlabshared.sensors.internal.Accessor})
        buses = getAvailableSerialPortIDs(obj);
    end
    
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        serialPinsArray = getAvailableSerialPins(obj);
        maxSerialReadWriteBufferSize = getMaxSerialReadWriteBufferSize(obj);
        supportedBaudRates = getSupportedBaudRates(obj);
        supportedParityOptions = getSupportedParity(obj);
        supportedDataBitOptions = getSupportedDataBits(obj);
        supportedStopBitOptions = getSupportedStopBits(obj);
        supportedTimeOut = getSupportedTimeOut(~);
        availableSerialPrecisions = getAvailableSerialPrecisions(obj)
    end
    
    % Implementation Interface
    %
    methods(Abstract, Access = protected)
        ports = getAvailableSerialPortIDsHook(obj)
        serialPinsArray = getAvailableSerialPinsImpl(obj);
        supportedBaudRates = getSupportedBaudRatesHook(obj);
        supportedParityOptions = getSupportedParityHook(obj);
        supportedDataBitOptions = getSupportedDataBitsHook(obj);
        supportedStopBitOptions = getSupportedStopBitOptionsHook(obj);
        defaultBaudRate = getSerialDefaultBaudRateHook(obj);
        maxSerialBufferSize = getMaxSerialReadWriteBufferSizeHook(obj);
        availableSerialPrecisions = getAvailableSerialPrecisionsHook(obj);
        type = getSerialPortTypeImpl(obj);
    end
end
