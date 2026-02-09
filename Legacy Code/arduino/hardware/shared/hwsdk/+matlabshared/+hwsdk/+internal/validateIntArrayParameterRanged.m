function paramValue = validateIntArrayParameterRanged(paramName, paramValue, min, max)

%   Copyright 2017 The MathWorks, Inc.
    try
        validateattributes(paramValue, {'double', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}, {'2d', 'integer', 'real', 'finite', 'nonnan'});
    catch
        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntArrayTypeRanged', ...
                                                   paramName, num2str(min), num2str(max));
    end

    paramValue = floor(paramValue);

    if ~(all(paramValue >= min) && all(paramValue <= max))
        if isscalar(paramValue)
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntValueRanged', ...
                                                   paramName, num2str(min), num2str(max));
        end
        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntArrayValueRanged', ...
                                                   paramName, num2str(min), num2str(max));
    end
end

% LocalWords:  hwsdk nonnan
