
%   Copyright 2017-2021 The MathWorks, Inc.

classdef (Abstract) peripheral_base < matlabshared.hwsdk.internal.base
        
    % User Interface
    %
%     properties(Abstract, Dependent)
%         SPIChipSelectPin
%         Bus
%         SCLPin
%         SDIPin
%         SDOPin
%         Mode
%         BitOrder
%         BitRate
%     end

    % Developer Interface
    %
    methods(Abstract, Access = {?matlabshared.hwsdk.internal.base})
        ActiveLevel = getActiveLevel(obj);
        supportedSPIModes = getSupportedSPIModes(obj);
        sclFrequencyLimit = getSCLFrequencyLimit(obj);
        spiBitOrder = getSPIBitOrder(obj);
    end

    % Implementation Interface
    %
    methods(Abstract, Access = protected)
        chipSelectActiveState = getActiveLevelImpl(obj);
        supportedSPIModes = getSupportedSPIModesImpl(obj);
        sclFrequencyLimit = getSCLFrequencyLimitImpl(obj);
        spiBitOrder = getSPIBitOrderImpl(obj);
    end
end

% LocalWords:  SPI SCL SDI SDO