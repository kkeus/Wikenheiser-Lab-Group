function result = renderCellArrayOfCharVectorsToCharVector(cellArray,separator) 
    % Convert cell array to character vectors to a single character vector
    % with each item in CELLARRAY separated by SEPARATOR.

    %   Copyright 2017 The MathWorks, Inc.

    assert(nargin==2 && isvector(cellArray) && ischar(separator))
    if isempty(cellArray)
        result = '-none-';
        return;
    end
    % Force to nx1
    if(size(cellArray,1)~=1)
        cellArray = cellArray';
    end
    
    % Insert the separator into a second row
    cellArray(2,:) = {separator};
    
    % Reshape the matrix to a vector, which puts the separators
    % between the original strings
    cellArray = reshape(cellArray,1,numel(cellArray));
    
    % Delete the last separator
    cellArray(end) = [];
    
    % Render them to a character vector
    result = cell2mat(cellArray);
end
