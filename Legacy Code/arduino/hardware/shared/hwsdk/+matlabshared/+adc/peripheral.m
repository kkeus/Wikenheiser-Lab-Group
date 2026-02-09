
%   Copyright 2017-2021 The MathWorks, Inc.

classdef peripheral < matlabshared.adc.peripheral_base
    
    properties(GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        Interface matlabshared.hwsdk.internal.InterfaceEnum
        AnalogPin string
    end
    
    methods(Hidden, Access = public)
        function obj = peripheral(varargin)
            assert(isa(obj, 'matlabshared.sensors.sensor'));
        end
    end
end

% LocalWords:  matlabshared
