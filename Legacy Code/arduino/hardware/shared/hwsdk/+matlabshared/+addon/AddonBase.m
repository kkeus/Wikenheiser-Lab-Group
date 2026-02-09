classdef (Abstract)AddonBase < matlabshared.hwsdk.internal.base
% ADDONBASE - Addon classes that do not define a library shall inherit from
% this base class to get Parent property.

% Copyright 2014-2018 The MathWorks, Inc.

    properties(Hidden)
        Parent
    end
end