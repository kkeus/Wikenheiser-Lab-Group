function value = searchDefaultPropertyValue(propertyList, propertyName)
% SEARCHDEFAULTPROPERTYVALUE - Return the default value for given property in the class's property list
% meta data

%   Copyright 2018 The MathWorks, Inc.

    value = [];

    for propCount = 1:length(propertyList)
        if propertyList(propCount).HasDefault && strcmp(propertyList(propCount).Name, propertyName) 
            value = propertyList(propCount).DefaultValue;
            % convert string type default value to character vector
            if isstring(value)
                value = char(value);
            end
        end
    end
end