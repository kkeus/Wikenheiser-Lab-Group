function linkstr = footer(var, varargin)
%FOOTER Returns the footer text as a string

%   Copyright 2017-2019 The MathWorks, Inc.

    linkstr = [];
    if isempty(var)
        return;
    end

    try
        obj = evalin('base', var);
    catch
        % var not available in base workspace. Don't show footers.
        return;
    end
    objMeta = metaclass(obj);
    methodNames = cellfun(@(x){x.Name},objMeta.Methods);

    bShowAllProperties = any(cellfun(@(s) contains('showAllProperties', s), methodNames));
    bShowFunctions = any(cellfun(@(s) contains('showFunctions', s), methodNames));
    bShowLatestValues = any(cellfun(@(s) contains('showLatestValues', s), methodNames));

    p = inputParser;
    p.PartialMatching = true;
    addParameter(p, 'Functions', 1);
    addParameter(p, 'AllProperties', 1);
    addParameter(p, 'LatestValues', 1);
    parse(p, varargin{:});

    bShowAllProperties = bShowAllProperties && p.Results.AllProperties;
    bShowFunctions = bShowFunctions && p.Results.Functions;
    bShowLatestValues = bShowLatestValues && p.Results.LatestValues;

    i = 1;
    if bShowAllProperties
        links{i} = ['<a href="matlab:if exist(''' var ''',''var''), showAllProperties(' var '),end" style="font-weight:bold">all properties</a>'];
        i = i + 1;
    end

    if bShowFunctions
        links{i} = ['<a href="matlab:if exist(''' var ''',''var''), showFunctions(' var '),end" style="font-weight:bold">functions</a>'];
        i = i + 1;
    end

    if bShowLatestValues
        links{i} = ['<a href="matlab:if exist(''' var ''',''var''), showLatestValues(' var '),end" style="font-weight:bold">latest values</a>'];
        i = i + 1;
    end

    %         linkstr = [...
    %             'Show <a href="matlab:if exist(''' var ''',''var''), showAllProperties(' var '),end" style="font-weight:bold">all properties</a>' ...
    %             ', <a href="matlab:if exist(''' var ''',''var''), showFunctions(' var '),end" style="font-weight:bold">functions</a>' ...
    %             ', <a href="matlab:if exist(''' var ''',''var''), showLatestValues(' var '),end" style="font-weight:bold">latest values</a>' ...
    %              ];

    if i > 1
        linkstr = ['Show ' matlabshared.hwsdk.internal.renderCellArrayOfStringsToString(links, ', ')];
    end

end

% LocalWords:  linkstr
