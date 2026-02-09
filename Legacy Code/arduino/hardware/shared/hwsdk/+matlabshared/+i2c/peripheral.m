
%   Copyright 2017-2021 The MathWorks, Inc.

classdef (Abstract) peripheral < matlabshared.i2c.peripheral_base
    % User Interface
    %
    
    % Developer Interface
    %
    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})
        function i2cAddressSpace = getI2CAddressSpace(obj)
            i2cAddressSpace = getI2CAddressSpaceImpl(obj);
            assert(isnumeric(i2cAddressSpace));
            assert(size(i2cAddressSpace, 1)==1); % row based
        end
    end

    methods(Hidden, Access = public)
        function obj = peripheral(varargin)
            assert(isa(obj, 'matlabshared.sensors.sensor'));
        end
    end

    methods(Access = private)
        function result = validateI2CAddress(obj, parent, address)
            try
                result = matlabshared.hwsdk.internal.validateHexParameterRanged('I2C device address', ...
                    address, ...
                    0, ...
                    parent.Parent.getMaxI2CAddress);

                i2cAddressSpace = obj.getI2CAddressSpaceImpl();
                if isempty(i2cAddressSpace)
                    return;
                end
                
                deviceI2CAddressSpace = "";
                if ~ismember(result, i2cAddressSpace)
                    for i = 1 : numel(i2cAddressSpace) - 1
                        deviceI2CAddressSpace = deviceI2CAddressSpace + ...
                            sprintf('%-1d(0x%02s), ', i2cAddressSpace(i), dec2hex(i2cAddressSpace(i)));
                    end
                    deviceI2CAddressSpace = deviceI2CAddressSpace + ...
                        sprintf('%-1d(0x%02s)', i2cAddressSpace(end), dec2hex(i2cAddressSpace(end)));
                    error(['Valid I2C addresses for this device are: ' char(deviceI2CAddressSpace)]);
                end
            catch e
                throwAsCaller(e);
            end
        end
    end
end

% LocalWords:  matlabshared
