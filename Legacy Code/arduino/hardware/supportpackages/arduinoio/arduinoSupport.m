function arduinoSupport(varargin)
%    arduinoSupport is a Troubleshooting utility of MATLAB SUPPORT PACKAGE FOR ARDUINO HARDWARE.
%
%    arduinoSupport, returns all the generic information related to System,Installed packages
%    and Hardware and saves output to text file 'arduinoSupport.txt' in
%    the current writable directory.
%
%    Syntax
%      arduinoSupport                         Extract generic information.
%      arduinoSupport(PORT)                   Extract generic information and creates a serial connection to an Arduino hardware on the specified port with TraceOn and ForceBuildOn value true
%      arduinoSupport(PORT,BOARD,NAME,VALUE)  Extract generic information and creates a serial connection to the Arduino hardware on the specified port and board with additional Name-Value options with TraceOn and ForceBuildOn value true
%
%    Example:
%
%      % Extract generic information
%      arduinoSupport
%
%      % Extract generic information and connect to an Arduino Uno board on COM port 3 with TraceOn and ForceBuildOn value true on Windows:
%      arduinoSupport('com3','uno');
%
%      % Extract generic information and connect to an Arduino Uno board on a serial port with TraceOn and ForceBuildOn value true on Mac:
%      arduinoSupport('/dev/tty.usbmodem1421');
%
%      % Extract generic information and connect to an Arduino board and include only I2C library instead of default libraries set (I2C, SPI and Servo)
%      arduinoSupport('com3','uno','libraries','I2C');
%
%      % Extract generic information and connect to an Arduino Uno board on COM port 3 and BaudRate 115200 bits per second
%      arduinoSupport('com3','uno','BaudRate',115200);
%

%   Copyright 2020-2023 The MathWorks, Inc.

    fileName = 'arduinoSupport.txt'; %default text file name


    % Opens 'fileName' for writing
    fid = fopen(fileName, 'wt');
    if (fid==-1)
        error('Permission denied: Unable to open file');
    end
    cleanUp = onCleanup(@()fclose(fid));

    % Display message to command window.
    disp('Gathering diagnostic information ...');

    fprintf(fid, ['Current Date and Time : ', '%s', newline], datestr(now));

    section('Support Utility for MATLAB Support Package for Arduino Hardware')
    section('Table of Contents')
    dispFile('1.    Installed Support Packages')
    dispFile('2.    MCR Version')
    dispFile('3.    Version of MATLAB and Installed Toolboxes')
    dispFile('4.    Hardware Information')
    dispFile('5.    Arduinoio.CLIRoot Path')
    dispFile('6.    Current Working Directory')
    dispFile('7.    MATLAB Root')
    dispFile('8.    List of all Arduino Libraries')
    dispFile('9.    Default Libraries Location')
    dispFile('10.   Board Information and Object Creation Status')
    dispFile('11.   MATLAB Path')
    dispFile('12.   MATLAB and Support Package Installer Log')

    % List All Installed Support Packages and their version
    section( 'Installed Support Packages' );
    fprintf(fid, evalc('matlabshared.supportpkg.getInstalled()'));

    % Extract the MCR Version
    section('MCR version')
    try
        [majorVersion, minorVersion, ~] = mcrversion;
        fprintf(fid, ['Major Version : ', '%s',newline], evalc('disp(majorVersion)'));
        fprintf(fid, ['Minor Version : ', '%s',newline], evalc('disp(minorVersion)'));
    catch e
        apiCalled = "[major, minor, ~] = mcrversion";
        fprintf(fid, ['Error occurred while using command : >> ', '%s',newline], evalc('disp(apiCalled)'));
        fprintf(fid, ['Error message : ', '%s',newline], evalc('disp(e.message)'));
    end

    % List of all installed toolboxes and their version
    section('Version of MATLAB and Installed Toolboxes')
    fprintf(fid, evalc('ver'));

    % Path of arduinoio.CLIRoot
    section('Arduinoio.CLIRoot Path')
    try
        fprintf(fid,['%s',newline], arduinoio.CLIRoot);
        arduinoioPathFlag = 1;
    catch e
        arduinoioPathFlag = 0;
        apiCalled = "arduinoio.CLIRoot";
        fprintf(fid, ['Error occurred while using command : >> ', '%s',newline], evalc('disp(apiCalled)'));
        fprintf(fid, ['Error message : ', '%s',newline], evalc('disp(e.message)'));
    end

    % Path of Current Working Directory
    section('Current Working Directory')
    fprintf(fid, ['%s',newline], pwd);

    % Path of MATLAB Root
    section('MATLAB Root')
    fprintf(fid, ['%s',newline], matlabroot);


    % Hardware Information (VID/PID)
    section('Hardware Information')
    separator()
    [arduinoList, status] = arduinoio.internal.ArduinoHWInfo();
    if(status)
        fprintf(fid, "%s\n", arduinoList);
    else
        writeHardwareInfo(fid, arduinoList);
    end
    separator()

    section('List of all Arduino Libraries')
    try
        % List all arduino libraries
        fprintf(fid,['%s',newline], evalc('disp(listArduinoLibraries())'));
    catch e
        apiCalled = "listArduinoLibraries()";
        fprintf(fid, ['Error occurred while using command : >> ', '%s',newline], evalc('disp(apiCalled)'));
        fprintf(fid, ['Error message : ', '%s',newline], evalc('disp(e.message)'));
    end

    section('Default Library Location')
    if arduinoioPathFlag
        libLocation = fullfile(arduinoio.CLIRoot, 'user', 'libraries');
        try
            % Check libLocation location
            if libLocation
                fprintf(fid, ['Library Location :', newline,'%s',newline], evalc('dir(libLocation)'));
            end
        catch e
            apiCalled = "dir(libLocation)";
            fprintf(fid, ['Error occurred while using command : >> ', '%s',newline], evalc('disp(apiCalled)'));
            fprintf(fid, ['Error message : ', '%s',newline], evalc('disp(e.message)'));
        end
    else
        fprintf(fid,['Library location does not exist',newline]);
    end

    section('Board Information and Object Creation Status')
    separator()
    if( nargin > 0 )
        % To check first input argument is a valid argument or not
        if ~ isa(varargin{1},'char')
            error(message('MATLAB:hwsdk:general:invalidAddressTypeFirstInput'));
        end
        if (nargin >=2 && ~isa(varargin{2},'char'))
            error(message('MATLAB:arduinoio:general:invalidBoardType'));
        end

        dispFile('arduinoSupport API called with arguments')
        fprintf(fid,evalc('disp(varargin)'));

        % To restrict arguments like TraceOn and ForceBuildOn
        restrictedInput = {'TraceOn','Trace','ForceBuildOn','ForceBuild'};
        for k = 1:length(varargin)
            for j = 1:length(restrictedInput)
                if strcmpi(varargin{k},restrictedInput(j))
                    varargin{k+1}=[];
                    varargin{k}=[];
                    break;
                end
            end
        end
        varargin = varargin(~cellfun('isempty',varargin));
        argumentCell ={};
        for i = 1:length(varargin)
            if varargin{i} == 1
                argumentCell = [argumentCell, {'true'}];
            elseif varargin{i} == 0
                argumentCell = [argumentCell, {'false'}];
            else
                argumentCell = [argumentCell, varargin{i}];
            end
        end
        argumentString = strjoin(argumentCell,', ');

        dispFile('arduino object creation passed with arguments');
        fprintf(fid, ['%s', newline], argumentString);
        fprintf('\n')

        clear arduinoObject;
        % error handling
        try
            % Object creation using TraceOn and ForceBuildOn feature
            arduinoObject = arduino(varargin{:},'TraceOn',true,'ForceBuildOn',true);
            fprintf(fid, evalc('disp(arduinoObject)'));
        catch e
            apiCalled = "arduinoObject = arduino(" + argumentString + ",'TraceOn',true,'ForceBuildOn',true)";
            fprintf(fid, [newline, 'Error occurred while using command : >> ', '%s',newline], evalc('disp(apiCalled)'));
            fprintf(fid, ['Error message : ', '%s',newline], evalc('disp(e.message)'));
        end
    else
        dispFile('Board information not provided');
    end

    section('Matlab Path')
    fprintf(fid,['%s',newline], evalc('path'));
    separator()

    % Installer Log File
    section('MATLAB and Support Package Installer Log')
    separator()
    if ismac || isunix
        username = getenv('USER');
    elseif ispc
        username = getenv('username');
    else
        dispFile('Platform not supported')
    end
    logfile = "mathworks_" + username + ".log";
    logFileName = fullfile(tempdir,logfile);
    try
        logid = fopen(logFileName, 'r');
        if logid == -1
            error('Cannot open file: %s', logFileName);
        end
        data = fscanf(logid, '%c', inf);
        fprintf(fid,'%s', data);
        fclose(logid);
    catch e
        fprintf(fid, ['Error occurred while using command : >> ', '%s',newline], evalc('disp(logFileName)'));
        fprintf(fid, ['Error message : ', '%s',newline], evalc('disp(e.message)'));
    end
    separator();


    section('End Test');
    dispFile('This information has been saved in the text file: arduinoSupport.txt');
    dispFile('If any errors occurred, please visit the MathWorks Technical Support Web Site');
    dispFile('at https://www.mathworks.com/support/contact_us.html ');

    disp('Completed!');
    disp('arduinoSupport.txt file is generated');

    edit(fileName);

    function writeHardwareInfo(fid, arduinoList)
    % Function to write the Arduino device info to the text file
        if(isempty(arduinoList))
            fprintf(fid,"Arduino hardware not detected\n");
            return;
        end

        for index = 1:length(arduinoList)
            fprintf(fid, "VendorID: %s\n", arduinoList(index).VendorID);
            fprintf(fid, "ProductID: %s\n", arduinoList(index).ProductID);
            fprintf(fid, "Manufacturer: %s\n", arduinoList(index).Manufacturer);
            fprintf(fid, "ProductName: %s\n", arduinoList(index).ProductName);
            fprintf(fid, "SerialNumber: %s\n\n", arduinoList(index).SerialNumber);
        end

    end

    function section( str )
        fprintf(fid, '\n------------------ %s ------------------ \n\n', str );
    end
    function dispFile( str )
        fprintf(fid,'%s\n', str );
    end
    function separator()
        fprintf(fid, '-----------------------------------------------------------------------------------------------------\n');
    end
end
