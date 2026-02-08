function [a,alias] = patch24_setupArduino()

%create arduino object
a = arduino('COM4');

%make list of pin names
alias = [];

%configure LED pins
a.configurePin('A1','DigitalOutput');
a.writeDigitalPin('A1',0);
a.configurePin('A2','DigitalOutput');
a.writeDigitalPin('A2',0);
a.configurePin('A3','DigitalOutput');
a.writeDigitalPin('A3',0);

%config output pins and set them high

a.configurePin('D5','DigitalOutput');
a.writeDigitalPin('D5',1);

a.configurePin('D6','DigitalOutput');
a.writeDigitalPin('D6',1);

a.configurePin('D7','DigitalOutput');
a.writeDigitalPin('D7',1);

a.configurePin('D8','DigitalOutput');
a.writeDigitalPin('D8',1);

a.configurePin('D9','DigitalOutput');
a.writeDigitalPin('D9',1);

a.configurePin('D10','DigitalOutput');
a.writeDigitalPin('D10',1);

a.configurePin('D11','DigitalOutput');
a.writeDigitalPin('D11',1);

a.configurePin('D12','DigitalOutput');
a.writeDigitalPin('D12',1);

a.configurePin('D13','DigitalOutput');
a.writeDigitalPin('D13',1);

a.configurePin('A4','DigitalOutput');
a.writeDigitalPin('A4',1);

a.configurePin('A5','DigitalOutput');
a.writeDigitalPin('A5',1);

a.configurePin('A0','DigitalOutput');
a.writeDigitalPin('A0',0);


%reset the motor arduino
pause(1)
a.writeDigitalPin('D5',0);
pause(0.1)
a.writeDigitalPin('D5',1);
pause(0.25)















% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% %old code
% 
% a.configurePin('A0','DigitalOutput');
% a.writeDigitalPin('A0',1);
% 
% a.configurePin('A1','DigitalOutput');
% a.writeDigitalPin('A1',1);
% 
% a.configurePin('A2','DigitalOutput');
% a.writeDigitalPin('A2',1);
% 
% a.configurePin('A3','DigitalOutput');
% a.writeDigitalPin('A3',1);
% 
% a.configurePin('A4','DigitalOutput');
% a.writeDigitalPin('A4',1);
% 
% a.configurePin('A5','DigitalOutput');
% a.writeDigitalPin('A5',1);
% 
% %set feeder output pins and write them high
% a.configurePin('D10','DigitalOutput');
% a.writeDigitalPin('D10',1);
% 
% a.configurePin('D11','DigitalOutput');
% a.writeDigitalPin('D11',1);
% 
% %setup tone output pin
% a.configurePin('D9','DigitalOutput');
% a.writeDigitalPin('D9',1);
% 
% %sync LED/pin
% a.configurePin('D8','DigitalOutput');
% a.writeDigitalPin('D8',0);
% 
% %set up reset pin
% a.configurePin('D13','DigitalOutput');
% a.writeDigitalPin('D13',1);
% 
% 
% 
% %reset the motor arduino
% pause(1)
% a.writeDigitalPin('D13',0);
% pause(0.1)
% a.writeDigitalPin('D13',1);
% 
% 
% 
% 
% 
% 
