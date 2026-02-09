function name = shortName(className)

%   Copyright 2017-2022 The MathWorks, Inc.

    dots = strfind(className, '.');
    if ~isempty(dots)
        name = className(dots(end)+1: end);
    else
        name = className;
    end
end
