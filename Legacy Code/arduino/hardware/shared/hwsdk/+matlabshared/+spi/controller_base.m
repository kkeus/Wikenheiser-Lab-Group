%

%   Copyright 2017-2023 The MathWorks, Inc.

classdef (Abstract) controller_base < matlabshared.hwsdk.internal.base
% User Interface
%
    properties(Abstract, GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableSPIBusIDs double
    end

    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base,?matlabshared.sensors.internal.Accessor})
        spiChipSelectPins = getAvailableSPIChipSelectPins(obj, bus);
    end
    % Developer Interface
    %
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        spiPins = getAvailableSPIPins(obj, bus);
        numSPIBuses = getNumSPIBuses(obj);
        spiBitRates = getSPIBitRates(obj, bus);
        spiDefaultBitRate = getSPIDefaultBitRate(obj, bus);
        maxSPIReadWriteBufferSize = getMaxSPIReadWriteBufferSize(obj);
        busAlias = getSPIBusAliasImpl(obj, bus, csPin);
    end

    % Implementation Interface
    %
    methods(Abstract, Access = protected)
        spiPins = getAvailableSPIPinsImpl(obj, bus);
        spiBitRates = getSPIBitRatesImpl(obj, bus);
    end
end

% LocalWords:  dev spidev
