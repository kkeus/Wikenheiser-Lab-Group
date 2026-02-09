function result = validateEndianness(endianness)

%   Copyright 2017 The MathWorks, Inc.

try
    endiannessValues = {"littleendian", "bigendian"};
    result = validatestring(string(endianness), endiannessValues);
catch e
    throwAsCaller(e);
end
end