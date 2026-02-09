function validateIOServerCompatibility
% Validate the version of Arduino library is newer than the core IOserver 
% version
%
% Copyright 2023 The MathWorks, Inc.

spkgBoardIOSeverVersion = arduinoio.internal.ArduinoConstants.LibVersion;
IOServerCoreVersion = arduinoio.internal.getIOServerCoreVersion;
pattern = '(?<Major>\d+).(?<Minor>\d+).(?<Patch>\d+)';
boardVersion = regexp(spkgBoardIOSeverVersion, pattern, 'names');
coreVersion = regexp(IOServerCoreVersion, pattern, 'names');

% Errors out if the version of IO server core is newer than the lib version
% of Arduino. This can happen if the IO server code shipped with MATLAB is
% updated, but the Arduino support package is not updated accordingly
if ~(strcmp(boardVersion.Major, coreVersion.Major) && ...
        strcmp(boardVersion.Minor, coreVersion.Minor) && ...
        str2double(boardVersion.Patch) >= str2double(coreVersion.Patch))
    matlabshared.hwsdk.internal.localizedError...
        ('MATLAB:hwsdk:general:invalidSPPKGVersion', 'Arduino',...
        'ML_Arduino');
end
