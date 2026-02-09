function [port, board, arduinoCLILocation] = getPortBoardCLI(utilityObj, defaultPort, defaultBoard)
%GETPORTBOARDCLI is a method which gets called only in MCR environment
%   Launches a UI to fetch Portname, Boardname and ArduinoCLILocation from
%   the End User.

%   Copyright 2019-2023 The MathWorks, Inc.

    % Launch the Configure Arduino UI
    app = arduinoio.internal.MLCompiler_Arduino(utilityObj, defaultPort, defaultBoard);
    % Block flow until released from the UI.
    uiwait(app.ConfigureArduinoUIFigure);
    if isvalid(app)
        % Fetch needed parameters from the App and destruct it
        port = app.COMPortDropDown.Value;
        board = app.BoardDropDown.Value;
        arduinoCLILocation = app.ArduinoCLIPathEditField.Value;
        delete(app);
    else
        % User closed / cancelled UI before we could fetch the needed parameters
        m = message('MATLAB:arduinoio:general:uiCloseDeploy');
        disp(m.getString());
        quit;
    end

end
