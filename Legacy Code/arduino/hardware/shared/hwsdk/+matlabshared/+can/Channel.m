classdef (Hidden, Sealed) Channel < matlabshared.testmeas.CustomDisplay & ...
                                    matlabshared.hwsdk.internal.base
    %Channel    Provides access to CAN Network through a shield / chip
    %connected to a low cost Hardware
    %
    %   Channel methods:
    %       read  - Reads from CAN Channel
    %       write - Writes into CAN channel
    %
    %   See also read, write
    
    %   Copyright 2019-2023 The MathWorks, Inc.
    
    properties (Hidden)
        Provider
    end
    
    properties (GetAccess = public, SetAccess = private)
        %Device - Shield or Chip Name
        Device char
    end
    
    properties (Dependent, GetAccess = public, SetAccess = private)
        %ProtocolMode - CAN / CAN-FD
        ProtocolMode char
        %BusSpeed - Speed of CAN Bus. Fetched through NV Pairs during
        %canChannel object creation.
        BusSpeed double
    end
    
    properties (Access = public)
        %Database - R/W property. Used to fill up the Signal and Name
        %fields of CAN Messages in read method's output timetable.
        Database = []
    end
    
    properties (Dependent, SetAccess = private)
        %InterruptPin - Dependent on chip's InterruptPin Property
        InterruptPin char
        %OscillatorFrequency - Dependent on chip's OscillatorFrequency Property
        OscillatorFrequency
    end
    
    methods        
        function intPin = get.InterruptPin(obj)
            intPin = obj.Provider.InterruptPin;
        end
        
        function oscFreq = get.OscillatorFrequency(obj)
            oscFreq = obj.Provider.OscillatorFrequency;
        end
        
        function protocol = get.ProtocolMode(obj)
            protocol = obj.Provider.ProtocolMode;
        end
        
        function busSpeed = get.BusSpeed(obj)
            busSpeed = obj.Provider.BusSpeed;
        end
        
        function set.Database(obj, dbObj)
            if isempty(dbObj)
                obj.Database = [];
            else
                try
                    % Validate using Shared CAN function
                    can.validateCANdbFile(dbObj.Path);
                    % Verify if VNT is checked out
                    canMessage(dbObj, dbObj.MessageInfo(1).Name);
                catch e
                    switch(e.identifier)
                        case 'MATLAB:structRefFromNonStruct'
                            % Invalid type - Not even a struct
                            errID = 'MATLAB:hwsdk:can:invalidDatabaseType';
                            m = message(errID);
                            throwAsCaller(MException(m));
                        case {'MATLAB:undefinedVarOrClass', 'MATLAB:license:NoFeature'}
                            % VNT Not installed / licensed
                            errID = 'MATLAB:hwsdk:can:databaseWithoutVNT';
                            m = message(errID);
                            throwAsCaller(MException(m));
                        case {'MATLAB:invalidType', 'MATLAB:noSuchMethodOrField'}
                            % VNT available but invalid database object
                            errID = 'vnt:Channel:InvalidDatabase';
                            m = message(errID);
                            throwAsCaller(MException(m));
                        otherwise
                            % some other exception
                            throwAsCaller(e);
                    end
                end
                obj.Database = dbObj;
            end
        end
    end
    
    methods (Hidden, Access = public)
        function obj = Channel(parentObj, deviceName, varargin)
            p = inputParser;
            addRequired(p, "Device", @(x) (isstring(x) || ischar(x)));
            try
                parse(p, deviceName);
            catch e
                switch e.identifier
                    case 'MATLAB:minrhs'
                        obj.localizedError('MATLAB:hwsdk:can:missingDeviceName', parentObj.Board, matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parentObj.SupportedCANDevices, ', '));
                    case 'MATLAB:InputParser:ArgumentFailedValidation'
                        obj.localizedError('MATLAB:hwsdk:can:invalidDeviceName', parentObj.Board, matlabshared.hwsdk.internal.renderCellArrayOfCharVectorsToCharVector(parentObj.SupportedCANDevices, ', '));
                    otherwise
                        throwAsCaller(e);
                end
            end
            
            obj.Device = validateCANDeviceName(parentObj, p.Results.Device);
            
            obj.Provider = getCANChannelProvider(parentObj, obj.Device, varargin{:});
            
            switch class(obj.Provider.Device)
                case 'matlabshared.spi.device'
                    p = addprop(obj, 'ChipSelectPin');
                    p.SetAccess = 'private';
                    p.Dependent = true;
                    p.GetMethod = @getChipSelectPin;
                otherwise
                    % No Dynamic Properties added
            end
            
            % For display - Use matlabshared.testmeas.CustomDisplay
            obj.PropertyGroupList = {["Device", "ProtocolMode", "BusSpeed", "Database"], ...
                                    ["OscillatorFrequency", "ChipSelectPin", "InterruptPin"]};
            obj.PropertyGroupNames = ["", ""];
            obj.ShowAllMethodsInFooter = false;
        end
    end
    
    methods(Access = public)
        function write(obj, varargin)
            %write    Writes into CAN channel
            %   write(ch, 500, false, [1, 5, 10, 4]) writes the CAN frame
            %   with standard identifier 500 and data array as
            %   specified into the CAN channel ch.
            %
            %   write(ch, msg) writes the CAN frame msg created using the
            %   VNT API canMessage into the CAN channel ch.
            %
            %   See also canChannel, read

            % This is needed for data integration for max argument
            % parameter
            if isa(obj.Provider.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                if nargin == 4
                    dmaxArguments= '3';
                elseif nargin == 2
                    dmaxArguments = '1';
                else
                    dmaxArguments = 'NA';
                end

                % Register on clean up for integrating all data
                c = onCleanup(@() integrateData(obj.Provider.Parent,'CANChannel',dmaxArguments));
            end
            try
                write(obj.Provider, varargin{:});
            catch e
                if isa(obj.Provider.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj.Provider.Parent,e.identifier);
                end
                throwAsCaller(e);
            end
        end
        
        function tt = read(obj, varargin)
            %read    Reads from CAN channel
            %   tt = read(ch) reads 1 CAN frame from the CAN channel ch and
            %   returns it in the form of a timetable.
            %
            %   tt = read(ch, maxMessages) reads x <= maxMessages if only x
            %   CAN frames are available from the CAN channel ch. Returns
            %   all the CAN frames in the form of timetable.
            %
            %   See also canChannel, write

            % This is needed for data integration for maxMessages parameter
            if isa(obj.Provider.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                if nargin>1
                    dmaxMessages = 'true';
                else
                    dmaxMessages = 'false';
                end

                % Register on clean up for integrating all data
                c = onCleanup(@() integrateData(obj.Provider.Parent,'CANChannel',dmaxMessages));
            end
            try
                tt = read(obj.Provider, varargin{:});
            catch e
                if isa(obj.Provider.Parent,'matlabshared.ddux.HWSDKDataUtilityHelper')
                    integrateErrorKey(obj.Provider.Parent,e.identifier);
                end
                throwAsCaller(e);
            end
            if ~isempty(obj.Database) && ~isempty(tt)
                tt = canMessageTimetable(tt, obj.Database);
            end
        end
    end
    
    methods(Hidden)
        % Added to ease VNT user's workflow.
        function transmit(obj, varargin)
            try
                narginchk(2,2);
                write(obj.Provider, varargin{:});
            catch
                obj.localizedError('vnt:Channel:InvalidMessage');
            end
        end
        
        function tt = receive(obj, varargin)
            try
                narginchk(2,4);
                tt = read(obj.Provider, varargin{1});
            catch e
                switch e.identifier
                    case 'MATLAB:hwsdk:can:invalidmaxMessagesType'
                        obj.localizedError('MATLAB:hwsdk:can:invalidmaxMessagesType', 'messagesRequested');
                    otherwise
                        throwAsCaller(e);
                end
            end
        end
    end
end

% Non member helper functions
function csPin = getChipSelectPin(obj)
    csPin = obj.Provider.ChipSelectPin;
end
