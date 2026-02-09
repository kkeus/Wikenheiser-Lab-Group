function rootDir = getSensorThirdPartyRootDir()
% GETSENSORTHIRDPARTYROOTDIR return the root directory of sensor component

% Copyright 2022 The MathWorks, Inc.

rootDir = fileparts(strtok(mfilename('fullpath'), '+'));
end

