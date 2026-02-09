function value = getDefaultLibraryPropertyValue(libName, propertyName, varargin)
% GETDEFAULTLIRARYPROPERTYVALUE - Return the default property value by name
% of the given library string. If not overriden in the library class,
% return empty array

%   Copyright 2018-2020 The MathWorks, Inc.

% Added to check availability of alternate 3P header files for the
% specified library and board
alternateLibraryHeaderAvailable = false;
if nargin > 2
    alternateLibraryHeaderAvailable = varargin{1};
    assert(islogical(alternateLibraryHeaderAvailable) && ...
        all(size(alternateLibraryHeaderAvailable)==[1 1]), ...
        'ASSERT: alternateLibraryHeaderAvailable must be a logical true or false');
end

baseList = {};
% ADD I2C and SPI by default after verifying subclasses
baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.i2c', 'matlabshared.addon.LibraryBase', true)];
baseList = [baseList; matlabshared.hwsdk.internal.findSubClasses('matlabshared.spi', 'matlabshared.addon.LibraryBase', true)'];
baseList = [baseList; internal.findSubClasses('arduinoio', 'matlabshared.addon.LibraryBase', true)];

addonList = internal.findSubClasses('arduinoioaddons', 'matlabshared.addon.LibraryBase', true);

if isempty(strfind(libName, '/'))
    value = findMatchingLibraryAndReturnDefaultPropertyValue(baseList, libName, propertyName, alternateLibraryHeaderAvailable);
else
    value = findMatchingLibraryAndReturnDefaultPropertyValue(addonList, libName, propertyName, alternateLibraryHeaderAvailable);
end
end

function value = findMatchingLibraryAndReturnDefaultPropertyValue(allLibList, oldLib, propName, alternateLibraryHeaderAvailable)
% Return the input library plus its dependent libs, if any

value = [];
for libClassCount = 1:length(allLibList)
    % get current class's library name
    thePropList = allLibList{libClassCount}.PropertyList;
    libName = arduinoio.internal.searchDefaultPropertyValue(thePropList, 'LibraryName');
    % get the alternate library header file associated with the oldLib
    
    if strcmp(libName, oldLib)
        if alternateLibraryHeaderAvailable
            try
                if ismember('AlternateLibraryHeaderFiles', {thePropList.Name})
                    value = arduinoio.internal.searchDefaultPropertyValue(thePropList, 'AlternateLibraryHeaderFiles');
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidPropertyName', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector({thePropList.Name}, ', '));
                end
            catch e
                throwAsCaller(e);
            end
        else
            value = arduinoio.internal.searchDefaultPropertyValue(thePropList, propName);
        end
        
    end
end
end