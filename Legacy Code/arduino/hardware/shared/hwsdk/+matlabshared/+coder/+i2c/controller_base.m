classdef (Abstract)controller_base < handle
    
    % Copyright 2019-2021 The MathWorks, Inc.
    
    %#codegen
    
    % Implementation Interface
    %
    methods(Abstract, Access = protected)
        i2cDriverObj = getI2CDriverObjImpl(obj);
    end
    
    methods(Abstract, Hidden, Access = public)
        busId = getI2CBusInfo(obj, HWSDKBusNum);
        i2cDriverObj = getI2CDriverObj(obj, busNum)
    end
end