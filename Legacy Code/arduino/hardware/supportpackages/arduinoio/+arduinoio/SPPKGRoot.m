function output = SPPKGRoot()
% This function returns the installed root directory of Arduino I/O support package

%   Copyright 2017 The MathWorks, Inc.
sppkgRoot = fileparts(strtok(mfilename('fullpath'), '+'));
output = sprintf('%s',sppkgRoot);

end