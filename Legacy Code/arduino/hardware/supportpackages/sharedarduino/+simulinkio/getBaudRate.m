function baudrate = getBaudRate(varargin)
%getBaudRate get baud rate for external mode and Simulink IO over serial
%   Arduino targets do not expose the baud rate for external mode and
%   Simulink IO running over serial. Use this function to get the baud
%   rate.

% Copyright 2017-2019 The MathWorks, Inc.


% g1939800 - By default, setting the BaudRate to 115200 to be in sync
% with Arduino IO.
hCS = getActiveConfigSet(bdroot);

baudrate = codertarget.arduinobase.registry.getHostBoardConnectionData(hCS, 'ConnectedIO', 'Baud');

end