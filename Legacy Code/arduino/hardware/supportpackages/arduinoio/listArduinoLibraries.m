function allInstalledLibs = listArduinoLibraries()
%Display a list of installed Arduino libraries
%
%Syntax:
%libs = listArduinoLibraries()
%
%Description:
%Creates a list of available Arduino libraries and saves the list to the variable libs.
%
%Output Arguments:
%libs - List of available Arduino libraries (cell array of strings)

%   Copyright 2014-2023 The MathWorks, Inc.

% Integrate data on clean
dduxHelper = arduinoio.internal.ArduinoDataUtilityHelper;
c = onCleanup(@()integrateData(dduxHelper));

    baseList = {};
    % ADD I2C and SPI by default after verifying subclasses
    baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.i2c', 'matlabshared.addon.LibraryBase', true)];
    baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.spi', 'matlabshared.addon.LibraryBase', true)'];
    baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.serial', 'matlabshared.addon.LibraryBase', true)'];
    baseList = [baseList; internal.findSubClasses('arduinoio', 'matlabshared.addon.LibraryBase', true)];  
    
    addonList = internal.findSubClasses('arduinoioaddons', 'matlabshared.addon.LibraryBase', true);
    allList = [baseList; addonList];
    allInstalledLibs = {};
    for libClassCount = 1:numel(allList)
        thePropList = allList{libClassCount}.PropertyList;
        for propCount = 1:numel(thePropList)
            % check classes that have defined constant LibraryName - e.g
            % those that are library classes
            theProp = thePropList(propCount);
            % If the current property's name is 'LibraryName' and it has a
            % default value, then it defines a new library
            if strcmp(theProp.Name, 'LibraryName') && theProp.HasDefault 
                definingClass = theProp.DefiningClass;
                packageNames = strsplit(definingClass.Name, '.');
                vendorPackageName = packageNames{end-1};
                % check vendor package name to form library name string
                if isstring(theProp.DefaultValue)
                    libName = char(theProp.DefaultValue);
                else
                    libName = theProp.DefaultValue;
                end
                if ~strcmp(vendorPackageName, 'arduinoio') && strcmp(packageNames{1},'arduinoioaddons') % class within arduino addons.VENDORNAME
                    libName = strrep(theProp.DefaultValue, '\', '/');
                    if contains(libName, '/')
                        temp = strsplit(libName, '/');
                        if strcmpi(vendorPackageName, temp{1})
                            allInstalledLibs = [allInstalledLibs, libName]; %#ok<AGROW>
                        end
                    end
                else
                    allInstalledLibs = [allInstalledLibs, libName]; %#ok<AGROW>
                end
            end
        end
    end
    allInstalledLibs = cellstr(unique(allInstalledLibs'));
    
    try
        if isempty(allInstalledLibs)
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:CLINotInstalled');
        end
    catch e
        % Integrate the error
        integrateErrorKey(dduxHelper, e.identifier);
        throwAsCaller(e);
    end
end


