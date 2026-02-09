function output = SharedArduinoRoot()
% This function returns the installed root directory of Shared Arduino
% component

%   Copyright 2017 The MathWorks, Inc.
sppkgRoot = fileparts(strtok(mfilename('fullpath'), '+'));
output = sprintf('%s',sppkgRoot);

end