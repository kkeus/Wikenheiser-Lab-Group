function paramValue = validateDoubleParameterRanged(paramName, paramValue, min, max, units)

%   Copyright 2014-2018 The MathWorks, Inc.
    if nargin < 5
        units = [];
    end

    try
        validateattributes(paramValue, {'double'}, {'scalar', 'real', 'finite', 'nonnan'});
    catch
        if isempty(units)
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidDoubleTypeRanged', ...
                                                       paramName, num2str(min), num2str(max));
        else
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidDoubleTypeRangedUnits', ...
                                                       paramName, num2str(min), num2str(max), units);
        end
    end

    paramValue = double(paramValue);

    if ~((paramValue >= min) && (paramValue <= max))
        if isempty(units)
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidDoubleValueRanged', ...
                                                       paramName, num2str(min), num2str(max));
        else
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidDoubleValueRangedUnits', ...
                                                       paramName, num2str(min), num2str(max), units);
        end
    end
end

% LocalWords:  arduinoio nonnan
