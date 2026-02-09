classdef controller < matlabshared.serial.controller_base
% hwsdk controller class

%   Copyright 2019-2023 The MathWorks, Inc.
    properties(GetAccess = public, SetAccess = {?matlabshared.hwsdk.internal.base})
        AvailableSerialPortIDs double
    end

    properties(Access = private, Constant = true)
        SerialBaudRate = 9600
    end

    properties (Access = private)
        PortValidator
    end

    methods(Access = public, Hidden)
        function obj = controller()
            type = getSerialPortTypeImpl(obj);
            switch(type)
              case "numeric"
                obj.PortValidator = matlabshared.hwsdk.internal.NumericValidator;
              case "string"
                obj.PortValidator = matlabshared.hwsdk.internal.StringValidator;
              otherwise
                assert(false, 'This Serial Port type is not supported');
            end
        end
    end


    properties (Constant, Hidden)

        FlowControlOptions = {'none', 'hardware', 'software'} % check if required
        ParityOptions = {'none', 'even', 'odd'}
        StopBitsOptions = [1 1.5 2]
        DataBitOptions = [5 6 7 8 9]
        SupportedBaudRates = [300 600 1200 2400 4800 9600 14400 19200 28800 38400 57600 115200]
        MaxSerialBufferSize = 2^8

    end

    properties (Constant, Hidden)
        % DefaultTimeout - Default read/write timeout to 10 sec
        DefaultTimeout = 10
    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base, ?matlabshared.sensors.internal.Accessor})

        function buses = getAvailableSerialPortIDs(obj)
            buses = obj.getAvailableSerialPortIDsHook();
        end

    end

    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})

        function serialPinsArray = getAvailableSerialPins(obj)
            serialPinsArray = getAvailableSerialPinsImpl(obj);
            assert(isempty(serialPinsArray) || isstruct(serialPinsArray), 'getAvailableSerialPins: serialPinsArray is expected to be empty or struct');
            if ~isempty(serialPinsArray)
                assert(size(serialPinsArray, 1) == 1, 'getAvailableSerialPins: serialPinsArray is expected to be a row vector'); % Row based
                assert(isfield(serialPinsArray, 'TxPin'), 'getAvailableSerialPins: serialPinsArray is expected to have TxPin as one of its fields');
                assert(isfield(serialPinsArray, 'RxPin'), 'getAvailableSerialPins: serialPinsArray is expected to have RxPin as one of its fields');
                assert(~isempty([serialPinsArray.TxPin]), 'getAvailableSerialPins: TxPin must not be empty');
                assert(~isempty([serialPinsArray.RxPin]), 'getAvailableSerialPins: RxPin must not be empty');
                pinValidatingHandle = getSerialPinTypeValidator(obj.PinValidator);
                assert(all(pinValidatingHandle([serialPinsArray.TxPin])), ['getAvailableSerialPins: TxPin must satisfy ' char(pinValidatingHandle)]);
                assert(all(pinValidatingHandle([serialPinsArray.RxPin])), ['getAvailableSerialPins: RxPin must satisfy ' char(pinValidatingHandle)]);
            end
        end

        function maxSerialReadWriteBufferSize = getMaxSerialReadWriteBufferSize(obj)
            maxSerialReadWriteBufferSize = obj.getMaxSerialReadWriteBufferSizeHook();
            assert(isnumeric(maxSerialReadWriteBufferSize));
            assert(isscalar(maxSerialReadWriteBufferSize));
        end
        function supportedBaudRates = getSupportedBaudRates(obj)
            supportedBaudRates =  obj.getSupportedBaudRatesHook;
        end

        function supportedParityOptions = getSupportedParity(obj)
            supportedParityOptions=  getSupportedParityHook(obj);
        end

        function supportedDataBitOptions = getSupportedDataBits(obj)
            supportedDataBitOptions = getSupportedDataBitsHook(obj);
        end

        function supportedStopBitOptions = getSupportedStopBits(obj)
            supportedStopBitOptions = getSupportedStopBitOptionsHook(obj);
        end

        function supportedTimeOut = getSupportedTimeOut(~)
            supportedTimeOut = [0 8];
        end

        function availableSerialPrecisions = getAvailableSerialPrecisions(obj)
            availableSerialPrecisions = obj.getAvailableSerialPrecisionsHook;
            assert(isstring(availableSerialPrecisions));
        end

        % To resolve ambiguous error message when no value is provided for
        % mandatory NV Pair, this validation need to be accessible by
        % controller.
        function status = validateDeviceSerialPort(obj, serialPort)
            status = false; %#ok<NASGU>
            validateSerialPort(obj.PortValidator, serialPort, obj.Board, obj.getAvailableSerialPortIDs);
            status = true;
        end
    end

    methods(Access = protected)
        function supportedBaudRates = getSupportedBaudRatesHook(obj)
            supportedBaudRates =  obj.SupportedBaudRates;
        end

        function supportedParityOptions = getSupportedParityHook(obj)
            supportedParityOptions=  obj.ParityOptions;
        end

        function supportedDataBitOptions = getSupportedDataBitsHook(obj)
            supportedDataBitOptions =  obj.DataBitOptions;
        end

        function supportedStopBitOptions = getSupportedStopBitOptionsHook(obj)
            supportedStopBitOptions =  obj.StopBitOptions;
        end

        function buses = getAvailableSerialPortIDsHook(obj)
            serialPinsArray = obj.getAvailableSerialPins();
            buses = [];
            if numel(serialPinsArray) > 0
                buses = 1:numel(serialPinsArray);
            end
        end

        function defaultBaudRate = getSerialDefaultBaudRateHook(obj)
            defaultBaudRate = obj.SerialBaudRate;
        end

        function maxSerialBufferSize = getMaxSerialReadWriteBufferSizeHook(obj)
        % Assume 256 byte buffer length
            maxSerialBufferSize = obj.MaxSerialBufferSize;
        end

        function availableSerialPrecisions = getAvailableSerialPrecisionsHook(obj)
            availableSerialPrecisions = [obj.getAvailablePrecisions];
        end
    end

end

% LocalWords:  dev cdev matlabshared CBus CIs
