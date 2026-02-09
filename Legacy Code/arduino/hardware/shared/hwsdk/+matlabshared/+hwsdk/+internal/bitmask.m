function out = bitmask(in, bits)

%   Copyright 2017 The MathWorks, Inc.

    nBits = matlabshared.hwsdk.internal.sizeof(class(in))*8;
    tmp = bitshift(in, nBits-bits(end));
    out = double(bitshift(tmp, -(nBits-bits(end)+bits(1)-1)));
end