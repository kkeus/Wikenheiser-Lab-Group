function result = validateAnalogPin(device, analogPin)

%   Copyright 2014-2017 The MathWorks, Inc.
    try
        if ischar(analogPin)
            analogPin = string(analogPin);
        end
        validateattributes(analogPin, {'string'}, {'scalar'});

        iPin = find(strcmpi(analogPin, device.AvailableAnalogPins));
        if ~isempty(iPin)
            result = device.AvailableAnalogPins(iPin);
            return;
        end
    catch
    end

    error(char("Valid analog pins are " + matlabshared.hwsdk.internal.renderArrayOfStringsToString(device.Parent.AvailableAnalogPins, ', ')));
end