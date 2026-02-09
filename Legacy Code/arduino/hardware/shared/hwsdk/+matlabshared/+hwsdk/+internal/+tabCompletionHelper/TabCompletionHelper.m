classdef TabCompletionHelper < matlabshared.hwsdk.internal.base
% helper class for dynamic input arguments' values for
% resources/functionSignatures.json of hwsdk

% Copyright 2018-2024 The MathWorks, Inc.

    methods (Static)
        function formats =  readVoltageOutputFormat
            formats = {'matrix' ,'timetable'};
        end
        function modes = getSupportedPinModes(hardwareObj)
        %GETSUPPORTEDPINMODES Gets the pin modes supported by the
        %hardware (microbit, arduino)
        %   Pins of different hardware have different functionalities
        %   multiplexed. We notice them as modes. This function gets
        %   all the different modes supported by a hardware.
            modes = hardwareObj.getSupportedModes();
        end

        function precisions = getAvailableI2CPrecisions(i2cObj)
        %GETAVAILABLEI2CPRECISIONS Gets the datatypes supported by I2C
        %device
            precisions = i2cObj.Parent.getAvailableI2CPrecisions();
        end

        function precisions = getAvailableSerialPrecisions(serialObj)
        %GETAVAILABLEI2CPRECISIONS Gets the datatypes supported by I2C
        %device
            precisions = serialObj.Parent.getAvailableSerialPrecisions();
        end

        function baudRate = getAvailableBaudRates(hardwareObj)
        %GETAVAILABLEBaudRates  Gets the baud rates supported by
        %serial device
            baudRate= hardwareObj.getSupportedBaudRates();
        end

        function parity = getAvailableParity(hardwareObj)
        %GETAVAILABLEParity  Gets the parity supported by
        %serial device
            parity= hardwareObj.getSupportedParity();
        end

        function dataBits = getAvailableDataBits(hardwareObj)
        %GETAVAILABLEDataBits  Gets the databits supported by
        %serial device
            dataBits= hardwareObj.getSupportedDataBits();
        end

        function stopBits = getAvailableStopBits(hardwareObj)
        %GETAVAILABLEstopBits  Gets the stopbits supported by
        %serial device
            stopBits= hardwareObj.getSupportedStopBits();
        end

        function precisions = getAvailableSPIPrecisions(spiObj)
        %GETAVAILABLESPIPRECISIONS Gets the datatypes supported by SPI
        %device
            precisions = spiObj.Parent.getAvailableSPIPrecisions();
        end

        function libraries = getAllLibraries(obj)
        %GETALLLIBRARIES Gets all libraries available
            libraries = obj.getAllLibraries();
        end

        function libraries = getValidAddonLibraries(obj)
        %Gets all addon libraries available on hardware
            libraries = obj.getValidAddonLibraries();
        end

        function i2cAddresses = getConnectedI2CDevices(obj)
        %GETCONNECTEDI2CDEVICES Gets all I2C devices connected to all
        %the I2C buses of the hardware
            i2cAddresses = [];
            I2CBuses = obj.AvailableI2CBusIDs;
            for busNumber = I2CBuses
                try
                    connectedAddresses = scanI2CBus(obj, busNumber);
                catch
                    % scanI2CBus errors out when no device is connected
                    % Do nothing to continue scanning in the next buses
                    connectedAddresses = [];
                end
                i2cAddresses = [i2cAddresses; connectedAddresses]; %#ok<AGROW>
            end
        end

        function digitalPins = getSupportedDigitalPins(obj)
            digitalPins = obj.getPinsSupportedForDigitalOperations();
        end
    end
end
