function output = getDocMap()
% This function returns the arduinoio.map full path

%   Copyright 2015-2016 The MathWorks, Inc.

output = matlabshared.supportpkg.getSupportPackageRoot;

output = fullfile(output, 'help', 'supportpkg','arduinoio', 'arduinoio.map');

end
