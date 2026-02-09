function result = renderArrayOfIntsToString(values)

%   Copyright 2014-2017 The MathWorks, Inc.
    if isempty(values)
        result = '-none-';
        return;
    end
    if isreal(values)
        result = sprintf('%d, ', values);
        result = result(1:end-2);
    else
        result = sprintf('%.4f + %.4fi, ', real(values), imag(values));
        result = result(1:end-2);
    end
end