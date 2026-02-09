
%   Copyright 2017-2021 The MathWorks, Inc.

classdef (Abstract) peripheral_base < matlabshared.hwsdk.internal.base

    % User Interface
    %
    properties(Abstract, GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AnalogPin string
    end
    
end