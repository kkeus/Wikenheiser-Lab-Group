function IOServerVersion = getIOServerCoreVersion
% Get the version of the IO server shipped with MATLAB
%
% Copyright 2023 The MathWorks, Inc.

persistent versionInfo;

if isempty(versionInfo)
    IOServerHeaderPath = fullfile(matlabroot, 'toolbox', 'target', ... 
        'shared', 'ioserver', 'ioserver', 'inc', 'IO_server.h');
    if exist(IOServerHeaderPath, 'file') == 0
        % Error out. File not found
        matlabshared.hwsdk.internal.localizedError...
            ('MATLAB:arduinoio:general:IOServerHeaderNotFound');
        return;
    end

    [fid, errorMsg] = fopen(IOServerHeaderPath);
    if fid < 0
        % Rethrow the errMsg
        matlabshared.hwsdk.internal.localizedError...
            ('MATLAB:arduinoio:general:FailedToOpenFile', ...
            IOServerHeaderPath, errorMsg);
    else
        fileData = fscanf(fid, '%c');
        fclose(fid);
        % Below is an exmple text being parsed to get version info:
        % #define Major 24 /* 8 bit field */
        % #define Minor 1 /* 1 bit (out of 8 bits) field. 1 for 'a' and 2 for 'b' */
        % #define Patch 0 /* 8 bit field. 0 to 255 updates */
        pattern = ['#define Major (?<Major>\d+).*' ...
            '#define Minor (?<Minor>\d+).*' ...
            '#define Patch (?<Patch>\d+)'];
        versionNames = regexp(fileData, pattern, 'names');
        if length(versionNames) ~= 1
            % throws error for no match or multiple match
            matlabshared.hwsdk.internal.localizedError...
                ('MATLAB:arduinoio:general:CannotFindIOServerVersionInHeader');
        else
            versionInfo = [versionNames.Major '.' versionNames.Minor ...
                '.' versionNames.Patch];
        end
    end
end

IOServerVersion = versionInfo;