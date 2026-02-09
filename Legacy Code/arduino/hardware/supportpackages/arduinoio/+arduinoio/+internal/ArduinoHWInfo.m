function [info, status] = ArduinoHWInfo()
%   ARDUINOHWINFO retrieves information of Arduino Hardware connected
%   to the system by checking from a list VID_PIDs present in boards.xml file
%   Syntax:
%       arduinoio.internal.ArduinoHWInfo
%
% Copyright 2020-2021 The MathWorks, Inc.

%   info stores the details of Arduino Hardware
info = [];
status = 0;
USBDevEnumObj = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
[ports,devices] = getSerialPorts(USBDevEnumObj);

try
    % Extract all VID_PID from boards.xml and lists in boardsXML
    boardsXML = fullfile(arduinoio.SharedArduinoRoot,'+arduinoio','+internal','boards.xml');
    xml = readstruct(boardsXML);

    % List of boards to remove which are not supported in MATLAB
    % Support Package for Arduino Hardware
    fieldsToRemove = arduinoio.internal.ArduinoConstants.BoardsNotSupportedinMLIO;

    % Remove the fields from the struct
    xml = rmfield(xml, fieldsToRemove);

    % Extract all the supported Arduino board names
    boardNames = fieldnames(xml);

    for idx = 1:numel(devices)
        % Create the VIDPID string as there in the board xml format
        VIDPIDSearchStr = lower(['0x' devices(idx).VendorID '_0x' devices(idx).ProductID]);
        % Assign product name based on the VID PID.
        for i = 1:numel(boardNames)
            if contains (lower(char(strrep(xml.(boardNames{i}).VID_PID,"'",''))),VIDPIDSearchStr)
                info(end+1).VendorID = devices(idx).VendorID;
                info(end).ProductID = devices(idx).ProductID;
                info(end).Manufacturer = devices(idx).Manufacturer;
                info(end).ProductName  = ['Arduino ' boardNames{i}];
                info(end).SerialNumber = devices(idx).SerialNumber;
                info(end).PortNumber = ports{idx};
            end
        end
    end
catch e
    status = 1;
    info = sprintf("Unable to detect boards.xml.\nError message: %s\n",e.message);
end
end
