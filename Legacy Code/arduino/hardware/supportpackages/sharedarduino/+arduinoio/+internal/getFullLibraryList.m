function fullLibs = getFullLibraryList(libs)
% GETFULLLIBRARYLIST - Return the full list of libraries including
% dependent libraries based on the input library list.

%   Copyright 2018 The MathWorks, Inc.


    fullLibs = {};
    for libCount = 1:length(libs)
        depLibs = arduinoio.internal.getDefaultLibraryPropertyValue(libs{libCount}, 'DependentLibraries');
        if ~isempty(depLibs)
            if ischar(depLibs)
                depLibs = {depLibs};
            end
            libraryList = listArduinoLibraries();
            try
               validateFcn = @(x) validatestring(x, libraryList);
               depLibs = cellfun(validateFcn, depLibs, 'UniformOutput', false); 
            catch 
                matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:missingDependentLibraries', libs{libCount}, strjoin(depLibs, ', '));
            end
            newLibs = [libs{libCount}, depLibs];
        else
            newLibs = libs{libCount};
        end
        fullLibs = [fullLibs, newLibs]; %#ok<AGROW>
    end
    if ~isempty(fullLibs)
        fullLibs = unique(fullLibs);
    end
end