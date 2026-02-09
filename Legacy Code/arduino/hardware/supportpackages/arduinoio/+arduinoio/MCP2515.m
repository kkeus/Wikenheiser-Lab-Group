classdef (Hidden) MCP2515 < matlabshared.can.ChannelProvider & matlabshared.addon.LibraryBase
%MCP2515   Access CAN Network through MCP2515

%   Copyright 2019-2023 The MathWorks, Inc.

    properties
        %ChipSelectPin - Device selector of SPI Interface
        ChipSelectPin char

        %InterruptPin - Used to handle received messages
        InterruptPin char
    end

    properties(Hidden)
        Device
    end

    properties(Access = private)
        ID
        ResourceOwner = 'CAN'
        ResourceMode = 'Interrupt'
    end

    properties(Abstract, Constant, Access = protected)
        OscillatorFrequencies double;
        BusSpeeds double;
    end

    properties(Constant, Access = private)
        ConfigurationRegister = 0x2A;
        DummyData1 = 0x55;
        DummyData2 = 0xAA;
        WriteCommand = 2;
        ReadCommand = 3;
    end

    methods(Hidden, Access = public)
        function obj = MCP2515(parentObj, csPin, interruptPin, varargin)
            obj.Parent = parentObj;
            obj.ProtocolMode = 'CAN';

            if nargin > 3
                % Check only for max inputs. We throw better error or less
                % than min inputs.
                narginchk(3, 7);
            end
            p = inputParser;
            % Fetch Chip Select Pin
            addRequired(p, "ChipSelectPin", @(x) (isstring(x) || ischar(x)));
            try
                parse(p, csPin);
            catch e
                switch e.identifier
                  case {'MATLAB:badsubscript', 'MATLAB:minrhs'}
                    obj.localizedError('MATLAB:arduinoio:can:MCP2515missingCSINT');
                  case 'MATLAB:InputParser:ArgumentFailedValidation'
                    digitalPins = obj.Parent.AvailableDigitalPins;
                    spiTerminals = getSPITerminals(obj.Parent);
                    spiPins = getPinsFromTerminals(obj.Parent, spiTerminals);
                    if ~isempty(spiPins)
                        validPins = setdiff(digitalPins, spiPins(1:3), 'stable');
                    else
                        validPins = digitalPins;
                    end
                    obj.localizedError('MATLAB:hwsdk:general:invalidChipSelectPin', obj.ResourceOwner, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
                  otherwise
                    throwAsCaller(e);
                end
            end

            % Validate Chip Select Pin, configure it and reserve Resources
            try
                % Assuming defaults for rest of the parameters.
                obj.Device = device(obj.Parent, 'SPIChipSelectPin', p.Results.ChipSelectPin);
                overridePinResource(obj.Parent, p.Results.ChipSelectPin, obj.ResourceOwner, obj.ResourceOwner);
                obj.ChipSelectPin = p.Results.ChipSelectPin;
            catch e
                switch(e.identifier)
                  case 'MATLAB:hwsdk:general:invalidChipSelectPin'
                    digitalPins = obj.Parent.AvailableDigitalPins;
                    spiTerminals = getSPITerminals(obj.Parent);
                    spiPins = getPinsFromTerminals(obj.Parent, spiTerminals);
                    if ~isempty(spiPins)
                        validPins = setdiff(digitalPins, spiPins(1:3), 'stable');
                    else
                        validPins = digitalPins;
                    end
                    obj.localizedError('MATLAB:hwsdk:general:invalidChipSelectPin', obj.ResourceOwner, char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(validPins))));
                  otherwise
                    throwAsCaller(e);
                end
            end

            % Fetch Interrupt Pin
            addRequired(p, "InterruptPin", @(x) (isstring(x) || ischar(x)));
            try
                % Interrupt Pin
                parse(p, csPin, interruptPin);
            catch e
                switch e.identifier
                  case {'MATLAB:badsubscript', 'MATLAB:minrhs'}
                    obj.localizedError('MATLAB:arduinoio:can:MCP2515missingINT', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(parentObj.getPinsFromTerminals(parentObj.getInterruptTerminals())))));
                  case 'MATLAB:InputParser:ArgumentFailedValidation'
                    intTerminals = getInterruptTerminals(obj.Parent);
                    interruptPins = getPinsFromTerminals(obj.Parent, intTerminals);
                    obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                       obj.Parent.Board, 'Interrupt', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(interruptPins))));
                  otherwise
                    throwAsCaller(e);
                end
            end
            % Validate Interrupt Pin
            try
                validatePin(obj.Parent, p.Results.InterruptPin, 'Interrupt');
                obj.InterruptPin = p.Results.InterruptPin;
            catch e
                switch(e.identifier)
                  case 'MATLAB:hwsdk:general:invalidPinNumber'
                    intTerminals = getInterruptTerminals(obj.Parent);
                    interruptPins = getPinsFromTerminals(obj.Parent, intTerminals);
                    obj.localizedError('MATLAB:hwsdk:general:invalidPin', ...
                                       obj.Parent.Board, 'Interrupt', char(matlabshared.hwsdk.internal.renderArrayOfPinStringsToRangedString(string(interruptPins))));
                  otherwise
                    throwAsCaller(e);
                end
            end
            % Error if CS Pin and INT Pins are same
            if strcmpi(obj.ChipSelectPin, obj.InterruptPin)
                obj.localizedError('MATLAB:arduinoio:can:MCP2515csIntConflict');
            end

            % Fetch NV Pairs
            p = inputParser;
            p.PartialMatching = true;
            addParameter(p, 'OscillatorFrequency', 16e6);
            addParameter(p, 'BusSpeed', 500e3);
            try
                parse(p, varargin{:});
            catch e
                switch(e.identifier)
                  case {'MATLAB:InputParser:ParamMissingValue', 'MATLAB:InputParser:UnmatchedNotAValidFieldName'}
                    try
                        message = e.message;
                        index = strfind(message, '''');
                        str = message(index(1)+1:index(2)-1);
                        validatestring(str, p.Parameters);
                    catch
                        % Invalid NV Pair Name
                        parameters = p.Parameters;
                        obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', str, 'Serial device', matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                    end
                    % Valid NV Pair Name. Value missing.
                    throwAsCaller(e);
                  case 'MATLAB:InputParser:UnmatchedParameter'
                    message = e.message;
                    index = strfind(message, '''');
                    name = message(index(1)+1:index(2)-1);
                    parameters = p.Parameters;
                    obj.localizedError('MATLAB:hwsdk:general:invalidNVPropertyName', name, obj.ResourceOwner, ...
                                       matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
                  otherwise %'MATLAB:InputParser:ParamMustBeChar' and others
                    throwAsCaller(e)
                end
            end
            obj.OscillatorFrequency = validateOscFreq(obj, p.Results.OscillatorFrequency);
            obj.BusSpeed = validateBusSpeed(obj, p.Results.BusSpeed);

            % Reserve Interrupt Resource
            obj.ID = getFreeResourceSlot(obj.Parent, obj.ResourceOwner);
            % Configure Interrupt Pin
            try
                configurePinWithUndo(obj.InterruptPin, obj.ResourceOwner, obj.ResourceMode);
                overridePinResource(obj.Parent, obj.InterruptPin, obj.ResourceOwner, obj.ResourceOwner);
            catch
                obj.localizedError('MATLAB:hwsdk:general:reservedPin', char(obj.InterruptPin), configurePin(obj.Parent, obj.InterruptPin), obj.ResourceMode);
            end

            % Check if MCP2515 is accessible. Done because of a bug in 3P
            % Issue:
            % ACAN2515 3P library has a bug of attaching an interrupt pin
            % even after figuring out that the device is not available at
            % the provided Chip Select.
            % Workaround:
            % As done in 3P, I verify if the device is available at the
            % specified Chip Select Pin and throw error a little ahead in
            % the timeline.
            writeRead(obj.Device, [obj.WriteCommand, obj.ConfigurationRegister, obj.DummyData1]);
            deviceDataCheck = writeRead(obj.Device, [obj.ReadCommand, obj.ConfigurationRegister, obj.DummyData1]);
            try
                if obj.DummyData1 ~= deviceDataCheck(3:end)
                    obj.localizedError('MATLAB:arduinoio:can:noMCP2515', 'MCP2515');
                end
            catch
                % 3 bytes sent to SPI. At least 3 bytes are expected in
                % deviceDataCheck. If there is a hardware failure, then
                % unexpected behavior will result.
                obj.localizedError('MATLAB:arduinoio:can:noMCP2515', 'MCP2515');
            end
            writeRead(obj.Device, [obj.WriteCommand, obj.ConfigurationRegister, obj.DummyData2]);
            deviceDataCheck = writeRead(obj.Device, [obj.ReadCommand, obj.ConfigurationRegister, obj.DummyData2]);
            try
                if obj.DummyData2 ~= deviceDataCheck(3:end)
                    obj.localizedError('MATLAB:arduinoio:can:noMCP2515', 'MCP2515');
                end
            catch
                % 3 bytes sent to SPI. At least 3 bytes are expected in
                % deviceDataCheck. If there is a hardware failure, then
                % unexpected behavior will result.
                obj.localizedError('MATLAB:arduinoio:can:noMCP2515', 'MCP2515');
            end

            % Attach MCP2515 to Arduino
            connect(obj, getPinNumber(obj.Parent, obj.ChipSelectPin), ...
                    getPinNumber(obj.Parent, obj.InterruptPin));

            % Nested function that configure pin and also allow reverting
            % them back in case configuration fails
            function configurePinWithUndo(pin, resourceOwner, pinMode)
                [~, ~, prevMode, prevResourceOwner] = getPinInfoHook(obj.Parent, pin);
                % Only Interrupt pin. So, indexing with 1 is okay.
                obj.Undo(1).Pin = pin;
                obj.Undo(1).ResourceOwner = prevResourceOwner;
                obj.Undo(1).PrevPinMode = prevMode;

                if (strcmp(prevMode, 'Interrupt') || strcmp(prevMode, 'CAN')) && strcmp(prevResourceOwner, '')
                    % Take resource ownership from Arduino object
                    % configurePinInternal is needed for Unset as it
                    % involves IOServer calls.
                    configurePinInternal(obj.Parent, pin, 'Unset', 'canChannel', prevResourceOwner);
                    configurePinResource(obj.Parent, pin, resourceOwner, pinMode, true);
                elseif strcmp(prevMode, 'Unset')
                    % We can only acquire unset resources
                    configurePinResource(obj.Parent, pin, resourceOwner, pinMode, false);
                else
                    obj.localizedError('MATLAB:hwsdk:general:reservedPin', pin, prevMode, pinMode);
                end
            end
        end
    end

    methods(Access = protected)
        function delete(obj)
            if ~isempty(obj.ChipSelectPin)
                [~, ~, csPinMode, ~] = getPinInfoHook(obj.Parent, obj.ChipSelectPin);
                % Unconfigure CS Pin and unreserve SPI resources
                if strcmp(csPinMode, 'CAN')
                    % treat it only if CAN has configured it.
                    % Otherwise let SPI device handle it.
                    overridePinResource(obj.Parent, obj.ChipSelectPin, 'SPI', 'SPI');
                end
                if isempty(obj.InterruptPin)
                    delete(obj.Device);
                else % if ~isempty(obj.InterruptPin)
                    [~, ~, interruptPinMode, ~] = getPinInfoHook(obj.Parent, obj.InterruptPin);
                    if strcmp(csPinMode, 'CAN') && strcmp(interruptPinMode, 'CAN')
                        % Detach only if construction is successful. Else NOP
                        disconnect(obj, getPinNumber(obj.Parent, obj.ChipSelectPin));
                    end
                    % Configuration of CS and INT Pins happened before 3P
                    % is used. Hence, 3P should be detached before CS and
                    % INT Pins are unconfigured.
                    delete(obj.Device);
                    % Unreserve Interrupt Resources
                    if ~isempty(obj.ID)
                        clearResourceSlot(obj.Parent, obj.ResourceOwner, obj.ID);
                    end
                    % Unconfigure Interrupt Pin.
                    if ~isempty(obj.Undo) && strcmp(interruptPinMode, 'CAN')
                        % Unconfigure Interrupt Pin only if it was
                        % configured before by ResourceOwner.
                        % Configuring to 'Unset' with ResourceOwner
                        % will make Arduino the owner of the pin.
                        overridePinResource(obj.Parent, obj.Undo(1).Pin, obj.ResourceOwner, obj.ResourceMode);
                        % configurePinInternal is needed for IOServer calls
                        % which happen during Unset.
                        configurePinInternal(obj.Parent, obj.Undo(1).Pin, 'Unset', 'canChannel', obj.ResourceOwner);
                        % After Arduino becomes the owner, configure it to
                        % the previous state with the previous resource.
                        if ~strcmp(obj.Undo(1).PrevPinMode, 'Unset')
                            % Perform configuration only if it is not unset
                            configurePinResource(obj.Parent, obj.Undo(1).Pin, obj.Undo(1).ResourceOwner, obj.Undo(1).PrevPinMode, false);
                        end
                    end
                end
            end
        end
    end

    methods(Access = protected)
        function oscFreq = validateOscFreq(obj, oscFreq)
            if ~isnumeric(oscFreq) || ~isscalar(oscFreq) || ~ismember(oscFreq, obj.OscillatorFrequencies)
                obj.localizedError('MATLAB:hwsdk:can:invalidOscFreq');
            end
        end

        function busSpeed = validateBusSpeed(obj, busSpeed)
            if ~isnumeric(busSpeed) || ~isscalar(busSpeed) || ~ismember(busSpeed, obj.BusSpeeds)
                obj.localizedError('MATLAB:hwsdk:can:invalidCANBusSpeed', matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.BusSpeeds));
            end
        end
    end
end
