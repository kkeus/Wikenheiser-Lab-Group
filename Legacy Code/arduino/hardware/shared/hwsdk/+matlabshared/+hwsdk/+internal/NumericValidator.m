classdef (Hidden) NumericValidator < matlabshared.hwsdk.internal.BasePinValidator
% Handles numeric validations

%   Copyright 2023-2024 The MathWorks, Inc.

    methods (Hidden)
        function validateI2CPinType(~, i2cPinsArray)
            assert(isstruct(i2cPinsArray),'MATLAB:hwsdk:internal:invalidI2CPinArrayType', 'validateI2CPinType: I2C Pins Array input must be a struct');
            for i = 1:numel(i2cPinsArray)
                assert(isnumeric(i2cPinsArray(i).SCLPin) || isempty(i2cPinsArray(i).SCLPin),'MATLAB:hwsdk:internal:invalidSCLPinTypeNumeric', 'getAvailableI2CPins: Expected I2CPinsArray to have numeric or empty SCLPin');
                assert(isnumeric(i2cPinsArray(i).SDAPin) || isempty(i2cPinsArray(i).SDAPin),'MATLAB:hwsdk:internal:invalidSDAPinTypeNumeric', 'getAvailableI2CPins: Expected I2CPinsArray to have numeric or empty SDAPin');
            end
        end

        function validateSPIPinType(~, spiPinsArray)
            for i = 1:numel(spiPinsArray)
                assert(isnumeric(spiPinsArray(i).SCLPin),'MATLAB:hwsdk:internal:invalidSCLPinTypeNumeric', 'validateSPIPinType: Expected SCLPin to be nonempty and numeric');
                assert(isnumeric(spiPinsArray(i).SDIPin),'MATLAB:hwsdk:internal:invalidSDIPinTypeNumeric', 'validateSPIPinType: Expected SDIPin to be nonempty and numeric');
                assert(isnumeric(spiPinsArray(i).SDOPin),'MATLAB:hwsdk:internal:invalidSDOPinTypeNumeric', 'validateSPIPinType: Expected SDOPin to be nonempty and numeric');
            end
        end

        function pinString = renderPinsToStringImpl(~, pinCell)
            pinString = matlabshared.hwsdk.internal.renderArrayOfIntsToString([pinCell{:}]);
        end

        function charPin = getPinForErrorDisplay(~, pin)
            charPin = num2str(pin);
        end

        function validatePWMPinType(~, pins)
            assert(isnumeric(pins),'MATLAB:hwsdk:internal:invalidPWMPinsTypeNumeric','validatePWMPinType: getAvailablePWMPinsImpl must return a row based array of doubles');

        end

        function pin = validateControllerPin(~, pin, validPins, boardName)
            if isequal(class(pin), class(validPins))
                if ~any(pin == validPins)
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidPinNumber', char(boardName), char(matlabshared.hwsdk.internal.renderArrayOfIntsToString(validPins)));
                end
            else
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidPinTypeDouble',  char(matlabshared.hwsdk.internal.renderArrayOfIntsToString(validPins)));
            end
        end

        function bus = validateI2CBus(~, bus, availableI2CBusIDs)
            assert(isnumeric(availableI2CBusIDs),'MATLAB:hwsdk:internal:invalidAvailableI2CBusIDsTypeNumeric', 'validateI2CBus: availableI2CBusIDs is expected to be a numeric vector');
            buses = matlabshared.hwsdk.internal.renderArrayOfIntsToString(availableI2CBusIDs);
            try
                if ~(isnumeric(bus) && isreal(bus) && isscalar(bus) && ~isinteger(bus) && bus>=0)
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidBusTypeNumeric', 'I2C', buses);
                elseif ~ismember(bus, availableI2CBusIDs)
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidBusValue', 'I2C', buses);
                end
            catch e
                throwAsCaller(e);
            end
        end

        function busNumber = getI2CBusNumber(~, hwsdkI2CBusID)
            busNumber = hwsdkI2CBusID - 1;
        end

        function showI2CBus(~, bus)
        % Displays I2C Bus in Device property display
            fprintf('                   Bus: %d\n', bus);
        end

        function showSPIPins(~, scl, sdi, sdo)
            fprintf('                SCLPin: %d\n', scl);
            fprintf('                SDIPin: %d\n', sdi);
            fprintf('                SDOPin: %d\n', sdo);
        end

        function validateSerialPort(~, serialPort, board, validPortIDs)
            try
                validateattributes(serialPort, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
            catch
                % if scalar following error is thrown
                if isscalar(serialPort)
                    if iscell(serialPort)
                        serialPort = num2str(serialPort{:});
                    else
                        serialPort = num2str(serialPort);
                    end
                    % if scalar following error is thrown
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:unsupportedPort',serialPort,char(board), matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(validPortIDs));
                else
                    %throw a valid error for non-scalar inputs
                    validateattributes(serialPort,{'numeric','char','string','cell'},{'scalar'},'device','Port',1);
                end
            end
            if ~ismember(serialPort, validPortIDs)
                matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:unsupportedPort', matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(serialPort),char(board), matlabshared.hwsdk.internal.renderArrayOfIntsToCharVector(validPortIDs));
            end
        end

        function validatingHandle = getSerialPinTypeValidator(~)
            validatingHandle = @isnumeric;
        end
    end
end
