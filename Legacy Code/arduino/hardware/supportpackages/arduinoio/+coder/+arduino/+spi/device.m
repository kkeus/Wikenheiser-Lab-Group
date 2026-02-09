classdef device < matlabshared.coder.spi.device
    
    % This is a temporary change to tackle the incompatibility of Arduino
    % Simulink target. This will be removed as soon as Arduino targets C
    % driver is updated.
    
    % Copyright 2019-2020 The MathWorks, Inc.
    
    %#codegen
    
    methods
        function obj = device(varargin)
            % For arduino, the "ActiveLevel" and "Bus" are not supported as
            % N-V pair. The following parser only ensures that these two
            % parameters are not provided as input arguments. After this
            % check the parsing actually happens in the super class.
            parms = struct('SPIChipSelectPin', uint32(0), ...
                'SPIMode', uint32(0), 'BitOrder', uint32(0), 'BitRate', uint32(0));
            poptions = struct('CaseSensitivity',false, 'PartialMatching','unique', ...
                'StructExpand',false);
            coder.internal.parseParameterInputs(parms,poptions,varargin{2:end});  % First element is hardware object
            obj@matlabshared.coder.spi.device(varargin{:});
        end
    end
    
    methods(Access = protected)
        function dataOut = writeReadHook(obj, dataIn, precision)
            % In run-time it is not possible to throw any error. In that
            % case clip the data in the range [0, maxValue]
            castData = cast(dataIn, char(precision));
            dataTowrite = typecast(castData, 'uint8');
            returnedData = writeReadSPI(obj.SPIDriverObj, obj.SPIChipSelectPinInternal, dataTowrite);
            if strcmpi(char(precision), 'uint8')
                % For uint8 data type no typecasting is
                % required
                dataOut = returnedData;
            else
                dataOut = typecast(returnedData, precision);
            end
        end
    end
end