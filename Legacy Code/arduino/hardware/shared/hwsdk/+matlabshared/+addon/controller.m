classdef controller < matlabshared.addon.controller_base
%

%   Copyright 2017-2022 The MathWorks, Inc.
    properties(GetAccess = public, SetAccess={?matlabshared.hwsdk.internal.base})
        Libraries
    end

    properties(Access={?matlabshared.hwsdk.internal.base})
        LibraryIDs
    end

    methods
        % HWSDK displays a string array. Some hardware might require a
        % different type of display. Since a Getter cannot be
        % inherited, a trip is provided here which the individual hardware
        % can make use of.
        function libraries = get.Libraries(obj)
            libraries =  getLibrariesForPropertyDisplayHook(obj, obj.Libraries);
        end
    end

    methods(Access = protected)
        % Hardware inherits this method to modify the property display
        function libraries = getLibrariesForPropertyDisplayHook(~, libs)
            libraries = libs;
        end
    end

    methods(Access = public, Hidden)
        function obj = controller()
            obj.LibraryIDs = [];
        end
    end

    methods(Sealed, Access = public)
        function addonObj = addon(obj, libname, varargin)
            try
                % This is needed for integrating the library name for addon
                if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    if nargin < 1
                        dlibname = 'NA';
                    else
                        dlibname = libname;
                    end
                    % Register on clean up for integrating all data.
                    c = onCleanup(@() integrateData(obj,dlibname));
                end
                if isempty(getValidAddonLibraries(obj))
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:noAddonLibraryUploaded');
                else
                    givenLibrary = [];
                    % accept string type libname, but convert to character vector
                    if isstring(libname)
                        libname = char(libname);
                    end
                    if ~ischar(libname)
                        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidAddonLibraryType');
                    else
                        givenLibrary = strrep(libname, '\', '/');
                        try
                            givenLibrary = validatestring(givenLibrary, getValidAddonLibraries(obj)); % check given libraries all exist
                        catch
                            validAddonLibs = getValidAddonLibraries(obj);
                            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidAddonLibraryValue', libname, strjoin(validAddonLibs, ', '));
                        end
                    end
                    constructCmd = strcat(obj.getLibraryClassName(givenLibrary), '(obj, varargin{:})');
                    addonObj = eval(constructCmd);
                end
            catch e
                if isequal(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    validAddonLibs = getValidAddonLibraries(obj);
                    id = 'MATLAB:hwsdk:general:invalidAddonLibraryValue';
                    e = MException(id, getString(message(id, strrep(libname,'\', '\\'), strjoin(validAddonLibs, ', '))));
                end
                if isa(obj,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj,e.identifier);
                end
                throwAsCaller(e);
            end
        end
    end

    methods(Access = {?matlabshared.hwsdk.internal.base})
        function libraries = getDefaultLibraries(obj)
            libraries = obj.getDefaultLibrariesHook();
            if ~isempty(libraries)
                assert(isstring(libraries) && ...
                       size(libraries, 1)==1, ...
                       'ASSERT: getDefaultLibrariesHook must return a row based string array'); % row based
            end
        end

        function outstr = getLibraryClassName(obj, libName)
        % GETLIBRARYCLASSNAME - Return the name of the class that defines the given
        % library. The returning string contains the package names as well.

            outstr = '';
            [basePackageName] = getBasePackageNameImpl(obj);
            assert(isstring(basePackageName) && ...
                   all(size(basePackageName)==[1 1]), ...
                   'ASSERT: getBasePackageNameImpl must return a string');
            addonPackageName = basePackageName + "addons";
            addonList = matlabshared.hwsdk.internal.findSubClasses(char(addonPackageName), 'matlabshared.addon.LibraryBase', true);

            for libClassCount = 1:length(addonList)
                theList = addonList{libClassCount};
                thePropList = theList.PropertyList;
                theLibraryName = obj.searchDefaultPropertyValue(thePropList, 'LibraryName');
                if strcmp(libName, theLibraryName)
                    outstr = theList.Name;
                    break;
                end
            end

        end

        function libs = getValidAddonLibraries(obj)
            libs = [];
            temp = zeros(1,length(obj.Libraries));
            for libCount = 1:length(temp)
                if contains(obj.Libraries(libCount), '/')
                    temp(libCount) = true;
                end
            end
            for libCount = 1:length(temp)
                if temp(libCount)
                    libs = [libs, obj.Libraries(libCount)]; %#ok<AGROW>
                end
            end
        end

        function libraryList = getAllLibraries(obj)
            [basePackageName] = getBasePackageNameImpl(obj);
            assert(isstring(basePackageName) && ...
                   all(size(basePackageName)==[1 1]), ...
                   'ASSERT: getBasePackageNameImpl must return a string');
            addonPackageName = basePackageName + "addons";
            superclassName = "matlabshared.addon.LibraryBase";
            baseList = matlabshared.hwsdk.internal.findSubClasses(char(basePackageName), char(superclassName), true);
            if isa(obj, 'matlabshared.pwm.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.pwm', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.adc.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.adc', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.i2c.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.i2c', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.spi.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.spi', char(superclassName), true)'];
            end
            if isa(obj, 'matlabshared.serial.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.serial', char(superclassName), true)'];
            end
            if ~isempty(what(char(addonPackageName)))
                addonList = matlabshared.hwsdk.internal.findSubClasses(char(addonPackageName), char(superclassName), true);
            else
                addonList =[];
            end
            allList = [baseList; addonList];
            libraryList = {};
            for libClassCount = 1:length(allList)
                thePropList = allList{libClassCount}.PropertyList;
                for propCount = 1:length(thePropList)
                    % check classes that have defined constant LibraryName - e.g
                    % those that are library classes
                    theProp = thePropList(propCount);
                    % If the current property's name is 'LibraryName' and it has a
                    % default value, then it defines a new library
                    if strcmp(theProp.Name, 'LibraryName') && theProp.HasDefault
                        definingClass = theProp.DefiningClass;
                        packageNames = strsplit(definingClass.Name, '.');
                        vendorPackageName = packageNames{end-1};
                        % check vendor package name to form library name character vector
                        % convert string type theProp.DefaultValue(LibraryName) to character vector
                        if isstring(theProp.DefaultValue)
                            libName = char(theProp.DefaultValue);
                        else
                            libName = theProp.DefaultValue;
                        end
                        if ~strcmp(vendorPackageName, basePackageName) && strcmp(packageNames{1},addonPackageName) % class within arduinoioaddons.VENDORNAME
                            libName = strrep(libName, '\', '/');
                            if contains(libName, '/')
                                temp = strsplit(libName, '/');
                                if strcmpi(vendorPackageName, temp{1})
                                    libraryList = [libraryList, libName]; %#ok<AGROW>
                                end
                            end
                        else
                            libraryList = [libraryList, libName]; %#ok<AGROW>
                        end
                        break;
                    end
                end
            end
            libraryList = unique(libraryList');
            try
                if isempty(libraryList)
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:IDENotInstalled');
                end
            catch e
                throwAsCaller(e);
            end
        end

        function newLibs = validateLibraries(obj, libs)
            libraryList = obj.getAllLibraries();
            validateFcn = @(x) validatestring(char(x), libraryList, 'matlabshared\addon\controller', 'libraries');
            libs = strrep(libs, '\', '/');
            givenLibs = string(arrayfun(validateFcn, libs, 'UniformOutput', false)); % check given libraries all exist
            newLibs = obj.getLibrariesAndDependentLibraries(givenLibs);
        end
    end

    methods(Access = protected)
        function libraries = getDefaultLibrariesHook(~)
            libraries = [];
        end

        function baseList = getBaseLibrariesHook(obj)
            superclassName = "matlabshared.addon.LibraryBase";
            baseList = [];
            if isa(obj, 'matlabshared.pwm.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.pwm', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.adc.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.adc', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.i2c.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.i2c', char(superclassName), true)];
            end
            if isa(obj, 'matlabshared.spi.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.spi', char(superclassName), true)'];
            end

            if isa(obj, 'matlabshared.serial.controller')
                baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.serial', char(superclassName), true)'];
            end
        end

        % Hook that searches for alternate library headers for the specified library and boards
        % Depending upon the implementation in subclasses, it may return list of such libraries or just a logical flag
        function alternateLibraryHeaderAvailable = areAlternateLibraryHeadersAvailableHook(~)
        % The overriding definitions should accept the board specific object as the input
        % areAlternateLibraryHeadersAvailableHook(obj)
        % and should output either logical true or false
            alternateLibraryHeaderAvailable = [];
        end

    end

    methods(Access = {?matlabshared.hwsdk.internal.base, ?arduino.internal.accessor})
        function fullLibs = getLibrariesAndDependentLibraries(obj, libs)
        % getLibrariesAndDependentLibraries - Return the full list of libraries including
        % dependent libraries based on the input library list.

            fullLibs = {};
            libraryList = obj.getAllLibraries();

            for libCount = 1:numel(libs)
                depLibs = obj.getDefaultLibraryPropertyValue(libs(libCount), 'DependentLibraries');
                if ~isempty(depLibs)
                    try
                        validateFcn = @(x) validatestring(char(x), libraryList);
                        depLibs = string(arrayfun(validateFcn, depLibs, 'UniformOutput', false));
                    catch
                        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:missingDependentLibraries', libs{libCount}, strjoin(depLibs, ', '));
                    end
                    newLibs = [libs(libCount), depLibs];
                else
                    newLibs = libs(libCount);
                end
                fullLibs = [fullLibs, newLibs]; %#ok<AGROW>
            end
            if ~isempty(fullLibs)
                fullLibs = unique(fullLibs);
            end
        end

        function value = findMatchingLibraryAndReturnDefaultPropertyValue(obj, allLibList, oldLib, propName, varargin)
        % Return the input library plus its dependent libs, if any

        % varargin{1}, if provided, should contain a logical flag that tells if the specified
        % library oldLib has an alternate header file associated with it for the
        % board specified in the obj
        % set default value of alternateLibraryHeaderAvailable to false
            alternateLibraryHeaderAvailable = false;

            if nargin > 4
                alternateLibraryHeaderAvailable = varargin{1};
                assert(islogical(alternateLibraryHeaderAvailable) && ...
                       all(size(alternateLibraryHeaderAvailable)==[1 1]), ...
                       'ASSERT: alternateLibraryHeaderAvailable must be a logical true or false');
                % get the object specific property name containing the alternate
                % header file name
                alternateHeaderPropName = "AlternateLibraryHeaderFiles";
            end
            value = [];
            for libClassCount = 1:length(allLibList)
                % get current class's library name
                thePropList = allLibList{libClassCount}.PropertyList;
                libName = obj.searchDefaultPropertyValue(thePropList, 'LibraryName');
                if strcmp(libName, oldLib)
                    if alternateLibraryHeaderAvailable
                        % check if an alternate header file is available for the oldLib
                        try
                            if ismember(alternateHeaderPropName, {thePropList.Name})
                                value = obj.searchDefaultPropertyValue(thePropList, alternateHeaderPropName);
                            else
                                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidPropertyName', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector({thePropList.Name}, ', '));
                            end
                        catch e
                            throwAsCaller(e);
                        end
                    else
                        value = obj.searchDefaultPropertyValue(thePropList, propName);
                    end
                end
            end
        end

        function value = getDefaultLibraryPropertyValue(obj, libName, propertyName, varargin)
        % GETDEFAULTLIBRARYPROPERTYVALUE - Return the default property value by name
        % of the given library string. If not overridden in the library class,
        % return empty array

        % varargin{1}, if provided, should contain a logical flag that tells if the specified
        % library libName has an alternate header file associated with it for the
        % board specified in the obj
        % NOTE: the obj class should implement a method
        % (an overriding method for areAlternateLibraryHeadersAvailableHook in addon.controller)
        % to determine the status of this flag
        % Set default value of alternateLibraryHeaderAvailable to false
            alternateLibraryHeaderAvailable = false;
            if nargin > 3
                alternateLibraryHeaderAvailable = varargin{1};
                assert(islogical(alternateLibraryHeaderAvailable) && ...
                       all(size(alternateLibraryHeaderAvailable)==[1 1]), ...
                       'ASSERT: alternateLibraryHeaderAvailable must be a logical true or false');
            end

            [basePackageName] = getBasePackageNameImpl(obj);
            assert(isstring(basePackageName) && ...
                   all(size(basePackageName)==[1 1]), ...
                   'ASSERT: getBasePackageNameImpl must return a string');
            addonPackageName = basePackageName + "addons";
            superclassName = "matlabshared.addon.LibraryBase";
            %             baseList = internal.findSubClasses(char(basePackageName), char(superclassName), true);
            baseList = getBaseLibrariesHook(obj);
            if ~isempty(what(char(addonPackageName)))
                addonList = internal.findSubClasses(char(addonPackageName), char(superclassName), true);
            else
                addonList =[];
            end
            if ~contains(libName, '/')
                value = obj.findMatchingLibraryAndReturnDefaultPropertyValue(baseList, libName, propertyName, alternateLibraryHeaderAvailable);
            else
                value = obj.findMatchingLibraryAndReturnDefaultPropertyValue(addonList, libName, propertyName, alternateLibraryHeaderAvailable);
            end
        end

        function value = searchDefaultPropertyValue(~, propertyList, propertyName)
        % SEARCHDEFAULTPROPERTYVALUE - Return the default value for given property in the class's property list
        % meta data
            value = [];

            for propCount = 1:length(propertyList)
                if propertyList(propCount).HasDefault && strcmp(propertyList(propCount).Name, propertyName)
                    value = propertyList(propCount).DefaultValue;
                    % convert string type default value to cellstr
                    if isstring(value)
                        value = cellstr(value);
                    end
                end
            end
        end
    end
end

% LocalWords:  arduinoioaddons VENDORNAME arduinoio matlabshared addon
% LocalWords:  arduinoioaddons VENDORNAME arduinoio matlabshared addon
% LocalWords:  GETDEFAULTLIBRARYPROPERTYVALUE SEARCHDEFAULTPROPERTYVALUE
