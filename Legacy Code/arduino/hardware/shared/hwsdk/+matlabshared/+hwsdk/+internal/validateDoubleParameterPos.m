function paramValue = validateDoubleParameterPos(paramName, paramValue)

%   Copyright 2014-2018 The MathWorks, Inc.
    try
        validateattributes(paramValue, {'double'}, {'scalar', 'real', 'finite', 'nonnan', 'positive'});
    catch
        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidDoubleTypePos', paramName);
    end

    paramValue = double(paramValue);
end

% LocalWords:  arduinoio nonnan
