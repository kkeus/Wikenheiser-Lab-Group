classdef LibraryBase < matlabshared.hwsdk.internal.base
% LIBRARYBASE - True library classes and addon classes that define a
% library shall inherit from this base class to get Parent property and
% other properties and methods.

% Copyright 2016-2022 The MathWorks, Inc.

    properties(Hidden, SetAccess = protected)
        Parent
    end

    properties (Hidden)
        % Undo - Used by every device based peripheral to store current pin
        % configuration details in order to do a clean rewind.
        Undo = struct('Pin', {}, 'ResourceOwner', {}, 'PrevPinMode', {});
    end

    properties(Access = private, Constant)
        % This request ID indicates that the host is making a custom request
        % for an add-on library.
        AddOnRequest = hex2dec('2F')
    end

    properties(SetAccess = private, GetAccess = protected)
        % Any SDK change that leads to backward incompatibility would
        % update MajorVersion number. Otherwise, only MinorVersion number
        % will be changed
        MajorVersion = 1
        MinorVersion = 0
    end

    % Every library class SHALL override all of the following properties
    % with default value
    properties(Abstract = true, Access = protected, Constant = true)
        LibraryName
        DependentLibraries
        % Header file of the 3P source/library
        LibraryHeaderFiles
        % Value SHALL be file name with absolute full path
        CppHeaderFile
        CppClassName
    end

    methods(Access = protected)
        function [dataOut, payloadSize] = sendCommand(obj, libName, commandID, dataIn, timeout)
            try
                % Validate inputs
                % inputs parameter must be a row or column vector or empty
                % matrix
                try
                    validateattributes(dataIn, {'numeric'}, {'2d', 'integer'});
                catch
                    obj.localizedError('MATLAB:hwsdk:general:invalidInputs');
                end

                [m, ~] = size(dataIn);
                if ~isempty(dataIn) && m ~= 1 % convert input into a row vector
                    dataIn = dataIn';
                end
                % Validate commandID
                try
                    validateattributes(commandID, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative', '>=',0, '<=', 255});
                catch
                    obj.localizedError('MATLAB:hwsdk:general:invalidCommandID');
                end
                maxBytes = getMaxBufferSizeImpl(obj.Parent);
                if numel(dataIn) > maxBytes
                    obj.localizedError('MATLAB:hwsdk:general:maxDataLimit', num2str(maxBytes), obj.Parent.Board);
                end
                cmd = [commandID, typecast(uint32(length(dataIn)),'uint8'), dataIn]; % Second to fifth bytes are the length of input data
                                                                                     % accept string type libName but convert it to character vector
                if isstring(libName)
                    libName = char(libName);
                end
                if ischar(libName)
                    if nargin < 5
                        dataOut = sendAddonMessage(obj, libName, cmd);
                    else
                        % Validate timeout
                        try
                            validateattributes(timeout, {'numeric'}, {'scalar', 'real', 'finite', 'nonnan', 'nonnegative'});
                        catch
                            obj.localizedError('MATLAB:hwsdk:general:invalidTimeout');
                        end
                        dataOut = sendAddonMessage(obj, libName, cmd, timeout);
                    end
                    payloadSize = dataOut(1);
                    dataOut = dataOut(2:end);
                else
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidLibraryNameFormat');
                end
            catch e
                throwAsCaller(e);
            end
        end

        function value = sendAddonMessage(obj, libName, cmd, timeout)
            libID = getLibraryID(obj.Parent, libName);
            requestId = obj.AddOnRequest;
            peripheralPayload = [uint8(libID), uint8(cmd)];
            % IOProtocol needs a value for
            % responsePeripheralPayloadSize. But Add-on does not provide
            % that. So a dummy value is given.
            responsePeripheralPayloadSize = uint8(50);
            % Set the Add on flag in IO Protocol
            setAddOnFlag(obj);
            c = onCleanup(@() resetAddOnFlag(obj));
            if nargin < 4
                value = rawRead(obj.Parent.Protocol, requestId, peripheralPayload, responsePeripheralPayloadSize);
            else
                % Save the timeout value for IO Protocol
                prevTimeout = getIOProtocolTimeout(obj.Parent.Protocol);
                % Set the timeout to the user specified value
                setIOProtocolTimeout(obj.Parent.Protocol, timeout);
                value = rawRead(obj.Parent.Protocol, requestId, peripheralPayload, responsePeripheralPayloadSize);
                % Restore the old timeout value
                setIOProtocolTimeout(obj.Parent.Protocol, prevTimeout);
            end
            % reset Add on flag in IOProtocol
            resetAddOnFlag(obj)
            % The first byte tells the size
            value = [length(value); value];
        end

        function setAddOnFlag(obj)
            obj.Parent.Protocol.IsAddOnEnable = true;
        end

        function resetAddOnFlag(obj)
            obj.Parent.Protocol.IsAddOnEnable = false;
        end
    end
end

% LocalWords:  addon SDK arduino ADK
