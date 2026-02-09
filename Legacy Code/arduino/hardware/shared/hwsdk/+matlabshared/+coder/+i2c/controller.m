classdef controller < matlabshared.coder.i2c.controller_base
%

% Copyright 2019-2022 The MathWorks, Inc.

%#codegen

    properties(Access = protected)
        I2CDriverObj = {};
    end

    properties(Access = private, Constant = true)
        %         I2C BitRate Range for default 1kHz to 100kHz
        I2CBitRate = [1000 100000];
    end

    methods(Access = protected)
        function busId = getI2CBusInfoHook(~, HWSDKBusNum)
            busId = HWSDKBusNum - 1;
        end

        function i2cDriverObj = getI2CDriverObjImpl(~, ~)
        % This is the default I2C device driver. Overload this method
        % in the hardware class to return a different driver if
        % required
            i2cDriverObj = matlabshared.devicedrivers.coder.I2C;
        end

        function availableI2CPrecisions = getAvailableI2CPrecisionsHook(obj)
            availableI2CPrecisions = obj.getAvailablePrecisions();
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

        function bitRateLimit = getI2CBitRateLimitHook(obj, ~)
        % Assume I2C Standard bus speeds
            bitRateLimit = obj.I2CBitRate;
        end

        function maxI2CAddress = getMaxI2CAddressHook(~)
            maxI2CAddress = 2^7;
        end

        function minI2CAddress = getMinI2CAddressHook(~)
            minI2CAddress = 0;
        end
    end

    methods(Abstract, Access = protected)
        busIDs = getAvailableI2CBusIDsImpl(obj);
    end

    methods(Hidden, Access = public)
        function busIDs =  getAvailableI2CBusIDs(obj)
            busIDs = getAvailableI2CBusIDsImpl(obj);
        end

        function busId = getI2CBusInfo(obj, HWSDKBusNum)
            busId = getI2CBusInfoHook(obj, HWSDKBusNum);
        end

        function i2cDriverObj = getI2CDriverObj(obj, busNum)
        % Add external C/C++ library
            i2cDriverObj = getI2CDriverObjImpl(obj, busNum);
        end

        function hwsdkDefaultI2CBusID = getHwsdkDefaultI2CBusIDHook(~)
        % GETHWSDKDEFAULTI2CBUSIDHOOK Fetches the default I2C Bus ID.
        % HWSDK defaults the I2C Bus to 1 considering MATLAB indexing
        % which starts with 1.
        % Hardware can choose to override their default I2C Bus ID to
        % 0 and accordingly override getI2CBusInfoHook() to provide
        % right busNumber values to be sent to IOServer.
            hwsdkDefaultI2CBusID = 1;
        end

        function i2cDefaultBitRate = getI2CDefaultBitRate(obj, bus)
            i2cDefaultBitRate = obj.getI2CDefaultBitRateHook(bus);
        end

        function maxI2CAddress = getMaxI2CAddress(obj)
            maxI2CAddress = getMaxI2CAddressHook(obj);
            coder.internal.assert(isnumeric(maxI2CAddress), 'MATLAB:hwsdk:general:ParamNotNumeric', 'maximum I2C Address');
            coder.internal.assert(isscalar(maxI2CAddress), 'MATLAB:hwsdk:general:ParamNotScalar', 'maximum I2C Address');
        end

        function minI2CAddress = getMinI2CAddress(obj)
            minI2CAddress = getMinI2CAddressHook(obj);
            coder.internal.assert(isnumeric(minI2CAddress), 'MATLAB:hwsdk:general:ParamNotNumeric', 'minimum I2C Address');
            coder.internal.assert(isscalar(minI2CAddress), 'MATLAB:hwsdk:general:ParamNotScalar', 'minimum I2C Address');
        end

        function availableI2CPrecisions = getAvailableI2CPrecisions(obj)
            availableI2CPrecisions = obj.getAvailableI2CPrecisionsHook();
        end

        function pinNumber = validateI2CPinNumberHook(~, pin)
            pinNumber = pin;
        end
    end
end
