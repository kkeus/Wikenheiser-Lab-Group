function paramValue = validateIntParameter(paramName, paramValue, validParamValues)
%   Copyright 2014-2021 The MathWorks, Inc.
    try
        validateattributes(paramValue, {'double', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}, {'scalar', 'integer', 'real', 'finite', 'nonnan'});
    catch
        matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:invalidIntType', ...
                                                   paramName, matlabshared.hwsdk.internal.renderArrayOfIntsToString(validParamValues));
    end

    paramValue = floor(paramValue);

    if ~(ismember(paramValue, validParamValues))
        matlabshared.hwsdk.internal.localizedError('MATLAB:arduinoio:general:invalidIntValue', ...
                                                   paramName, matlabshared.hwsdk.internal.renderArrayOfIntsToString(validParamValues));
    end
end

% LocalWords:  arduinoio nonnan
