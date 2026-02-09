function result = renderArrayOfStringsToString(array,separator, quote)
% renderCellArrayOfStringsToString convert cell array to string
% renderCellArrayOfStringsToString(CELLARRAY,SEPARATOR) Takes
% vector CELLARRAY of strings and turns it into a string, with
% each item in CELLARRAY separated by SEPARATOR.

%   Copyright 2014-2022 The MathWorks, Inc.

    if nargin < 2
        separator = ', ';
    end

    if nargin < 3
        quote = """";
    end

    if isempty(array)
        result = "-none-";
        return;
    end

    assert(nargin>=1 && isvector(array) && ischar(separator))

    % Force to nx1
    if(size(array,1)~=1)
        array = array';
    end

    % Insert the separator into a second row
    for i = 1:numel(array)
        array(i) = quote + array(i) + quote;
    end

    array(2,:) = {separator};

    % Reshape the matrix to a vector, which puts the separators
    % between the original strings
    array = reshape(array,1,numel(array));

    % Delete the last separator
    array(end) = [];

    % Render them to a string
    result = array(1);
    for i = 2:numel(array)
        result = result + array(i);
    end
end

% LocalWords:  nx
