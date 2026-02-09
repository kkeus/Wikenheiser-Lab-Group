function paramValue = validateHexParameterRanged(paramName, paramValue, min, max)

%   Copyright 2017 The MathWorks, Inc.

    if isnumeric(paramValue) && isscalar(paramValue)
        try
            paramValue = matlabshared.hwsdk.internal.validateIntParameterRanged(paramName, paramValue, min, max);
            return;
        catch e
            throwAsCaller(e);
        end
    end

    if ischar(paramValue) || isstring(paramValue)
        tmpValue= char(paramValue);
        if length(tmpValue)~=1 && strcmpi(tmpValue(1:2), '0x')
            tmpValue = tmpValue(3:end);
        end
        if strcmpi(tmpValue(end), 'h')
            tmpValue(end) = [];
        end

        try
            dec = hex2dec(tmpValue);
        catch
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntValueRanged', paramName, num2str(min), num2str(max));
        end

        if dec < min || dec > max
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntValueRanged', paramName, num2str(min), num2str(max));
        end

        paramValue = dec;
        return;
    end

    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidIntValueRanged', paramName, num2str(min), num2str(max));
end

% LocalWords:  ID's hwsdk CAddress
