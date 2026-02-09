classdef CodegenID <uint8
    
    % Use this enumerated class to add some IDs to use it across different
    % classes in MATLAB code generation.
    
    % Copyright 2019 The MathWorks, Inc.
    
    %#codegen
    
    enumeration
        BusIDNotFound (253)
        DefaultTimerPin (254)
        PinNotFound (255)
    end
end