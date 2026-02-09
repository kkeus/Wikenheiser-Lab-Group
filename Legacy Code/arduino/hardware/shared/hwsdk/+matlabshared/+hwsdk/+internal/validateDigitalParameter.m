function param = validateDigitalParameter(param)

%   Copyright 2014-2017 The MathWorks, Inc.
    try
        validateattributes(param, {'numeric', 'logical'}, {'scalar', 'integer', 'real', 'finite', 'nonnan'});
    catch
        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidDigitalType');
    end

    param = double(param);

    if ~((param == 0) || (param == 1))
        matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidDigitalType');
    end
end

% LocalWords:  arduinoio nonnan
