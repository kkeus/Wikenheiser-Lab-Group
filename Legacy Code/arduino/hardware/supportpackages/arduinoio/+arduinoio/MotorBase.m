classdef (Abstract)MotorBase < matlabshared.hwsdk.internal.base
% MOTORBASE - Addon motor classes shall inherit from this base class to get
% Parent and Pins properties

% Copyright 2014-2018 The MathWorks, Inc.

    properties(SetAccess = protected)
        MotorNumber
    end
    
    properties(Access = protected)
        Pins
    end
end