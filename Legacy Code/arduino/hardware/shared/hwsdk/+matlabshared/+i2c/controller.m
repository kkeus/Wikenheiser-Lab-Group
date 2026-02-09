classdef controller < matlabshared.i2c.controller_base
%

%   Copyright 2017-2023 The MathWorks, Inc.
    properties(GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableI2CBusIDs
    end

    properties(Access = private, Constant = true)
        %         I2C BitRate Range for default 1kHz to 100kHz
        I2CBitRate = [1000 100000];
    end

    properties (Access = private)
        BusValidator
    end

    methods(Access = public, Hidden)
        function obj = controller()
            type = getI2CBusTypeImpl(obj);
            switch(type)
              case "numeric"
                obj.BusValidator = matlabshared.hwsdk.internal.NumericValidator;
              case "string"
                obj.BusValidator = matlabshared.hwsdk.internal.StringValidator;
              otherwise
                assert(false, 'This I2C Bus type is not supported');
            end
        end
    end

    properties(Access = protected)
        I2CDriverObj
    end

    methods(Sealed, Access = public)
        function addresses = scanI2CBus(obj, bus)
        % This is needed for data integration
            if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                dbus = "NA";
                if nargin >1
                    dbus = bus;
                end

                % Register on clean up for integrating all data.
                c = onCleanup(@() integrateData(obj,dbus));
            end
            try
                % Validations
                if nargin < 2
                    bus = obj.getHwsdkDefaultI2CBusIDHook();
                else
                    bus = obj.validateBus(bus);
                end
                try
                    addresses = obj.scanI2CBusHook(bus);
                catch e
                    if strcmpi(e.identifier,'ioserver:general:CFunctionNotFound')
                        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:libraryNotUploaded', 'I2C');
                    else
                        throwAsCaller(e);
                    end
                end
                validateAddressTypeHook(obj, addresses);
            catch e
                if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj,e.identifier);
                end
                throwAsCaller(e);
            end
        end
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base, ?matlabshared.sensors.internal.Accessor})

        function buses = getAvailableI2CBusIDs(obj)
            buses = getAvailableI2CBusIDsHook(obj);
        end
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})

        function i2cPinsArray = getAvailableI2CPins(obj)
            i2cPinsArray = getAvailableI2CPinsImpl(obj);
            assert(size(i2cPinsArray, 1)==1);    % row based
            validateI2CPinType(obj.PinValidator, i2cPinsArray);
        end

        function maxI2CAddress = getMaxI2CAddress(obj)
            maxI2CAddress = obj.getMaxI2CAddressHook();
            assert(isnumeric(maxI2CAddress));
            assert(isscalar(maxI2CAddress));
        end

        function i2cBitRateLimit = getI2CBitRateLimit(obj, bus)
            i2cBitRateLimit = obj.getI2CBitRateLimitHook(bus);
            assert(size(i2cBitRateLimit, 1)==1); % row based
            assert(isnumeric(i2cBitRateLimit));
            assert(i2cBitRateLimit(1) <= i2cBitRateLimit(2));
        end

        function i2cDefaultBitRate = getI2CDefaultBitRate(obj, bus)
            i2cDefaultBitRate = obj.getI2CDefaultBitRateHook(bus);
            assert(isscalar(i2cDefaultBitRate) && isnumeric(i2cDefaultBitRate));
        end

        function maxI2CReadWriteBufferSize = getMaxI2CReadWriteBufferSize(obj)
        % Assume 256 byte buffer length
            maxI2CReadWriteBufferSize = obj.getMaxI2CReadWriteBufferSizeHook();
            assert(isnumeric(maxI2CReadWriteBufferSize));
            assert(isscalar(maxI2CReadWriteBufferSize));
        end

        function availableI2CPrecisions = getAvailableI2CPrecisions(obj)
            availableI2CPrecisions = obj.getAvailableI2CPrecisionsHook;
            assert(isstring(availableI2CPrecisions));
        end

        function i2cDriverObj = getI2CDriverObj(obj)
            i2cDriverObj = getI2CDriverObjImpl(obj);
        end

        % To resolve ambiguous error message when no value is provided for
        % mandatory NV Pair, this validation need to be accessible by
        % controller.
        function status = validateI2CAddress(obj, address)
            try
                % specify valid datatypes
                validateattributes(address, {'uint8', 'double', 'string', 'char'}, {'nonempty'});
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidAddressType');
            end
            try
                % Specify scalar
                if ~ischar(address)
                    validateattributes(address, {'uint8', 'double', 'string'}, {'scalar'});
                end
                % Specify positive if numeric
                if isnumeric(address)
                    validateattributes(address, {'uint8', 'double'}, {'nonnegative', 'nonnan', 'real'});
                end
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidAddressType');
            end
            if isnumeric(address)
                if isinf(address)
                    obj.localizedError('MATLAB:hwsdk:general:invalidAddressValue', num2str(address));
                end
            end

            if isstring(address)
                address = char(address);
            end

            if isempty(address)
                obj.localizedError('MATLAB:hwsdk:general:invalidAddressValue', '');
            end

            if ischar(address) && (numel(address) > 1) % address should be greater one character long
                if strcmpi(address(1:2),'0x') % for example '0x65'
                    address = address(3:end);
                end
                if strcmpi(address(end), 'h')
                    address(end) = [];
                end
                try
                    address = hex2dec(address); % throw error for invalid hex characters
                catch
                    obj.localizedError('MATLAB:hwsdk:general:invalidAddressValue',num2str(address));
                end
            end

            try
                % validate format
                matlabshared.hwsdk.internal.validateHexParameterRanged('I2C device address', ...
                                                                       address, ...
                                                                       0, ...
                                                                       obj.getMaxI2CAddress);
            catch
                obj.localizedError('MATLAB:hwsdk:general:invalidAddressValue',strcat('0x',dec2hex(address)));
            end
            status = true;
        end

        function busValue = validateBus(obj, bus)
            busValue = validateI2CBus(obj.BusValidator, bus, obj.AvailableI2CBusIDs);
        end
    end


    methods(Access = protected)
        function validateAddressTypeHook(~, addresses)
        % ValidateAddressTypeHook(obj, addresses)
        % Validates the datatype of I2C addresses output from
        % scanI2CBus.
            if ~isempty(addresses)
                assert(isstring(addresses));
                assert(size(addresses, 1) == 1); % row based
            end
        end

        function buses = getAvailableI2CBusIDsHook(obj)
            i2cPinsArray = obj.getAvailableI2CPins();
            buses = [];
            if numel(i2cPinsArray) > 0
                buses = 1:numel(i2cPinsArray);
            end
        end

        function addresses = scanI2CBusHook(obj, bus)
            addresses = scanI2CBus(obj.Protocol,bus-1);
            if 0 == addresses
                pinStruct = getAvailableI2CPins(obj);
                obj.localizedError('MATLAB:hwsdk:general:scanI2CBusFailure', char(string(bus)), char(pinStruct(bus).SDAPin), char(pinStruct(bus).SCLPin));
            end
            numAddrsFound = length(addresses);
            if numAddrsFound ~= 0 % devices found
                                  % Creating a hex string row vector.
                addresses = ("0x" + string(dec2hex(uint8(addresses))))';
            else
                addresses = [];
            end
        end

        function bitRateLimit = getI2CBitRateLimitHook(obj, ~)
        % Assume I2C Standard bus speeds
            bitRateLimit = obj.I2CBitRate;
        end

        function defaultBitRate = getI2CDefaultBitRateHook(obj, bus)
            bitRateLimit = obj.getI2CBitRateLimitHook(bus);
            targetBitRate = 100000;
            if bitRateLimit(1) <= targetBitRate && bitRateLimit(2) >= targetBitRate
                defaultBitRate = targetBitRate;
            elseif bitRateLimit(1) >= targetBitRate
                defaultBitRate = bitRateLimit(1);
            else
                defaultBitRate = bitRateLimit(2);
            end
        end

        function maxI2CAddress = getMaxI2CAddressHook(~)
        % Assume I2C 7-bit Addressing
            maxI2CAddress = 2^7-1;
        end

        function maxI2CReadWriteBufferSize = getMaxI2CReadWriteBufferSizeHook(~)
        % Assume 256 byte buffer length
            maxI2CReadWriteBufferSize = 2^8;
        end

        function availableI2CPrecisions = getAvailableI2CPrecisionsHook(obj)
            availableI2CPrecisions = obj.getAvailablePrecisions;
        end

        function i2cDriverObj = getI2CDriverObjImpl(obj)
        % This is the default I2C device driver. Overload this method
        % in the hardware class to return a different driver if
        % required
            if(isempty(obj.I2CDriverObj))
                obj.I2CDriverObj = matlabshared.ioclient.peripherals.I2C;
            end
            i2cDriverObj = obj.I2CDriverObj;
        end
    end

    methods(Access = {?matlabshared.hwsdk.internal.base,?arduino.accessor.UnitTest})
        % Converts HWSDK I2C Bus ID to Hardware Bus Number
        function [busNumber, SCLPin, SDAPin] = getI2CBusInfoHook(obj, hwsdkI2CBusID)
        % GETI2CBUSINFOHOOK Fetches the I2C pins and bus number to be
        % sent to IOServer. Subsequent function to
        % getHwsdkDefaultI2CBusIDHook()
        % Hardware have to override this function if their default I2C
        % Bus ID is not 1.
            busNumber = getI2CBusNumber(obj.BusValidator, hwsdkI2CBusID);
            i2cPins = obj.getAvailableI2CPins();
            SCLPin = i2cPins(busNumber+1).SCLPin;
            SDAPin = i2cPins(busNumber+1).SDAPin;
        end

        function hwsdkDefaultI2CBusID = getHwsdkDefaultI2CBusIDHook(obj)
        % GETHWSDKDEFAULTI2CBUSIDHOOK Fetches the default I2C Bus ID.
        % HWSDK defaults the I2C Bus to 1 considering MATLAB indexing
        % which starts with 1.
        % Hardware can choose to override their default I2C Bus ID to
        % 0 and accordingly override getI2CBusInfoHook() to provide
        % right busNumber values to be sent to IOServer.
            hwsdkDefaultI2CBusID = getAvailableI2CBusIDs(obj);
            % It is possible that there are no I2C Buses available
            % dynamically - Raspi. It is also possible that only
            % intermediate buses are available. For example, i2c-0 may be
            % unavailable. But i2c-1 may be available. So, fetch the first
            % of what getAvailableI2CBusIDs provide.
            if ~isempty(hwsdkDefaultI2CBusID)
                if ischar(hwsdkDefaultI2CBusID)
                    hwsdkDefaultI2CBusID = string(hwsdkDefaultI2CBusID);
                end
                hwsdkDefaultI2CBusID = hwsdkDefaultI2CBusID (1);
            end
        end

        % Hardware inherits following methods to modify the property display
        function sclPin = getI2CSCLPinForPropertyDisplayHook(~, pin)
            sclPin = pin;
        end

        function sdaPin = getSDAPinForPropertyDisplayHook(~, pin)
            sdaPin = pin;
        end
    end

    methods(Access = {?matlabshared.hwsdk.internal.base,?matlabshared.sensors.sensorBase})

        % Hardware inherits following method to modify the object display
        function showI2CProperties(obj, Interface, I2CAddress, Bus, SCLPin, SDAPin, BitRate, showAll)
            if nargin < 2
                showAll = 0;
            end

            if showAll
                fprintf('             Interface: "%s"\n', Interface);
            end

            fprintf('            I2CAddress: %-1d ("0x%02s")\n', I2CAddress(1), dec2hex(I2CAddress(1)));
            for i = 2:numel(I2CAddress)
                fprintf('                      : %-1d ("0x%02s")\n',I2CAddress(i), dec2hex(I2CAddress(i)));
            end
            showI2CBus(obj.BusValidator, Bus);

            if isPinNumericHook(obj)
                fprintf('                SCLPin: %d\n', SCLPin);
                fprintf('                SDAPin: %d\n', SDAPin);
            else
                fprintf('                SCLPin: "%s"\n', SCLPin);
                fprintf('                SDAPin: "%s"\n', SDAPin);
            end

            if showAll
                fprintf('               BitRate: %d (bits/s)\n', BitRate);
            end

            fprintf('\n');
        end
    end
end

% LocalWords:  dev cdev matlabshared CBus CIs
