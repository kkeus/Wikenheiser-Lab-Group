classdef ArduinoSPI < matlabshared.ioclient.peripherals.SPI
% ArduinoSPI: It is the device driver for SPI devices connected to
% Arduino. It provides internal APIs for IO and code generation.

% Copyright 2019-2023 The MathWorks, Inc.

%#codegen


    methods(Access = public)
        function obj = ArduinoSPI()
            coder.allowpcode('plain');
        end

        function status = openSPI(obj, varargin) % SPIModule, SDOPin, SDIPin, SCLK, chipSelectPin, isActiveLowSSPin
            if ~coder.target('MATLAB')
                coder.cinclude('MW_SPIwriteRead.h');
                chipSelectPin = varargin{5};
                coder.ceval('MW_SSpinSetup', uint8(chipSelectPin));
                status = [];
            else
                status = openSPI@matlabshared.ioclient.peripherals.SPI(obj, varargin{:});
            end
        end

        function setFormatSPI(obj, varargin)
            if ~coder.target('MATLAB')
                % Do nothing
            else
                setFormatSPI@matlabshared.ioclient.peripherals.SPI(obj, varargin{:});
            end
        end

        function setBusSpeedSPI(obj, varargin)
            if ~coder.target('MATLAB')
                % Do nothing
            else
                setBusSpeedSPI@matlabshared.ioclient.peripherals.SPI(obj, varargin{:});
            end
        end

        function [outputData, varargout] = writeReadSPI(obj, varargin)
            if ~coder.target('MATLAB')
                chipSelectPin = varargin{1};
                dataIn = varargin{2};
                if nargin == 4
                    spiModule = varargin{3};
                end
                dataLength = numel(dataIn);
                switch class(dataIn)
                  case 'uint8'
                    outputData = uint8(zeros(1, dataLength));
                    dataType = 1;
                  case 'uint16'
                    outputData = uint16(zeros(1, dataLength));
                    dataType = 2;
                  case 'uint32'
                    outputData = uint32(zeros(1, dataLength));
                    dataType = 3;
                  otherwise
                    outputData = uint8(zeros(1, dataLength));
                    dataType = 1;
                end
                coder.cinclude('MW_SPIwriteRead.h');
                if nargin == 4
                    coder.ceval('MW_SPIwriteReadLoop', uint8(spiModule), uint8(chipSelectPin), ...
                        coder.rref(dataIn), dataLength, dataType, coder.wref(outputData));
                else
                    % Default to module 0
                    coder.ceval('MW_SPIwriteReadLoop', uint8(0), uint8(chipSelectPin), ...
                        coder.rref(dataIn), dataLength, dataType, coder.wref(outputData));
                end
            else
                [outputData, writeStatus] = writeReadSPI@matlabshared.ioclient.peripherals.SPI(obj, varargin{:});
                if(nargout == 2)
                    varargout{1} = writeStatus;
                end
            end

        end

        function getStatusSPI(~, varargin)
        % No implementation for Arduino
        end

        function status = closeSPI(obj, varargin)
            if ~coder.target('MATLAB')
                % Do nothing
            else
                status = closeSPI@matlabshared.ioclient.peripherals.SPI(obj, varargin{:});
            end
        end

        function setSlaveSelectSPI(~, varargin)
        % No implementation for Arduino
        end
    end
end
