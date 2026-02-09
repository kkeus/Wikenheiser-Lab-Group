classdef controller < handle
%

%   Copyright 2019-2022 The MathWorks, Inc.

%#codegen

    properties(GetAccess = public, SetAccess = protected)
        AvailableSPIBusIDs
    end

    properties(Access = protected)
        SPIDriverObj
    end

    methods(Abstract, Access = protected)
        spiBitRates = getSPIBitRatesImpl(obj, bus);
        spiBusIDs = getAvailableSPIBusIDsImpl(obj);
    end

    methods(Access = public)

        function spiDriverObj = getSPIDriverObj(obj, busNum)
            spiDriverObj = getSPIDriverObjHook(obj, busNum);
        end

        function spiDefaultBitRate = getSPIDefaultBitRate(obj, bus)
            spiDefaultBitRate = obj.getSPIDefaultBitRateHook(bus);
            assert(isscalar(spiDefaultBitRate) && isnumeric(spiDefaultBitRate));
            spiBitRates = obj.getSPIBitRates(bus);
            assert(ismember(spiDefaultBitRate, spiBitRates));
        end

        function spiBitRates = getSPIBitRates(obj, bus)
            spiBitRates = obj.getSPIBitRatesImpl(bus);
            assert(size(spiBitRates, 1)==1); % row based
            assert(isnumeric(spiBitRates));
        end

        function numSPIBuses = getNumSPIBuses(obj)
            numSPIBuses = obj.getNumSPIBusesHook();
            assert(isscalar(numSPIBuses) && isnumeric(numSPIBuses));
        end

        function availableSPIPrecisions = getAvailableSPIPrecisions(obj)
            availableSPIPrecisions = obj.getAvailableSPIPrecisionsHook;
        end

        function spiBusAlias = getSPIBusAlias(obj, bus)
            spiBusAlias = obj.getSPIBusAliasHook(bus);
        end

        function spiBusIDs = getAvailableSPIBusIDs(obj)
            spiBusIDs = obj.getAvailableSPIBusIDsImpl();
        end

        function pinNumber = validateSPIPinNumberHook(~, pin)
            pinNumber = pin;
        end
    end

    methods(Access = protected)

        function spiDriverObj = getSPIDriverObjHook(obj, ~)
            if isempty(obj.SPIDriverObj)
                obj.SPIDriverObj = matlabshared.devicedrivers.coder.SPI();
            end
            spiDriverObj = obj.SPIDriverObj;
        end

        function spiDefaultBitRate = getSPIDefaultBitRateHook(obj, bus)
            spiBitRates = obj.getSPIBitRates(bus);
            spiDefaultBitRate = spiBitRates(1);
        end

        function spiBusAlias = getSPIBusAliasHook(~, bus)
            spiBusAlias = bus;
        end

        function availableSPIPrecisions = getAvailableSPIPrecisionsHook(~)
            availableSPIPrecisions = {'uint8', 'uint16', 'uint32', 'uint64'};
        end
    end

end
