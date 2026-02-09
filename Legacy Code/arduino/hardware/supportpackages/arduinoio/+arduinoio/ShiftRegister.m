classdef ShiftRegister < matlabshared.addon.LibraryBase & matlab.mixin.CustomDisplay & dynamicprops
%SHIFTREGISTER Create a shift register object.
%
% registerObj = shiftRegister(a, model, dataPin, clockPin, ...) creates a shift register object.

% Copyright 2018-2023 The MathWorks, Inc.

    properties(Access = private, Constant = true)
        SHIFT_REGISTER_WRITE       = hex2dec('F140')
        SHIFT_REGISTER_READ        = hex2dec('F141')
        SHIFT_REGISTER_RESET       = hex2dec('F142')
    end

    properties(Access = protected, Constant = true)
        LibraryName = 'ShiftRegister'
        DependentLibraries = {}
        LibraryHeaderFiles = ''
        CppHeaderFile = ''
        CppClassName = ''
    end

    properties(SetAccess = private, GetAccess = public)
        Model
        DataPin
        ClockPin
    end

    properties(Access = private, Constant = true)
        SupportedModels = {'74HC165', '74HC595', '74HC164'}
        ModelCodes = struct('MW_74HC165', 1, 'MW_74HC595', 2, 'MW_74HC164', 3)
        AvailableCounts = [8, 16, 24, 32, 40, 48, 56, 64]
        AvailablePrecisions = {'uint8', 'uint16', 'uint32', 'uint64'}
        PrecisionByteSize = struct('uint8', 8, 'uint16', 16, 'uint32', 32, 'uint64', 64)
    end

    properties(Access = private)
        ResourceOwner =  'ShiftRegister'
    end

    methods (Hidden, Access = public)
        function obj = ShiftRegister(parentObj, model, dataPin, clockPin, varargin)
            narginchk(4, 6);
            obj.Parent = parentObj;

            % Validate model
            try
                obj.Model = validatestring(model, obj.SupportedModels);
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegModel', ...
                                   ['''', strjoin(obj.SupportedModels, ''', '''), '''']);
            end

            % Validate pins
            % 1. validate data pin and clock pin
            [dataPin, ~, ~, ~] = getPinInfoHook(obj.Parent, dataPin);
            [clockPin, ~, ~, ~] = getPinInfoHook(obj.Parent, clockPin);
            obj.DataPin = char(dataPin);
            obj.ClockPin = char(clockPin);
            props = [obj.Parent.getPinNumber(obj.DataPin), obj.Parent.getPinNumber(obj.ClockPin)];
            % 2. validate other pins depending on model
            switch obj.Model
              case '74HC165'
                narginchk(6, 6);
                % validate load pin and clock enable pin
                loadPin = validateDigitalPin(obj.Parent, varargin{1});
                clockEnablePin = validateDigitalPin(obj.Parent, varargin{2});
                obj.LoadPin = char(loadPin);
                obj.ClockEnablePin = char(clockEnablePin);
                props = [props, obj.Parent.getPinNumber(obj.LoadPin), obj.Parent.getPinNumber(obj.ClockEnablePin)];
              case '74HC595'
                narginchk(5, 6);
                % validate latch pin and reset pin
                latchPin = validateDigitalPin(obj.Parent, varargin{1});
                obj.LatchPin = char(latchPin);
                props = [props, obj.Parent.getPinNumber(obj.LatchPin)];
                if nargin == 6
                    resetPin = validateDigitalPin(obj.Parent, varargin{2});
                    obj.ResetPin = char(resetPin);
                    props = [props, obj.Parent.getPinNumber(obj.ResetPin)];
                end
              case '74HC164'
                narginchk(4, 5);
                % validate reset pin
                if nargin == 5
                    resetPin = validateDigitalPin(obj.Parent, varargin{1});
                    obj.ResetPin = char(resetPin);
                    props = [props, obj.Parent.getPinNumber(obj.ResetPin)];
                end
              otherwise
                % Model already validated. Nothing to be done here.
            end

            % Check for duplicate pins
            uniqueprops = unique(props);
            if ~isequal(numel(uniqueprops), numel(props))
                obj.localizedError('MATLAB:hwsdk:general:duplicatePins', obj.ResourceOwner);
            end

            % Configure pin resources
            try
                [pin, ~, prevMode, ~] = getPinInfoHook(obj.Parent, obj.DataPin);
                if ismember(obj.Model, {'74HC595', '74HC164'})
                    obj.Undo(1) = configurePinInternal(obj.Parent, obj.DataPin, 'DigitalOutput', 'shiftRegister', obj.ResourceOwner);
                elseif ismember(obj.Model, {'74HC165'})
                    obj.Undo(1) = configurePinInternal(obj.Parent, obj.DataPin, 'DigitalInput', 'shiftRegister', obj.ResourceOwner);
                end
                [pin, ~, prevMode, ~] = getPinInfoHook(obj.Parent, obj.ClockPin);
                obj.Undo(2) = configurePinInternal(obj.Parent, obj.ClockPin, 'DigitalOutput', 'shiftRegister', obj.ResourceOwner);
                if isprop(obj, 'LoadPin')
                    [pin, ~, prevMode, ~] = getPinInfoHook(obj.Parent, obj.LoadPin);
                    obj.Undo(3) = configurePinInternal(obj.Parent, obj.LoadPin, 'DigitalOutput', 'shiftRegister', obj.ResourceOwner);
                end
                if isprop(obj, 'ClockEnablePin')
                    [pin, ~, prevMode, ~] = getPinInfoHook(obj.Parent, obj.ClockEnablePin);
                    obj.Undo(4) = configurePinInternal(obj.Parent, obj.ClockEnablePin, 'DigitalOutput', 'shiftRegister', obj.ResourceOwner);
                end
                if isprop(obj, 'LatchPin')
                    [pin, ~, prevMode, ~] = getPinInfoHook(obj.Parent, obj.LatchPin);
                    obj.Undo(5) = configurePinInternal(obj.Parent, obj.LatchPin, 'DigitalOutput', 'shiftRegister', obj.ResourceOwner);
                end
                if isprop(obj, 'ResetPin') && ~isempty(obj.ResetPin)
                    [pin, ~, prevMode, ~] = getPinInfoHook(obj.Parent, obj.ResetPin);
                    obj.Undo(6) = configurePinInternal(obj.Parent, obj.ResetPin, 'DigitalOutput', 'shiftRegister', obj.ResourceOwner);
                end
            catch e
                if strcmpi(e.identifier,'MATLAB:hwsdk:general:invalidResourceownerName')
                    % throw correct error for MKRZero pin D32. Details in g2052722
                    throwAsCaller(e);
                else
                    obj.localizedError('MATLAB:arduinoio:general:reservedShiftRegPins', char(pin), prevMode);
                end
            end
        end
    end

    %% Destructor
    methods (Access=protected)
        function delete(obj)
            try
                parentObj = obj.Parent;

                if isempty(obj.Undo)
                    % do nothing since constructor fails before configuring
                    % the pins
                else
                    % Construction failed, revert pins back to their
                    % original states
                    for idx = 1:numel(obj.Undo)
                        if all(structfun(@isempty, obj.Undo(idx)))
                            % Don't process for empty structs
                            continue;
                        end
                        % obj.ResourceOwner might be holding the pin.
                        % Configuring to 'Unset' with obj.ResourceOwner
                        % will make Arduino the owner of the pin.
                        configurePinInternal(parentObj, obj.Undo(idx).Pin, 'Unset', 'shiftRegister', obj.ResourceOwner);
                        % After Arduino becomes the owner, configure it to
                        % the previous state with the previous resource.
                        configurePinInternal(parentObj, obj.Undo(idx).Pin, obj.Undo(idx).PrevPinMode, 'shiftRegister', obj.Undo(idx).ResourceOwner);
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
        end
    end

    methods
        function set.Model(obj, model)
        % Add dynamic properties, e.g pins, depending on the model
            switch model
              case '74HC165'
                loadPin = addprop(obj, 'LoadPin');
                clockEnablePin = addprop(obj, 'ClockEnablePin');
                loadPin.SetAccess = 'private';
                clockEnablePin.SetAccess = 'private';
              case '74HC595'
                latchPin = addprop(obj, 'LatchPin');
                resetPin = addprop(obj, 'ResetPin');
                latchPin.SetAccess = 'private';
                resetPin.SetAccess = 'private';
              case '74HC164'
                resetPin = addprop(obj, 'ResetPin');
                resetPin.SetAccess = 'private';
              otherwise
            end
            obj.Model = model;
        end
    end

    % Hide inherited methods we don't want to show.
    methods (Hidden)
        function property = addprop(obj, prop)
        % provide access to the implementation
            property = obj.addprop@dynamicprops(prop);
        end
    end

    methods(Access = public)
        function dataOut = read(obj, precision)
        %   Read serial data from PISO type shift register.
        %
        %   Syntax:
        %   dataOut = read(registerObj)
        %   dataOut = read(registerObj, precision)
        %
        %   Description:
        %   Read serial data from the shift register device
        %
        %   Example:
        %       a = arduino();
        %       registerObj = shiftRegister(a, '74hc165', 'D3', 'D4', 'D5', 'D6');
        %       dataOut = read(registerObj);
        %
        %   Input Arguments:
        %   registerObj  - Shift register (model 74HC165)
        %   precision - Number of bits to read or precision of data (optional, multiple of 8 such as 8, 16 or 'uint8', 'uint16', 'uint32')
        %
        %   Example:
        %       a = arduino();
        %       registerObj = shiftRegister(a, '74hc165', 'D3', 'D4', 'D5', 'D6');
        %       dataOut = read(registerObj, 8);
        %       dataOut = read(registerObj, 'uint8')
        %
        %   Output Argument:
        %   dataOut   - Value(s) read from the register
        %
        %   See also write shiftRegister reset

        % This is needed for data integration
            if (nargin < 2)
                dprecision = "NA";
            else
                dprecision = precision;
            end

            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent,'ShiftRegister',dprecision));
            try
                narginchk(1, 2);
                % Only PISO types support read operation
                if ~ismember(obj.Model, {'74HC165'})
                    obj.localizedError('MATLAB:arduinoio:general:unsupportedShiftRegRead', obj.Model);
                end

                % Validate precision input
                if (nargin < 2)
                    precision = 8;
                    numBits = precision;
                else
                    numBits = validatePrecision(obj, precision);
                end

                numBytes = numBits/8;

                peripheralPayload = preparePayload(obj, numBytes);
                responsePeripheralPayloadSize = numBytes;
                output = rawRead(obj.Parent.Protocol, obj.SHIFT_REGISTER_READ, peripheralPayload, responsePeripheralPayloadSize);

                if ~ischar(precision)
                    dataOut = zeros(1, numBits);
                    % convert array of doubles into 2-D array of 1s or 0s
                    value = dec2bin(output, 8) - '0';
                    % convert to double vector starting from MSB
                    for iLoop = 1:numBytes
                        dataOut(8*(iLoop-1)+(1:8)) = value(numBytes-iLoop+1,:);
                    end
                    dataOut = flip(dataOut);
                else
                    dataOut = uint8(output);
                    dataOut = typecast(dataOut, precision);
                    dataOut = double(dataOut);
                end
            catch e
                integrateErrorKey(obj.Parent,e.identifier);
                throwAsCaller(e);
            end
        end

        function write(obj, value, precision)
        %   Write serial data to SIPO type shift register.
        %
        %   Syntax:
        %   write(registerObj,value)
        %   write(registerObj,value,precision)
        %
        %   Description:
        %   Write data with specified precision to the shift register
        %
        %   Example:
        %       a = arduino();
        %       registerObj = shiftRegister(a, '74hc595', 'D3', 'D4', 'D7');
        %       write(registerObj, 10);
        %       write(registerObj, '00001010')
        %       write(registerObj, [0 1 0 1 0 0 0 0])
        %
        %   Input Arguments:
        %   registerObj  - Shift register
        %   value     - Data to write to the shift register (double, hex, binary, character vector or string of 1's or 0's, or vector of 1's or 0's)
        %   precision - Precision of data to write to shift register (optional, character vector or string)
        %
        %   Example:
        %       a = arduino();
        %       registerObj = shiftRegister(a, '74hc595', 'D3', 'D4', 'D7');
        %       write(registerObj, 10, 'uint8')
        %       write(registerObj,'00001010', 'uint8');
        %       write(registerObj,[0 1 0 1 0 0 0 0], 'uint8');
        %       write(registerObj, 0xFF);
        %       write(registerObj, 0b10010001);
        %       write(registerObj, 0xFF, 'uint16');
        %       write(registerObj,0xFFFF);
        %       write(registerObj,uint16(256));
        %
        %   See also read, reset, shiftRegister

        % This is needed for data integration
            if (nargin < 3)
                dprecision = "NA";
            else
                dprecision = precision;
            end

            % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent,'ShiftRegister',dprecision));

            try
                narginchk(2, 3);
                % Only SIPO types support write operation
                if ~ismember(obj.Model, {'74HC595', '74HC164'})
                    obj.localizedError('MATLAB:arduinoio:general:unsupportedShiftRegWrite', obj.Model);
                end
                % Error out values typecasted to signed integer types, i.e.
                % user is not allowed to enter write values that are
                % typecasted to signed integer types (raised in g2072398)
                if ismember(class(value), {'int8','int16','int32','int64'})
                    obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegValue');
                end
                % Validate precision input
                if (nargin < 3)
                    numBits = 8;
                    % set default precision to 'uint8'
                    precision = 'uint8';
                    % set the precision equal to class of value
                    if ismember(class(value), {'uint16', 'uint32','uint64'})
                        precision = class(value);
                    end
                else
                    numBits = validatePrecision(obj, precision);
                end

                % Validate value input
                value = validateData(obj, value, numBits, precision);
                value = cast(value, precision);
                value = typecast(value, 'uint8');
                numBytes = numel(value);

                peripheralPayload = preparePayload(obj, [numBytes, value]);
                rawWrite(obj.Parent.Protocol, obj.SHIFT_REGISTER_WRITE, peripheralPayload);
            catch e
                integrateErrorKey(obj.Parent,e.identifier);
                throwAsCaller(e);
            end
        end

        function reset(obj)
        %   Clear all outputs of SIPO type shift register.
        %
        %   Syntax:
        %   reset(registerObj)
        %
        %   Description:
        %   Clear all outputs of shift register
        %
        %   Example:
        %       a = arduino();
        %       registerObj = shiftRegister(a, '74hc595', 'D3', 'D4', 'D7', 'D8');
        %       reset(registerObj);
        %
        %   Input Arguments:
        %   registerObj  - Shift register
        %
        %   See also read, write

        % Register on clean up for integrating all data
            c = onCleanup(@() integrateData(obj.Parent,'ShiftRegister','NA'));

            try
                % Only shift register with non-empty ResetPin support reset
                % operation
                if ~isprop(obj, 'ResetPin')
                    obj.localizedError('MATLAB:arduinoio:general:unsupportedShiftRegReset', obj.Model);
                end
                if isempty(obj.ResetPin)
                    obj.localizedError('MATLAB:arduinoio:general:shiftRegResetPinNotSpecified');
                end

                peripheralPayload = preparePayload(obj, []);
                rawWrite(obj.Parent.Protocol, obj.SHIFT_REGISTER_RESET, peripheralPayload);
            catch e
                integrateErrorKey(obj.Parent,e.identifier);
                throwAsCaller(e);
            end
        end
    end

    methods(Access = private)
        function payload = preparePayload(obj, inputs)
            dataTerminal = getPinNumber(obj.Parent, obj.DataPin);
            clockTerminal = getPinNumber(obj.Parent, obj.ClockPin);
            switch obj.Model
              case '74HC165'
                model = obj.ModelCodes.MW_74HC165;
                loadTerminal = getPinNumber(obj.Parent, obj.LoadPin);
                ceTerminal = getPinNumber(obj.Parent, obj.ClockEnablePin);
                payload = [model, dataTerminal, clockTerminal, loadTerminal, ceTerminal, inputs];
              case '74HC595'
                model = obj.ModelCodes.MW_74HC595;
                latchTerminal = getPinNumber(obj.Parent, obj.LatchPin);
                if ~isempty(obj.ResetPin)
                    resetTerminal = getPinNumber(obj.Parent, obj.ResetPin);
                    payload = [model, dataTerminal, clockTerminal, latchTerminal, 1, resetTerminal, inputs];
                else
                    payload = [model, dataTerminal, clockTerminal, latchTerminal, 0, inputs];
                end
              case '74HC164'
                model = obj.ModelCodes.MW_74HC164;
                if ~isempty(obj.ResetPin)
                    resetTerminal = getPinNumber(obj.Parent, obj.ResetPin);
                    payload = [model, dataTerminal, clockTerminal, 1, resetTerminal, inputs];
                else
                    payload = [model, dataTerminal, clockTerminal, 0, inputs];
                end
            end
        end

        function result = validatePrecision(obj, precision)
            try
                if isnumeric(precision)
                    % If precision is numeric, it has to be a multiple
                    % of 8, from 8 - 64
                    assert(ismember(precision, obj.AvailableCounts));
                    result = precision;
                else
                    if ischar(precision)
                        precision = string(precision);
                    end
                    result = validatestring(precision, obj.AvailablePrecisions, '', 'precision');
                    result = obj.PrecisionByteSize.(result);
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:unrecognizedStringChoice') ...  % Wrong string
                        || strcmp(e.identifier, 'MATLAB:ambiguousStringChoice') % Ambiguous string ('uint')
                    id = 'MATLAB:hwsdk:general:invalidPrecision';
                    e = MException(id, ...
                                   getString(message(id, char(strjoin(obj.AvailablePrecisions(), ', ')))));
                elseif strcmp(e.identifier, 'MATLAB:assertion:failed') ...      % Wrong number of bits.
                        || strcmp(e.identifier, 'MATLAB:assertion:LogicalScalar') % Invalid scalar value ([])
                    id = 'MATLAB:hwsdk:general:invalidPrecision';
                    e = MException(id, ...
                                   getString(message(id, ...
                                                     matlabshared.hwsdk.internal.renderArrayOfIntsToString(obj.AvailableCounts))));
                end
                throwAsCaller(e);
            end
        end

        function value = validateData(obj, value, numBits, precision)
            try
                % accept string type value but convert to character vector
                if isstring(value)
                    value = char(value);
                end
                if ischar(value)
                    % error out if user enters whitespaces
                    idWhiteSpaces = find(value == ' ', 1);
                    if ~isempty(idWhiteSpaces)
                        obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegWriteNumBits');
                    end

                    if numel(value) ~= numBits
                        obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegWriteNumBits');
                    end
                    value = bin2dec(value);
                else
                    len = numel(value);
                    if len == 1 % scalar
                                % check to see if scalar is within the range of precision
                        value = matlabshared.hwsdk.internal.validateIntParameterRanged('Write', value, intmin(precision), intmax(precision));
                    else % vector
                         % check to see if vector length matches with
                         % precision and is consisted of 1's or 0's
                        if len ~= numBits
                            obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegWriteNumBits');
                        end
                        validateattributes(value, {'double', 'uint8', 'uint16', 'uint32', 'uint64'}, {'vector', 'integer', '<=', 1, '>=', 0});
                        % convert vector of 1 or 0 to double scalar
                        strValue = num2str(flip(value));
                        strValue(isspace(strValue))='';
                        value = bin2dec(strValue);
                    end
                end
            catch e
                if ~ismember(e.identifier, {'MATLAB:arduinoio:general:invalidShiftRegWriteNumBits', ...
                                            'MATLAB:hwsdk:general:invalidIntValueRanged'})
                    obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegValue');
                else
                    throwAsCaller(e);
                end
            end
        end
    end

    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);

            % Display main options
            fprintf('           Model: %-15s\n', ['''', obj.Model, '''']);
            fprintf('         DataPin: %-15s\n', ['''', obj.DataPin, '''']);
            fprintf('        ClockPin: %-15s\n', ['''', obj.ClockPin, '''']);
            switch obj.Model
              case '74HC165'
                fprintf('         LoadPin: %-15s\n', ['''', obj.LoadPin, '''']);
                fprintf('  ClockEnablePin: %-15s\n', ['''', obj.ClockEnablePin, '''']);
              case '74HC595'
                fprintf('        LatchPin: %-15s\n', ['''', obj.LatchPin, '''']);
                if isempty(obj.ResetPin)
                    fprintf('        ResetPin: Not specified\n');
                else
                    fprintf('        ResetPin: %-15s\n', ['''', obj.ResetPin, '''']);
                end
              case '74HC164'
                if isempty(obj.ResetPin)
                    fprintf('        ResetPin: Not specified\n');
                else
                    fprintf('        ResetPin: %-15s\n', ['''', obj.ResetPin, '''']);
                end
            end
            fprintf('\n');

            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end
