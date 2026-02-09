%

%   Copyright 2017-2023 The MathWorks, Inc.

classdef (Abstract)device < matlabshared.addon.LibraryBase

% Developer Interface
    properties(GetAccess = public, SetAccess = protected)
        %Interface - Specifies Interface for device of Hardware obj
        Interface matlabshared.hwsdk.internal.InterfaceEnum
    end

    properties(GetAccess = protected, SetAccess = private)
        % IsPinConfigurable - Specifies if pins of an interface is
        % configurable or not. Used by this and its subclasses for
        % configuration and unconfiguration purposes.
        IsPinConfigurable = true
    end

    properties (Access = protected)
        % ResourceOwner - Owner of a resource (pin). Used only with
        % configuration logic.
        ResourceOwner string
    end

    methods (Abstract, Access = protected)
        getDevicePinWithLabelImpl(obj);
    end

    methods(Hidden, Access = public)
        function obj = device(varargin)
            parent = varargin{1};
            if ~isa(parent, 'matlabshared.hwsdk.controller') &&...
                    ~isa(parent, 'matlabshared.i2c.controller') &&...
                    ~isa(parent, 'matlabshared.spi.controller') &&...
                    ~isa(parent, 'matlabshared.serial.controller')
                error(['The first parameter, ''' class(parent) ''' is not a compatible hardware.']);
            end

            obj.Parent = parent;
        end

        function values = getDeviceResourceProperty(obj, resourceName, resourceProperty)
        % Fetch values stored in resource properties
        % Nomenclature:
        % Example: I2CBus1.i2cAddresses=50
        % ResourceName - I2CBus1 - string
        % ResourceProperty - i2cAddresses - string
        % ResourceValue - 50 - any
            values = [];
            % Validate resource name and property to be string
            assert(isstring(resourceName), 'ResourceName must be a string');
            assert(isstring(resourceProperty), 'ResourcePropertyName must be a string');
            % Fetch information if availabile
            if numEntries(obj.Parent.DeviceDictionary) && isKey(obj.Parent.DeviceDictionary, resourceName)
                % Example: I2CBus1. Expected to be a struct.
                resource = obj.Parent.DeviceDictionary(resourceName);
                assert(isstruct(resource), 'Resource must be a struct');
                % Get the value from property if available.
                if isfield(resource, resourceProperty)
                    values = resource.(resourceProperty);
                end
            end
        end

        function setDeviceResourceProperty(obj, resourceName, resourceProperty, resourceValue)
        % Set values to resource properties
        % Nomenclature:
        % Example: I2CBus1.i2cAddresses=50
        % ResourceName - I2CBus1 - string
        % ResourceProperty - i2cAddresses - string
        % ResourceValue - 50 - any
        % Validate resource name and property to be string
            assert(isstring(resourceName), 'ResourceName must be a string');
            assert(isstring(resourceProperty), 'ResourcePropertyName must be a string');
            % Default resource to struct.
            resource = struct;
            % If resource is already available, retrieve it.
            if numEntries(obj.Parent.DeviceDictionary) && isKey(obj.Parent.DeviceDictionary, resourceName)
                resource = obj.Parent.DeviceDictionary(resourceName);
                assert(isstruct(resource), 'Resource must be a struct');
            end
            % Update property
            resource.(resourceProperty) = resourceValue;
            % Add resource back to the dictionary.
            obj.Parent.DeviceDictionary(resourceName) = resource;
        end

        function configurePins(obj, pins)
        % configures pins for rawDevice based peripherals.
        % INPUTS:
        %   obj (matlabshared.rawDevice.device)
        %   pins - cell array of all pins that need to be configured
        % OUTPUTS:
        %   none
            obj.IsPinConfigurable = isPinConfigurableHook(obj.Parent, Interface=obj.Interface, Pin=pins);
            if obj.IsPinConfigurable
                iUndo = 0;
                % HWSDK is internal and its okay to just assert
                assert(iscell(pins), 'pins input must be a cell array');
                % Row based
                assert(size(pins, 1) == 1);
                caller = strcat(lower(string(obj.Interface)), ".device");
                for pin = pins  % foreach
                    [~, ~, pinMode, pinResourceOwner] = getPinInfoHook(obj.Parent, pin{:});
                    iUndo = iUndo + 1;
                    % Proceed only if the pins are Unset or already
                    % configured by hardware
                    if (strcmp(pinMode, string(obj.Interface)) && strcmp(pinResourceOwner, '')) || ...
                            strcmp(pinMode, 'Unset')
                        if ~strcmp(pinMode, 'Unset')
                            % Take the ownership from hardware if HW is
                            % the resourceowner, by configuring to Unset.
                            configurePinInternal(obj.Parent, pin{:}, 'Unset', caller);
                        end
                        try
                            pinStatus = configurePinInternal(obj.Parent, pin{:}, string(obj.Interface), caller, obj.ResourceOwner);
                        catch e
                            switch e.identifier
                              case 'MATLAB:hwsdk:general:reservedPin'
                                reservedPin = extractBetween(e.message, 'Pin ', ' was');
                                if any(contains(reservedPin{:}, [pins{:}]))
                                    % If the reservedPin is part of pins
                                    % providing the interface, then throw
                                    % the protocol level error.
                                    % Get the pin mode before throwing an error.
                                    pinMode = configurePinInternal(obj.Parent,reservedPin{:});
                                    throwReservedDevicePins(obj, reservedPin{:}, pinMode);
                                end
                              otherwise
                            end
                            % Otherwise throw pin level error.
                            throwAsCaller(e);
                        end
                        obj.Undo(iUndo) = pinStatus;
                    elseif (strcmp(pinMode, string(obj.Interface)) && strcmp(pinResourceOwner, obj.ResourceOwner))
                        % If Pin is already configured by SPI, just
                        % retain the current values for later use
                        % in destructor.
                        obj.Undo(iUndo).Pin = pin{:};
                        obj.Undo(iUndo).ResourceOwner = obj.ResourceOwner;
                        obj.Undo(iUndo).PrevPinMode = string(obj.Interface);
                    else
                        throwReservedDevicePins(obj, pin{:}, pinMode);
                    end
                end
            end
        end
    end

    methods (Access = private)
        function throwReservedDevicePins(obj, pin, pinMode)
            obj.localizedError('MATLAB:hwsdk:general:reservedDevicePins', ...
                               char(obj.Parent.getBoardNameHook), ...
                               char(getDevicePinWithLabelImpl(obj)), ...
                               char(string(obj.Interface)), ...
                               char(pin), ...
                               char(pinMode));
        end
    end

    methods (Access = private, Static = true)
        function name = matlabCodegenRedirect(~)
            name = 'matlabshared.coder.rawDevice.device';
        end
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})
        function init(obj, varargin)
            if (nargin < 1)
                obj.localizedError('MATLAB:minrhs');
            end

            parent = varargin{1};
            if ~isa(parent, 'matlabshared.hwsdk.controller')
                error(['' class(parent) ''' is not a compatible hardware for use with this sensor.']);
            end
            obj.Parent = parent;

            p = inputParser;

            if isa(obj, 'matlabshared.i2c.peripheral') && isa(obj.Parent, 'matlabshared.i2c.controller')
                addParameter(p, 'I2CAddress', []);
            end

            if isa(obj, 'matlabshared.spi.peripheral')&& isa(obj.Parent, 'matlabshared.spi.controller')
                addParameter(p, 'SPIChipSelectPin', []);
            end

            if isa(obj, 'matlabshared.adc.peripheral')&& isa(obj.Parent, 'matlabshared.adc.controller')
                addParameter(p, 'AnalogPin', []);
            end

            parse(p, varargin{2:end});

            if sum(structfun(@(x) ~isempty(x), p.Results)) > 1
                error(['Invalid NV pair combination, only ONE of the ' ...
                       '' arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', ') '' ...
                       ' NV pairs may be specified.']);
            end

            if sum(structfun(@(x) ~isempty(x), p.Results)) == 0
                if isa(obj, 'matlabshared.i2c.peripheral') && isa(obj.Parent, 'matlabshared.i2c.controller')
                    i2cDeviceAddresses = arrayfun(@(x) matlabshared.hwsdk.internal.validateHexParameterRanged('I2CAddress', x, 0, 255), obj.Parent.scanI2CBus, 'UniformOutput', true);
                    validAddresses = intersect(i2cDeviceAddresses, obj.getI2CAddressSpace);
                    if numel(validAddresses) > 0
                        varargin{end+1} = 'I2CAddress';
                        varargin{end+1} = validAddresses(1);
                    else
                        error('I2C device requires specification of "I2CAddress" parameter');
                    end
                elseif isa(obj, 'matlabshared.spi.peripheral')&& isa(obj.Parent, 'matlabshared.spi.controller')
                    error('SPI device requires specification of "SPIChipSelectPin" parameter');
                elseif isa(obj, 'matlabshared.adc.peripheral')&& isa(obj.Parent, 'matlabshared.adc.controller')
                    error('Analog device requires specification of "AnalogPin" parameter');
                end
            end

            results = find(structfun(@(x) ~isempty(x), p.Results));

            if isempty(results)
                error(['Protocol parameters missing. Valid parameters are ''' ...
                       arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', ') ...
                       '''']);
            end

            if numel(results) > 1
                error(['Invalid protocol parameters specified, only one of the ' ...
                       '' arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', ') '' ...
                       ' name/value pairs may be specified.']);
            end

            switch p.Parameters{results(1)}
              case "I2CAddress"
                interface = "i2c";
              case "SPIChipSelectPin"
                interface = "spi";
              case "SerialPort"
                interface = "serial";
              otherwise
                error('Internal Error');
            end

            obj.Interface = interface;
            obj.Device = parent.getDevice(interface, varargin{:});

            prop = properties(obj.Device);
            for i = 1:numel(prop)
                p = addprop(obj, prop{i});
                p.Dependent = true;
                p.SetAccess = 'private';
                p.GetMethod = @(x) obj.Device.(prop{i});
            end
        end
    end

    % User Interface
    methods(Abstract, Access = public)
        data = read(obj, varargin);
        write(obj, varargin);
    end
end

% LocalWords:  matlabshared hwsdk spi adc CAddress
