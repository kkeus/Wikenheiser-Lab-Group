function [x, y] = get_latest_xy(sub)
    
x = NaN;
y = NaN;

try
    sample = sub.receive();

    x = double(sample{'x'});
    y = double(sample{'y'});

catch
    return;

end