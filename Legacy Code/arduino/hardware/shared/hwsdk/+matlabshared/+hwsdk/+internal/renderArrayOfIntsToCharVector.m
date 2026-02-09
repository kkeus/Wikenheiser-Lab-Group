function result = renderArrayOfIntsToCharVector(values)
    % Convert array of integers to a character vector by concatenating with
    % comma. If input is empty, '-none-' is returned.
    
    %   Copyright 2016-18 The MathWorks, Inc.
    
    if isempty(values)
        result = '-none-';
        return;
    end
    result = sprintf('%d, ', values);
    result = result(1:end-2);
end