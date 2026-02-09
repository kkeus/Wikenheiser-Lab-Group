classdef (Abstract, Hidden) ChannelProvider < handle
%ChannelProvider Baseclass of chips which actually provide the CAN
%Channel
%   ChannelProvider defines the properties and methods which every
%   provider of CAN Channel must follow. Channel fills its dependent
%   properties from here.

%   Copyright 2019-2022 The MathWorks, Inc.

    properties
        %OscillatorFrequency - Every chip / provider of CAN Channel need an
        %oscillator to drive the CAN Bus. Holds numeric values defined by
        %the hardware specific provider class
        OscillatorFrequency

        %ProtocolMode - CAN / CAN-FD (future). Defined by the provider
        %class today. May become editable in future similar to VNT
        ProtocolMode

        %BusSpeed - CAN Bus operating frequency
        BusSpeed
    end

    methods(Abstract)
        connect(obj, varargin);
        disconnect(obj, varargin);
        data = read(obj, varargin);
        write(obj, varargin);
    end
end
