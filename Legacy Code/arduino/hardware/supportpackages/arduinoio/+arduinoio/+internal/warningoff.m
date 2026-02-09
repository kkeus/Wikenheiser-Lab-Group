function warningoff(msgID)
% This function turns- off the display for the warning ID passed as an argument

%   Copyright 2019 The MathWorks, Inc.

    try
        warning('off',msgID);
    catch
        % don't throw error as not exposed to user
    end
end