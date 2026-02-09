
%   Copyright 2017-2021 The MathWorks, Inc.

classdef (Abstract) peripheral < matlabshared.spi.peripheral_base
    % User Interface
    %
    
    % Developer Interface
    %
    methods(Sealed, Access = {?matlabshared.hwsdk.internal.base})
        function ActiveLevel = getActiveLevel(obj)
            ActiveLevel = obj.getActiveLevelImpl();
            if ~isempty(ActiveLevel)
                assert(isstring(ActiveLevel));
                assert(ismember(ActiveLevel, ["low" "high"]));
            end
        end
        
        function supportedSPIModes = getSupportedSPIModes(obj)
            supportedSPIModes = obj.getSupportedSPIModesImpl();
            if ~isempty(supportedSPIModes)
                assert(size(supportedSPIModes, 1)==1); % row based
                assert(all(ismember(supportedSPIModes, [0 1 2 3])));
            end
        end
        
        function sclFrequencyLimit = getSCLFrequencyLimit(obj)
            sclFrequencyLimit = obj.getSCLFrequencyLimitImpl();
            if ~isempty(sclFrequencyLimit)
                assert(isnumeric(sclFrequencyLimit));
                assert(all(sclFrequencyLimit>=0));
                assert(all(size(sclFrequencyLimit)==[1 2])); % 1x2
                assert(sclFrequencyLimit(2) >= sclFrequencyLimit(1));
            end
        end
        
        function spiBitOrder = getSPIBitOrder(obj)
            spiBitOrder = obj.getSPIBitOrderImpl();
            if ~isempty(spiBitOrder)
                assert(isstring(spiBitOrder));
                assert(ismember(spiBitOrder, ["msbfirst" "lsbfirst"]));
            end
        end
    end

    methods(Hidden, Access = public)
        function obj = peripheral(varargin)
            assert(isa(obj, 'matlabshared.sensors.sensor'));
        end
    end
end

% LocalWords:  matlabshared
