function patch_fireFeeder(a,feeder,nPellets)

pulseLen = 0.1;

for iP = 1:nPellets;
    a.writeDigitalPin(feeder,0);
    pause(pulseLen);
    a.writeDigitalPin(feeder,1);
    pause(pulseLen/2);
end