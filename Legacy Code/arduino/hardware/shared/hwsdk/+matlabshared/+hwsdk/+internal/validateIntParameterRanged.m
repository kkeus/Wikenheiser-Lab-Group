function paramValue = validateIntParameterRanged(paramName, paramValue, min, max)

%   Copyright 2017 The MathWorks, Inc.
    try
        validateattributes(paramValue, {'double', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}, {'scalar', 'integer', 'real', 'finite', 'nonnan'});
    catch
        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntTypeRanged', ...
                                                   paramName, num2str(min), num2str(max));
    end

    paramValue = floor(paramValue);

    if ~((paramValue >= min) && (paramValue <= max))
        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntValueRanged', ...
                                                   paramName, num2str(min), num2str(max));
    end
end

% LocalWords:  hwsdk nonnan
