
classdef (Abstract) controller_base <  matlabshared.hwsdk.internal.base

%   Copyright 2017-2022 The MathWorks, Inc.

% User Interface
%
    properties(Abstract, GetAccess = public, SetAccess = private)
        AvailablePins string
    end

    methods(Abstract, Access = public)
        pinConfig = configurePin(obj, pin, config);
        deviceObj = device(parentObj, varargin);
    end

    % Developer Interface
    %
    methods(Abstract, Hidden)
        dev = getDevice(obj, interface, varargin);
        pinStatus = configurePinInternal(obj, pin, config, varargin);
    end

    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        precisions = getAvailablePrecisions(obj);
    end

    % Implementation Interface
    %
    methods(Abstract, Access = protected)
        name = getHarwdareNameImpl(obj);
        baseCode = getSPPKGBaseCodeImpl(obj);
        pinConfig = configurePinImpl(obj, pin, config, varargin);
        pinNumber = getPinNumberImpl(obj, pin);
        updateServerImpl(obj);
        pins = getAvailablePinsImpl(obj);

        % getPinTerminalTypeImpl: Hardware SPPKGs return the class of pins
        % terminals that they use with IOServer APIs. For example arduino's
        % pins terminals are double.
        pinType = getPinTerminalTypeImpl(obj);
    end
end
