function rangedPinsVector = renderArrayOfPinStringsToRangedCharacterVector(pins)

%   Copyright 2018 The MathWorks, Inc.

    % Fetch ranged string
    rangedString = matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(pins);
    % Convert the string into character
    rangedStringAsChar = char(rangedString);
    % Convert into character vector
    rangedPinsVector = strrep(rangedStringAsChar, '"', '''');
end