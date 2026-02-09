classdef debugMessage < matlabshared.ioclient.debugMessage
    
    % This class is referred by IOProtocol.m for printing debug messages for Arduino
    
    %   Copyright 2018-2019 The MathWorks, Inc.

    properties(Access = protected)
        PeripheralDebugObjects = {}
    end
    
    methods
        function obj = debugMessage()
            % Create debug message objects for each peripheral used for
            % printing debug messages and store in PeripheralDebugObjects
            % property as a cell array
            dioObj = arduinoio.internal.debug.DigitalIO;
            analogInObj = arduinoio.internal.debug.AnalogInput;
            PWMObj      = arduinoio.internal.debug.PWM;
            I2CObj      = arduinoio.internal.debug.I2C;
            SPIObj      = arduinoio.internal.debug.SPI;
            servoObj    = arduinoio.internal.debug.Servo;
            playToneObj = arduinoio.internal.debug.PlayTone;
            ultraSonicObj   = arduinoio.internal.debug.Ultrasonic;
            ShiftRegisterObj = arduinoio.internal.debug.ShiftRegister;
            RotaryEncoderObj = arduinoio.internal.debug.RotaryEncoder;
            SCIObj = arduinoio.internal.debug.SCI;
            obj.PeripheralDebugObjects = {dioObj, analogInObj, PWMObj, I2CObj, SPIObj, servoObj, playToneObj, ultraSonicObj, ShiftRegisterObj, RotaryEncoderObj, SCIObj};
        end
    end
end