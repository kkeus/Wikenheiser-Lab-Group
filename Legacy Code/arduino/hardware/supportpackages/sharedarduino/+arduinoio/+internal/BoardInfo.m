classdef (Hidden, Sealed) BoardInfo < matlab.mixin.Copyable
%BoardInfo
%
%% Properties

% Copyright 2017-2024 The MathWorks, Inc.
    properties (Access = {?matlabshared.hwsdk.internal.base,?arduinoio.internal.Utility,?simulinkio.arduinoioserver,...
                          ?matlab.hwmgr.providers.ArduinoDeviceProvider, ?arduinoexplorer.modules.internal.ArduinoManager, ?sharedarduino.accessor.UnitTest})
        Boards
    end
    %% Methods
    % Non public-constructor
    methods(Access=private)
        function obj = BoardInfo()
            obj.Boards = [];
            p = mfilename('fullpath');
            pp = fileparts(p);
            filename = fullfile(pp, 'boards.xml');
            xDoc = readstruct(filename);
            boards = fieldnames(xDoc);
            for boardIDX = 1: length(boards)
                boardNode = xDoc.(boards{boardIDX});
                boardSpecifications = fieldnames(boardNode);
                obj.Boards(end+1).Name = char(boards{boardIDX});
                switch obj.Boards(end).Name
                  case 'ESP32_WROOM_DevKitV1'
                    obj.Boards(end).Name = 'ESP32-WROOM-DevKitV1';
                  case 'ESP32_WROOM_DevKitC'
                    obj.Boards(end).Name = 'ESP32-WROOM-DevKitC';
                end
                for boardSpecIDX = 1:length(boardSpecifications)
                    childText = num2str(boardNode.(boardSpecifications{boardSpecIDX}));
                    switch char(boardSpecifications{boardSpecIDX})
                      case 'BoardName'
                        obj.Boards(end).BoardName = childText;
                      case 'Package'
                        obj.Boards(end).Package = childText;
                      case 'CPU'
                        obj.Boards(end).CPU = childText;
                      case 'MemorySize'
                        obj.Boards(end).MemorySize = str2num(childText);
                      case 'BaudRate'
                        obj.Boards(end).BaudRate = str2num(childText);
                      case 'MCU'
                        obj.Boards(end).MCU = childText;
                      case 'NumPins'
                        obj.Boards(end).NumPins = str2num(childText); %#ok<*ST2NM>
                      case 'PinsDigital'
                        obj.Boards(end).PinsDigital = str2num(childText);
                      case 'PinsAnalog'
                        obj.Boards(end).PinsAnalog = str2num(childText);
                      case 'PinsPWM'
                        obj.Boards(end).PinsPWM = str2num(childText);
                      case 'PinsServo'
                        obj.Boards(end).PinsServo = str2num(childText);
                      case 'PinsI2C'
                        obj.Boards(end).PinsI2C = str2num(childText);
                      case 'PinsInterrupt'
                        obj.Boards(end).PinsInterrupt = str2num(childText);
                      case 'ICSPSPI'
                        obj.Boards(end).ICSPSPI = str2num(childText);
                      case 'PinsSPI'
                        obj.Boards(end).PinsSPI = str2num(childText);
                      case 'PinsSerial'
                        obj.Boards(end).PinsSerial = str2num(childText);
                      case 'VID_PID'
                        obj.Boards(end).VIDPID = eval(['{' childText '}']);
                      case 'InitTimeout'
                        obj.Boards(end).InitTimeout = str2num(childText);
                    end
                end
            end
        end
    end
    % Destructor
    methods (Access = protected)
        function delete(obj)
        %delete Delete the hardware information
            obj.Boards = [];
        end
    end
    % Hidden static methods, which are used as friend methods
    methods(Hidden, Static)
        function value = getInstance(varargin)
            narginchk(0,1);
            if nargin == 0
                % ML IO
                value = arduinoio.internal.BoardInfo.getMLInstance();
            else
                % SL IO
                value = arduinoio.internal.BoardInfo.getSLInstance();
            end
        end
    end
    methods (Static, Access = private)
        function value = getMLInstance()
            persistent MLInstance;
            if isempty(MLInstance) || ~isvalid(MLInstance)
                slvalue = arduinoio.internal.BoardInfo.getSLInstance();
                % Clone the SLInstance handle without calling its
                % constructor (shallow copy)
                MLInstance = slvalue.copy();
                % Parse the arduino constants file and fetch only the boards that are supported in ML IO
                [~,indices] = ismember(arduinoio.internal.ArduinoConstants.BoardsNotSupportedinMLIO,{MLInstance.Boards.Name}');
                if ~isempty(indices)
                    % Remove all the structure entries that correspond to
                    % boards not supported in ML IO
                    MLInstance.Boards([indices]) = [];
                end
            end
            value = MLInstance;
        end
        function value = getSLInstance()
            persistent SLInstance;
            if isempty(SLInstance) || ~isvalid(SLInstance)
                SLInstance = arduinoio.internal.BoardInfo();
            end
            value = SLInstance;
        end
    end
end
% LocalWords:  fullpath MCU FCPU ICSPSPI SPI VID PARSECHILDNODES
% LocalWords:  MAKESTRUCTFROMNODE PARSEATTRIBUTES
