classdef UtilityCreator < handle
% Factory class to create utility object based on the platform  
    
%   Copyright 2014-2023 The MathWorks, Inc.
    
    methods(Static = true, Access = public)
        function utilityObject = getInstance()
            persistent arduinoUtility;
            if isempty(arduinoUtility)
                arduinoUtility = arduinoio.internal.PlatformUtility();
            end
            utilityObject = arduinoUtility;
        end
    end
end