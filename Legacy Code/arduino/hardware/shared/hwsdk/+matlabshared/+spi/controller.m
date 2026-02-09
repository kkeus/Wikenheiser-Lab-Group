classdef controller < matlabshared.spi.controller_base
%

%   Copyright 2017-2023 The MathWorks, Inc.

    properties(Hidden, GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableSPIBusIDs double
    end

    properties (Access = private)
        PreviousSettingSPI
    end

    properties(Access = protected)
        SPIDriverObj = [];
    end

    methods(Access = public, Hidden)
        function obj = controller()
        end
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base,?matlabshared.sensors.internal.Accessor})
            function spiChipSelectPins = getAvailableSPIChipSelectPins(obj)
            spiChipSelectPins = obj.getAvailableSPIChipSelectPinsHook();
            assert(size(spiChipSelectPins, 1)==1);    % row based
            assert(isstring(spiChipSelectPins));
        end
    end
    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})

        function spiPins = getAvailableSPIPins(obj)
            spiPins = obj.getAvailableSPIPinsImpl();
            if ~isempty(spiPins)
                assert(size(spiPins, 1)==1);    % row based
                validateSPIPinType(obj.PinValidator, spiPins);
            end
        end

        function buses = getAvailableSPIBusIDs(obj)
            spiPinsArray = obj.getAvailableSPIPins();
            buses = [];
            if numel(spiPinsArray) > 0
                if isnumeric(spiPinsArray)
                    if(spiPinsArray == 0)
                        buses = 0;
                    end
                else
                    buses = 1:numel(spiPinsArray);
                end
            end
        end

        function numSPIBuses = getNumSPIBuses(obj)
            numSPIBuses = obj.getNumSPIBusesHook();
            assert(isscalar(numSPIBuses) && isnumeric(numSPIBuses));
        end

        function spiBitRates = getSPIBitRates(obj, bus)
            spiBitRates = obj.getSPIBitRatesImpl(bus);
            assert(size(spiBitRates, 1)==1); % row based
            assert(isnumeric(spiBitRates));
        end

        function spiDefaultBitRate = getSPIDefaultBitRate(obj, bus)
            spiDefaultBitRate = obj.getSPIDefaultBitRateHook(bus);
            assert(isscalar(spiDefaultBitRate) && isnumeric(spiDefaultBitRate));
            spiBitRates = obj.getSPIBitRates(bus);
            assert(ismember(spiDefaultBitRate, spiBitRates));
        end

        function maxSPIReadWriteBufferSize = getMaxSPIReadWriteBufferSize(obj)
            maxSPIReadWriteBufferSize = obj.getMaxSPIReadWriteBufferSizeHook();
            assert(isnumeric(maxSPIReadWriteBufferSize));
            assert(isscalar(maxSPIReadWriteBufferSize));
        end

        function availableSPIPrecisions = getAvailableSPIPrecisions(obj)
            availableSPIPrecisions = obj.getAvailableSPIPrecisionsHook;
            assert(isstring(availableSPIPrecisions));
        end

        function [speedMatchFlag, formatMatchFlag] = checkPreviousSettingMatch(obj, bitRate, bitOrder, spiMode)
            formatMatchFlag = true;
            speedMatchFlag = true;
            if isempty(obj.PreviousSettingSPI)
                temp.BitOrder = bitOrder;
                temp.BitRate = bitRate;
                temp.SPIMode = spiMode;
                obj.PreviousSettingSPI = temp;
            else
                if ~isequal(bitRate, obj.PreviousSettingSPI.BitRate)
                    speedMatchFlag = false;
                    % Store current settings
                    obj.PreviousSettingSPI.BitRate = bitRate;
                end
                if ~isequal(bitOrder, obj.PreviousSettingSPI.BitOrder) || ~isequal(spiMode, obj.PreviousSettingSPI.SPIMode)
                    formatMatchFlag = false;
                    % Store current settings
                    obj.PreviousSettingSPI.BitOrder = bitOrder;
                    obj.PreviousSettingSPI.SPIMode = spiMode;
                end
            end
        end

        function spiDriverObj = getSPIDriverObj(obj, busNum)
        % This method is called by SPI device object to get the SPI
        % driver object, which is used for IO operation.
            spiDriverObj = getSPIDriverObjHook(obj, busNum);
        end

        % To resolve ambiguous error message when no value is provided for
        % mandatory NV Pair, this validation need to be accessible by
        % controller.
        function status = validateSPIChipSelectPin(obj, pin)
            status = false;
            if isstring(pin)
                pin = char(pin);
            end
            validPins = obj.getAvailableSPIChipSelectPinsHook();
            if ischar(pin)
                iPin = find(strcmpi(pin, validPins), 1);
                if ~isempty(iPin)
                    status = true;
                    return;
                end
            end
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidChipSelectPin', 'SPI', matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(validPins));
        end
    end

    methods(Access = protected)

        function spiChipSelectPins = getAvailableSPIChipSelectPinsHook(obj)
            spiChipSelectPins = [];
            if isa(obj, 'matlabshared.dio.controller')
                spiChipSelectPins = obj.getAvailableDigitalPins();
            end
        end

        function spiDefaultBitRate = getSPIDefaultBitRateHook(obj, bus)
            spiBitRates = obj.getSPIBitRates(bus);
            spiDefaultBitRate = spiBitRates(1);
        end

        function maxSPIReadWriteBufferSize = getMaxSPIReadWriteBufferSizeHook(~)
        % Assume 256 byte buffer length
            maxSPIReadWriteBufferSize = 2^8;
        end

        function enableSPIHook(obj, ~)
            if isa(obj, 'matlabshared.hwsdk.controller_base')
            else
                error('Not implemented');
            end
        end

        function disableSPIHook(obj, ~)
            if isa(obj, 'matlabshared.hwsdk.controller_base')
            else
                error('Not implemented');
            end
        end

        function availableSPIPrecisions = getAvailableSPIPrecisionsHook(~)
            availableSPIPrecisions = ["uint8", "uint16", "uint32", "uint64"];
        end

        function spiDriverObj = getSPIDriverObjHook(obj, ~)
        % Returns the SPI device driver to be used by SPI device object
        % for IO operation. If the object is not created, then create.
        % Else, send the one already created and stored in
        % obj.SPIDriverObj
            if isempty(obj.SPIDriverObj)
                obj.SPIDriverObj = matlabshared.ioclient.peripherals.SPI;
            end
            spiDriverObj = obj.SPIDriverObj;
        end
    end

    methods(Access = private)
        function bus = validateBus(obj, bus)
            if ~(isnumeric(bus) && isscalar(bus) && ismember(bus, obj.AvailableSPIBusIDs))
                buses = matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableSPIBusIDs);
                error(['Invalid I2C bus specified. Valid values are ' buses]);
            end
        end
    end

    methods(Access = {?matlabshared.hwsdk.internal.base,?arduino.accessor.UnitTest})
        % Hardware inherits following methods to modify the object display
        function showSPIProperties(obj, Interface, SPIChipSelectPin, SCLPin, SDIPin, SDOPin, SPIMode, ActiveLevel, BitOrder, BitRate, showAll)
            if nargin < 2
                showAll = 0;
            end

            obj.showSPIPropertiesHook(Interface, SPIChipSelectPin, SCLPin, SDIPin, SDOPin, SPIMode, ActiveLevel, BitOrder, BitRate, showAll);
        end

        % Hardware inherits following methods to modify the property display
        function csPin = getCSPinForPropertyDisplayHook(~, pin)
            csPin = pin;
        end

        function sclPin = getSPISCLPinForPropertyDisplayHook(~, pin)
            sclPin = pin;
        end

        function sdiPin = getSDIPinForPropertyDisplayHook(~, pin)
            sdiPin = pin;
        end

        function sdoPin = getSDOPinForPropertyDisplayHook(~, pin)
            sdoPin = pin;
        end
    end

    methods(Hidden,Access = protected)
        function showSPIPropertiesHook(obj,Interface, SPIChipSelectPin, SCLPin, SDIPin, SDOPin, SPIMode, ActiveLevel, BitOrder, BitRate, showAll)
        % This method is used for displaying SPI device object. The
        % hardware object inherits this method to modify the object
        % display.

            fprintf('             Interface: "%s"\n', Interface);
            fprintf('      SPIChipSelectPin: "%s"\n', SPIChipSelectPin);
            showSPIPins(obj.PinValidator, SCLPin, SDIPin, SDOPin);

            if showAll
                fprintf('               SPIMode: %d\n', SPIMode);
                fprintf('           ActiveLevel: "%s"\n', ActiveLevel);
                fprintf('              BitOrder: "%s"\n', BitOrder);
                fprintf('               BitRate: %d (bits/s)\n', BitRate);
            end

            fprintf('\n');
        end
    end
end

% LocalWords:  dev spidev matlabshared spi dio hwsdk
