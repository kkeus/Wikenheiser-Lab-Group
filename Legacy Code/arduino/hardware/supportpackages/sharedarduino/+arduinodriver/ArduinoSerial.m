classdef ArduinoSerial < matlabshared.ioclient.peripherals.SCI
    % This file provides the internal APIs for Serial read and write
    % operation on Arduino. The APIs are called by HWSDK and Device driver
    
    % Copyright 2019-2023 The MathWorks, Inc.
    
    %#codegen
    
    methods(Access = public)
        
        function obj = ArduinoSerial()
            coder.allowpcode('plain');
        end
        function varargout = openSCIBusInternal(obj, varargin)
            if ~coder.target('MATLAB')
                if nargin<2
                    return;
                end
                port = varargin{1};
                if ~isnumeric(port)
                    return;
                end
                coder.cinclude('MW_SerialWrite.h');
                coder.cinclude('MW_SerialRead.h');
                coder.ceval('MW_SCI_Open', uint8(port));
            elseif coder.target('MATLAB')
                status = openSCIBusInternal@matlabshared.ioclient.peripherals.SCI(obj, varargin{:});
                if nargout>1
                    varargout{1} = status;
                end
            end
        end
        
        function [data, status, timestamp] = sciReceiveBytesInternal(obj, varargin)
            timestamp = 0;
            if ~coder.target('MATLAB')
                port = varargin{1};
                dataSizeInBytes = varargin{2};
                dataLength = varargin{3};
                dataType = varargin{4};
                if nargin<6
                    header='';
                end
                if nargin<7
                    terminator='';
                end
                if nargin<8
                    dataLengthOption='Length via dialog';
                end
                if nargin<9
                    timeout=0;
                end
                if nargin<10
                    dataTypeWidth=1;
                end
                if nargin==10
                    header = varargin{5};
                    terminator = varargin{6};
                    dataLengthOption = varargin{7};
                    timeout = varargin{8};
                    dataTypeWidth = varargin{9};
                end
                switch(dataType)
                    case 'boolean'
                        % 'boolean' is not a valid datatype argument in
                        % cast function
                        data = false(dataLength, 1);
                    otherwise
                        data = cast(zeros(dataLength, 1), dataType);
                end
                status = uint8(0);
                if(strcmpi(dataLengthOption,'Variable length'))
                    coder.ceval('MW_Serial_readVariableLength',uint8(port),uint16(dataSizeInBytes),coder.wref(data),coder.wref(status),...
                        coder.rref(terminator), length(terminator),coder.rref(header), length(header), uint16(timeout), uint8(dataTypeWidth));
                else
                    coder.ceval('MW_Serial_read',uint8(port),uint16(dataSizeInBytes),coder.wref(data),coder.wref(status),...
                        coder.rref(terminator), length(terminator),coder.rref(header), length(header));
                end
            else
                [data, status,timestamp] = sciReceiveBytesInternal@matlabshared.ioclient.peripherals.SCI(obj, varargin{:});
            end
        end
        
        function varargout = sciTransmitBytesInternal(obj, varargin)
            if ~coder.target('MATLAB')
                % Code generation deos not return any status
                port = varargin{1};
                dataIn = varargin{2};
                if nargin < 4
                    % If dataSize in bytes is not specified, assume that
                    % the data is in uint8. dataSize in bytes should also
                    % be consistent (i.e. 1). Arduino Simulink block
                    % provides all the input arguments. But MATLAB APIs
                    % does not need to pass all.
                    dataSizeInBytes = 1; % uint8
                    dataType = 0;
                end
                if nargin < 5
                    sendModeEnum = 0; % Default write
                end
                if nargin < 6
                    % If dataType is not specified, assume that the data is
                    % in uint8. dataSize in bytes should also be consistent
                    % (i.e. 1). Arduino Simulink block provides all the
                    % input arguments. But MATLAB APIs does not need to
                    % pass all.
                    dataSizeInBytes = 1; % uint8
                    dataType = 0;
                end
                if nargin < 7
                    sendFormatEnum = 0; % Decimal by default
                end
                if nargin < 8
                    floatprecision = 2;
                end
                if nargin < 9
                    labelTerminated = ''; % null character by default
                end
                if nargin < 10
                    terminator = '';
                end
                if nargin < 11
                    header = '';
                end
                if nargin == 11
                    dataSizeInBytes = varargin{3};
                    sendModeEnum = varargin{4};
                    dataType = varargin{5};
                    sendFormatEnum = varargin{6};
                    floatprecision = varargin{7};
                    labelTerminated = varargin{8};
                    terminator = varargin{9};
                    header = varargin{10};
                end
                
                coder.ceval('MW_Serial_write', port, ...
                    coder.ref(dataIn), numel(dataIn), dataSizeInBytes, ...
                    sendModeEnum, dataType, sendFormatEnum, ...
                    floatprecision, labelTerminated, coder.rref(terminator), length(terminator),...
                    coder.rref(header), length(header));
            else
                status = sciTransmitBytesInternal@matlabshared.ioclient.peripherals.SCI(obj, varargin{:});
                if nargout>1
                    varargout{1} = status;
                end
            end
        end
        
        function sciCloseInternal(obj, varargin)
            if ~coder.target('MATLAB')
                % Do nothing for code generation.
            else
                sciCloseInternal@matlabshared.ioclient.peripherals.SCI(obj, varargin{:});
            end
        end
    end
end