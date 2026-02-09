%

%   Copyright 2017-2023 The MathWorks, Inc.

classdef (Abstract) controller_base < matlabshared.hwsdk.internal.base
% User Interface
%
    properties(Abstract, GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableI2CBusIDs
    end

    methods(Abstract, Access = public)
        addresses = scanI2CBus(obj, bus);
    end

    % Developer Interface
    %
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        %         dev = i2cdev(obj, varargin);
        i2cPins = getAvailableI2CPins(obj, bus);
        maxI2CAddress = getMaxI2CAddress(obj);
        i2cBitRateLimit = getI2CBitRateLimit(obj, bus);
        i2cDefaultBitRate = getI2CDefaultBitRate(obj, bus);
        maxI2CReadWriteBufferSize = getMaxI2CReadWriteBufferSize(obj);
    end

    % Implementation Interface
    %
    methods(Abstract, Access = protected)
        buses = getAvailableI2CBusIDsHook(obj)
        i2cPinsArray = getAvailableI2CPinsImpl(obj);
        maxI2CAddress = getMaxI2CAddressHook(obj);
        i2cBitRateLimit = getI2CBitRateLimitHook(obj, bus);
        i2cDefaultBitRate = getI2CDefaultBitRateHook(obj, bus);
        maxI2CReadWriteBufferSize = getMaxI2CReadWriteBufferSizeHook(obj);
        i2cDriverObj = getI2CDriverObjImpl(obj);
        type = getI2CBusTypeImpl(obj);
    end
end

% LocalWords:  dev cdev
