classdef (Hidden) StringValidator < matlabshared.hwsdk.internal.BasePinValidator
% Handles string validations

%   Copyright 2023-2024 The MathWorks, Inc.

    methods (Hidden)
        function validateI2CPinType(~, i2cPinsArray)
            for i = 1:numel(i2cPinsArray)
                assert(isstring(i2cPinsArray(i).SCLPin),'MATLAB:hwsdk:internal:invalidSCLPinTypeString','validateI2CPinType: SCL Pin must be a string');
                assert(isstring(i2cPinsArray(i).SDAPin),'MATLAB:hwsdk:internal:invalidSDAPinTypeString','validateI2CPinType: SDA Pin must be a string');
            end
        end

        function validateSPIPinType(~, spiPinsArray)
            for i = 1:numel(spiPinsArray)
                assert(isstring(spiPinsArray(i).SCLPin),'MATLAB:hwsdk:internal:invalidSCLPinTypeString','validateSPIPinType: SCLPin must be a string');
                assert(isstring(spiPinsArray(i).SDIPin),'MATLAB:hwsdk:internal:invalidSDIPinTypeString','validateSPIPinType: SDIPin must be a string');
                assert(isstring(spiPinsArray(i).SDOPin),'MATLAB:hwsdk:internal:invalidSDOPinTypeString','validateSPIPinType: SDOPin must be a string');
            end
        end

        function pinString = renderPinsToStringImpl(~, pinCell)
            charPins = all(cellfun(@ischar, pinCell));
            if charPins
                pinString = matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(pinCell, ', ');
            else
                pinString = matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(cellstr(pinCell), ', ');
            end
        end

        function charPin = getPinForErrorDisplay(~, pin)
            charPin = char(pin);
        end

        function validatePWMPinType(~, pins)
            assert(isstring(pins),'MATLAB:hwsdk:internal:invalidPWMPinsTypeString','validatePWMPinType: getAvailablePWMPinsImpl must return a row based array of strings');
        end

        function pin = validateControllerPin(~, pin, validPins, boardName)
            assert(isstring(validPins),'MATLAB:hwsdk:internal:invalidValidPinsTypeString', 'validateControllerPin: validPins must be a string array');
            assert(ischar(boardName) || isstring(boardName),'MATLAB:hwsdk:internal:invalidBoardNameTypeString', 'validateControllerPin: boardName must be a string');
            if ischar(pin)
                pin = string(pin);
            end

            if isscalar(pin) && isstring(pin)
                iPin = find(strcmpi(pin, validPins));
                if ~isempty(iPin)
                    pin = validPins(iPin);
                    return;
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidPinNumber', char(boardName), char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(validPins)));
                end
            end
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidPinTypeString',  char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(validPins)));
        end

        function bus = validateI2CBus(~, bus, availableI2CBusIDs)
            assert(isstring(availableI2CBusIDs),'MATLAB:hwsdk:internal:invalidAvailableI2CBusIDsTypeString', 'validateI2CBus: availableI2CBusIDs is expected to be a string vector');
            buses = matlabshared.hwsdk.internal.renderArrayOfStringsToString(availableI2CBusIDs);
            try
                if ~((isstring(bus) && isscalar(bus)) || ischar(bus))
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidBusTypeString', 'I2C', buses);
                elseif ~ismember(string(bus), availableI2CBusIDs)
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidBusValue', 'I2C', buses);
                end
            catch e
                throwAsCaller(e);
            end
        end

        function busNumber = getI2CBusNumber(~, hwsdkI2CBusID)
            if contains(hwsdkI2CBusID, "i2c-")
                % i2c-* can be zero indexed.
                busNumber = str2double(string(extract(hwsdkI2CBusID, 5)));
            else
                busNumber = 0;
            end
        end

        function showI2CBus(~, bus)
        % Displays I2C Bus in Device property display
            fprintf('                   Bus: "%s"\n', bus);
        end

        function showSPIPins(~, scl, sdi, sdo)
            fprintf('                SCLPin: "%s"\n', scl);
            fprintf('                SDIPin: "%s"\n', sdi);
            fprintf('                SDOPin: "%s"\n', sdo);
        end

        function validateSerialPort(~, serialPort, ~ , ~)
            try
                validateattributes(serialPort,{'char','string'},{'scalartext'});
                % zero-length string is considered as non-empty
                % therefore converted serialPort to char datatype
                serialPort = char(strtrim(serialPort));
                validateattributes(serialPort,{'char'},{'nonempty'});
            catch e
                throwAsCaller(e);
            end
        end

        function validatingHandle = getSerialPinTypeValidator(~)
            validatingHandle = @isstring;
        end
    end
end
