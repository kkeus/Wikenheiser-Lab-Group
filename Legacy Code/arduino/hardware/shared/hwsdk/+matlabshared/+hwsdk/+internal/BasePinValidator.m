classdef (Hidden) BasePinValidator < handle
% Handles validations common to all types

%   Copyright 2023 The MathWorks, Inc.

    methods(Abstract)
        % RENDERPINSTOSTRINGIMPL - must render pins to string. The base
        % cannot identify the input type. The caller can call a Numeric or
        % String Validator. Based on the object held by caller, the
        % corresponding validator will call the right render function
        % INPUTS:
        %   obj - matlabshared.hwsdk.internal.BaseValidator
        %   pinCell - pins collected as cell array. Only cell array works
        %   as we don't know their class(pins)
        pinString = renderPinsToStringImpl();
    end

    methods (Hidden)
        function pinsWithLabel = getDevicePinsWithLabel(obj, interface, varargin)
        % Parse and the pins to their labels.
            p = inputParser;
            p.PartialMatching = true;
            assert(isa(interface, "matlabshared.hwsdk.internal.InterfaceEnum"), 'interface should be a matlabshared.hwsdk.internal.InterfaceEnum');
            switch interface
              case matlabshared.hwsdk.internal.InterfaceEnum.I2C
                addParameter(p, 'SCL', [], @(x) any(~isempty(x)));
                addParameter(p, 'SDA', [], @(x) any(~isempty(x)));
              case matlabshared.hwsdk.internal.InterfaceEnum.SPI
                addParameter(p, 'SCL', [], @(x) any(~isempty(x)));
                addParameter(p, 'SDI', [], @(x) any(~isempty(x)));
                addParameter(p, 'SDO', [], @(x) any(~isempty(x)));
              case matlabshared.hwsdk.internal.InterfaceEnum.Serial
                addParameter(p, 'TxPin', [], @(x) any(~isempty(x)));
                addParameter(p, 'RxPin', [], @(x) any(~isempty(x)));
                % Other interfaces are not supported.
            end
            try
                parse(p, varargin{:});
            catch e
                throwAsCaller(e);
            end
            % Convert pins to comma separated string
            pinCell = {};
            switch interface
              case matlabshared.hwsdk.internal.InterfaceEnum.I2C
                pinCell = {p.Results.SCL, p.Results.SDA};
                label = ["SCL", "SDA"];
              case matlabshared.hwsdk.internal.InterfaceEnum.SPI
                pinCell = {p.Results.SCL, p.Results.SDI, p.Results.SDO};
                label = ["SCL", "SDI", "SDO"];
              case matlabshared.hwsdk.internal.InterfaceEnum.Serial
                pinCell = {p.Results.TxPin, p.Results.RxPin};
                label = ["TxPin", "RxPin"];
                % Other interfaces are not supported.
            end
            assert(~isempty(pinCell), 'pinCell should have been filled up by now')
            pinString = renderPinsToStringImpl(obj, pinCell);
            pinsWithLabel = addLabels(obj, pinString, label);
        end
    end

    methods (Access = private)
        function pinStringWithLabels = addLabels(~, pinString, labels)
            pinStrings = split(pinString, ", ");
            if size(pinStrings, 1) ~= 1
                % Make it row based if it is not already.
                pinStrings = pinStrings';
            end
            assert(length(pinStrings) == length(labels), ...
                   'length of pin strings must be same as length of labels');
            pinStringWithLabels = "";
            for pinIdx = 1:length(pinStrings)
                pinStringWithLabels = strcat(pinStringWithLabels, pinStrings{pinIdx}, " (", labels(pinIdx), "), ");
            end
            % Remove the last comma.
            pinStringWithLabels = extractBefore(pinStringWithLabels, strlength(pinStringWithLabels)-1);
        end
    end
end
