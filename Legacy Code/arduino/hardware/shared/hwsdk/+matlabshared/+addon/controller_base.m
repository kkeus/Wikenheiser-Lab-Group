classdef (Abstract) controller_base < matlabshared.hwsdk.internal.base
    % User Interface
    %

    %   Copyright 2017-2021 The MathWorks, Inc.

    properties(Abstract, GetAccess = public, SetAccess={?matlabshared.hwsdk.internal.base})
        Libraries
    end
    
    methods(Abstract, Access = public)
        addonObj = addon(obj, libname, varargin);
    end

    % Internal Interface
    %
    methods(Access={?matlabshared.hwsdk.internal.base})
        libraryList = getAllLibraries(obj);
    end
    
    % Developer Interface
    %
    methods(Abstract, Access=protected)
        [basePackageName] = getBasePackageNameImpl(obj);
    end
end