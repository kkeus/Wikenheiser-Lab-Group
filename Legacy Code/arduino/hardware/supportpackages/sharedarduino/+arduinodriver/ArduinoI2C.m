classdef ArduinoI2C < matlabshared.ioclient.peripherals.I2C
    
    % Copyright 2019 The MathWorks, Inc.
    
    %#codegen
    methods
        function obj = ArduinoI2C()
            coder.allowpcode('plain');
        end
    end
    
    methods(Access = public)
        function status = setI2CFrequency(obj, varargin)
            coder.allowpcode('plain');
            status = uint8(0);
            if ~coder.target('MATLAB')
                status = setI2CFrequency@matlabshared.ioclient.peripherals.I2C(obj, varargin{:});
            else
                % No C function is present in Arduino IO Server for setting
                % bus speed
                return;
            end
        end
        
    end
end