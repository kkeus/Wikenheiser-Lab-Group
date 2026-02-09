classdef controller < handle
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    %#codegen
    
    properties
        AvailableSerialPortIDs
    end
    properties(Access = private, Constant = true)
        SerialBaudRate = 9600
    end
    
    methods(Abstract, Access = protected)
        pins = getAvailableSerialPinsImpl(obj)
    end
    
    methods(Access = public)
        function buses = getAvailableSerialPortIDs(obj)
            buses = obj.getAvailableSerialPortIDsHook();
        end
        
        function serialPinsArray = getAvailableSerialPins(obj)
            serialPinsArray = getAvailableSerialPinsImpl(obj);
        end
        function availableSerialPrecisions = getAvailableSerialPrecisions(obj)
            availableSerialPrecisions = obj.getAvailableSerialPrecisionsHook();
        end
        
        function defaultBaudRate = getSerialDefaultBaudRate(obj)
            defaultBaudRate = obj.getSerialDefaultBaudRateHook();
        end
        
        function serialDriverObj = getSerialDriverObj(obj)
            serialDriverObj = getSerialDriverObjHook(obj);
        end
        
        function supportedTimeOut = getSupportedTimeOut(~)
            supportedTimeOut = [0 8];
        end
    end
    methods(Access = protected)
        
        function buses = getAvailableSerialPortIDsHook(obj)
            serialPinsArray = obj.getAvailableSerialPins();
            if numel(serialPinsArray) > 0
                buses = 0:(numel(serialPinsArray)-1);
            else
                buses = [];
            end
        end
        
        function defaultBaudRate = getSerialDefaultBaudRateHook(obj)
            defaultBaudRate = obj.SerialBaudRate;
        end
        
        function availableSerialPrecisions = getAvailableSerialPrecisionsHook(obj)
            availableSerialPrecisions = obj.getAvailablePrecisions();
        end
        
        function serialDriverObj = getSerialDriverObjHook(~)
            serialDriverObj = matlabshared.devicedrivers.coder.SCI;
        end
    end
end