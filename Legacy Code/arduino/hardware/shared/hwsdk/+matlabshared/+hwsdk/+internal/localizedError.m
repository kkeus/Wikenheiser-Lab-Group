function localizedError(id, varargin)

%   Copyright 2014-2018 The MathWorks, Inc.
    for i = 1:nargin-1
        if ischar(varargin{i})
            varargin{i} = strrep(varargin{i}, '\', '\\');
        end
    end
    MException(id,getString(message(id, varargin{:}))).throwAsCaller;
end

