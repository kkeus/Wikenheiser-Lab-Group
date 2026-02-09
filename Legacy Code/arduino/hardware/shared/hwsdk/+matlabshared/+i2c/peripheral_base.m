
%   Copyright 2017-2021 The MathWorks, Inc.

classdef (Abstract) peripheral_base < matlabshared.hwsdk.internal.base 
        
    % User Interface
    %
%     properties(Abstract, Dependent)
%         I2CAddress
%         Bus
%         SCLPin
%         SDAPin
%         BitRate
%     end

    % Developer Interface
    %
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        i2cAddressSpace = getI2CAddressSpace(obj);
    end

    % Implementation Interface
    %
    methods(Abstract, Access = protected)
        i2cAddressSpace = getI2CAddressSpaceImpl(obj);
        defaultI2CAddress = getI2CDefaultAddressHook(obj);
    end
end

% LocalWords:  SCL SDA CAddress
