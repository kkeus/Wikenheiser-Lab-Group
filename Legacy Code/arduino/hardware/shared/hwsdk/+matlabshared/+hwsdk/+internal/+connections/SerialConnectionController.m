classdef SerialConnectionController < matlabshared.hwsdk.internal.connections.ConnectionController
% SERIALCONNECTIONCONTROLLER handles the controller side of functions which
% is related to serial connection

%   Copyright 2022-2024 The MathWorks, Inc.

    methods (Hidden)

        function updatePreferences(~, hardwareObj)
            hardwareObj.setPreference(hardwareObj.ConnectionType, ...
                                      hardwareObj.Port, ...
                                      [], ...
                                      hardwareObj.TraceOn, ...
                                      hardwareObj.BaudRate, ...
                                      hardwareObj.Args.CustomParams);
        end

        function [status, address, port] = validateAddressExistence(~, hardwareObj, address, ~)
            port = [];
            if ispc
                address = upper(address);
            end

            % Check for physical serial ports
            % TODO The RemoteUtilities does not support MATLAB
            % compiler deployment yet, need to remove the %#exclude
            % below and isdeployed once g3238819 is resolved
            %#exclude matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
            if ~isdeployed && matlabshared.remoteconnectivity.internal.RemoteUtilities.isUsingRemoteHW
                % Logic for MATLAB Online

                % Create remote utils object
                remoteUtilsObj = matlabshared.remoteconnectivity.internal.RemoteUtilities;

                % Convert to upper case if remote os is windows
                if strcmpi(remoteUtilsObj.getRemoteOSInfo,'win64')
                    address = upper(address);
                end

                % For MATLAB Online, it only supports access USB-serial
                % devices. Use the list from USB Enumerator. All official
                % Arduino boards (and most of the clone boards) are using
                % USB-to-serial converter. As a result, the serial port
                % list returned by USB Enumerator is good enough. The only
                % thing which is potentially missing out are some
                % unofficial clone boards which does not implement PID/VID
                % properly (for which USB Enumerator are unlikley to inlcude
                % them as USB-serial device, and we might need to have an
                % alternative for serialportlist (g3205271))
                USBDevEnumObj = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
                [ports, ~] = getSerialPorts(USBDevEnumObj);
                status = ismember(address, ports);
            else
                % Logic for MATLAB desktop
                status = any(ismember(serialportlist, address));
            end

            % Check if a pseudo port is demanding access
            if ~any(true(status))
                status = portEmulatorAvailableHook(hardwareObj, address);
            end
        end

        function [addressKey, args] = addConnectionTypeProperties(~, hardwareObj)
            args = hardwareObj.Args;
            p = addprop(hardwareObj, 'Port');
            hardwareObj.Port = args.Address;
            p.SetAccess = 'private';
            addressKey = hardwareObj.Port;
            % Adding 'BaudRate' property dynamically to the object
            % when the connection type is serial. This is because
            % BT and WiFi uses the default baudrate of 115200
            p = addprop(hardwareObj, 'BaudRate');
            p.GetAccess = 'public';
        end

        function args = parseAdditionalNVParameters(obj, hardwareObj, iParam, args, ~, ~, ~, varargin)
        % Only serial connection type allows
        % specifying NV pairs for:
        %    Libraries
        %    TraceOn
        %    ForceBuildOn
        %    BaudRate

            p = inputParser;
            p.PartialMatching = true;
            p.KeepUnmatched = false;
            if isa(hardwareObj, 'matlabshared.addon.controller')
                addParameter(p, 'Libraries', {'null'});
            end
            addParameter(p, 'TraceOn', false, @islogical);
            addParameter(p, 'ForceBuildOn', false, @islogical);
            addParameter(p, 'BaudRate', [], @isnumeric);
            addCustomNameValueParametersHook(hardwareObj, p);
            % Validate whether the CustomParams is not any one of validParameters e.g TraceOn, Libraries, etc
            if ~isempty(args.CustomParams)
                validateCustomParamsHook(hardwareObj, args.CustomParams.Board, p.Parameters);
            end
            try
                parse(p, varargin{iParam:end});
            catch e
                switch e.identifier
                  case 'MATLAB:InputParser:ParamMissingValue'
                    message = e.message;
                    index = strfind(message, '''');
                    str = message(index(1)+1:index(2)-1);
                    try
                        validatestring(str, p.Parameters);
                    catch
                        unmatchedCustomParamsErrorHook(hardwareObj,str);
                    end
                    param = e.message(index(1):index(2));
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:missingParamValue', param);
                  case 'MATLAB:InputParser:ParamMustBeChar'
                    message = e.message;
                    message(1) = lower(message(1));
                    unmatchedCustomParamsErrorHook(hardwareObj,['- ',message(1:end-1)]);
                  case 'MATLAB:InputParser:UnmatchedParameter'
                    message = e.message;
                    index = strfind(message, '''');
                    param = e.message(index(1):index(2));
                    unmatchedCustomParamsErrorHook(hardwareObj,param);
                  otherwise
                    inputParserErrorHook(hardwareObj,e);
                end
            end
            args.TraceOn = p.Results.TraceOn;
            args.ForceBuildOn  = p.Results.ForceBuildOn;
            args.BaudRate = p.Results.BaudRate;
            if ~isempty(args.BaudRate)
                obj.BaudRateSpecified = true;
            end
            % 3. Validate Libraries data type
            [p, args] = validateLibraries(obj, hardwareObj, p, args);
            parseCustomNameValueParametersHook(hardwareObj, p);
        end

        function connectionObj = createConnectionObject(~, hardwareObj)
            connectionObj = hardwareObj.serialHook(hardwareObj.Port);
        end

        function showFailedUploadError(~, boardName, port)
        % This method throws exception on upload failure.
        % Here port is COM - string
            matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:failedUpload', char(boardName), char(port));
        end
    end

    methods (Access = protected)
        function addressKey = getAddressKeyHook(~, hardwareObj)
            addressKey = hardwareObj.Port;
        end
    end

    methods (Access = private)
        function [p, args] = validateLibraries(~, hardwareObj, p, args)
            if isa(hardwareObj, 'matlabshared.addon.controller')
                if ~ischar(p.Results.Libraries) && ~iscell(p.Results.Libraries) && ~iscellstr(p.Results.Libraries) && ~isstring(p.Results.Libraries)
                    matlabshared.hwsdk.internal.localizedError('MATLAB:hwsdk:general:invalidLibrariesType');
                end
                % Convert char vector to cell array of char vectors.
                % For example, 'servo, i2c' -> {'servo', 'i2c'}
                libs = p.Results.Libraries;
                % Assigns Libraries and LibrariesSpecified to defaults
                args.Libraries     = libs;
                args.LibrariesSpecified = true;
                if isstring(libs)
                    if length(libs) == 1 % single string
                        libs = char(libs);
                    else % array of strings
                        libs = cellstr(libs);
                    end
                end
                % Convert cell array of strings to cell array of char vectors.
                % For example,{"servo", "i2c"} -> {'servo', 'i2c'}
                if iscell(libs)
                    libs = cellstr(libs);
                    % Libraries paramter = 'null' indicates no libraries is
                    % provided by the user
                    if (isequal(numel(libs),1) && strcmpi(args.Libraries{1},'null'))
                        args.LibrariesSpecified = false;
                        libs = {};
                    end
                end
                if ischar(libs) && ~isempty(libs)
                    libs = strtrim(strsplit(libs, ','));
                end
                args.Libraries     = libs;
                if isempty(args.Libraries) % User specifies '' or {} or ""
                    args.Libraries = {};
                elseif isempty(args.Libraries{1}) % User does not specify 'Libraries' nv pair -> default value of {''} or {""}
                    args.Libraries = {};
                end
            end
        end
    end

end
