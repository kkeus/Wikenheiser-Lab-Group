function vars = workspaceVariableOfClass(className)

%   Copyright 2017-2022 The MathWorks, Inc.

    w = evalin('base', 'who')';
    vars = cell(size(w));
    for i = 1 : size(w, 2)
        if evalin('base', ['isa(' w{i} ', ''' className ''')'])
            vars{i} = w{i};
        end
    end
    % Remove empty cells
    vars = vars(~cellfun('isempty',vars));
end
