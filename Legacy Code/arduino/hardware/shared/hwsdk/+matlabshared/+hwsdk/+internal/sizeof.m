function result = sizeof(precision)

%   Copyright 2017-2022 The MathWorks, Inc.

    switch precision
      case {"int8", "uint8", "char"}
        result = 1;
      case {"int16", "uint16"}
        result = 2;
      case {"int32", "uint32"}
        result = 4;
      case {"int64", "uint64"}
        result = 8;
      otherwise
        error(['Unknown Precision: ' precision]);
    end
end
