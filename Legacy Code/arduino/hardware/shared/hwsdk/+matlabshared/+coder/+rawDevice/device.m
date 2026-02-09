classdef device < handle
    
    % Copyright 2019-2021 The MathWorks, Inc.
    
    %#codegen
    
    properties(Access = protected)
        Parent
    end
    
    properties(Access = protected, Constant = true)
        SIZEOF = struct('int8', 1, 'uint8', 1, 'int16', 2, 'uint16', 2, 'int32', 4, 'uint32', 4, 'int64', 8, 'uint64', 8)
    end
    
    methods
        function obj = device(varargin)
            parent = varargin{1};
            coder.internal.errorIf(~isa(parent, 'matlabshared.coder.hwsdk.controller')&&...
                ~isa(parent, 'matlabshared.coder.i2c.controller')&& ...
                ~isa(parent, 'matlabshared.coder.spi.controller')&&...
                ~isa(parent, 'matlabshared.coder.serial.controller'), 'MATLAB:hwsdk:general:invalidHwObj');
            obj.Parent = parent;
        end
    end
    
    methods(Abstract, Access = public)
        data = read(obj, varargin);
        write(obj, varargin);
    end
end