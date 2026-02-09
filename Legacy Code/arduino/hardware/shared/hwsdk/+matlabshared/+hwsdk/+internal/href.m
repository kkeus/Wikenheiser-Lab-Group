function linkstr = href(var, obj, ~, name)

%   Copyright 2017-2022 The MathWorks, Inc.

    linkstr = name;
    if strcmp(var, 'internal_href_obj')
        return;
    end

    internal_href_obj = obj; %#ok<NASGU>
    dispstr = evalc('disp(internal_href_obj)');
    %[a1, b1] = regexp(dispstr, '(?<=:\s+<a href=.*end">).*(?=</a>)');
    %[a2, b2] = regexp(dispstr, '(?<=:\s+)<a href=.*</a>');
    %if any(isempty([a1 b1 a2 b2]))
    newstr = dispstr;
    %else
    %    newstr = strcat(dispstr(1:a2-1), dispstr(a1:b1), dispstr(b2+1:end));
    %end
    newstr = strrep(newstr, '''', ''''' char(39) ''''');
    newstr = strrep(newstr, '"', ''''' char(34) ''''');
    newstr = strrep(newstr, newline, '\n');
    %linkstr = "<a href=""matlab:eval('fprintf([''" + dispstr + "\n''])')"">" + name + "</a>";
    linkstr = ['<a href=' char(34) 'matlab:eval(''fprintf([''''' newstr '\n''''])'')' char(34) '>' name '</a>'];

    %linkstr = name;


    %linkstr = ['<a href="matlab:if exist(''' var ''',''var''), disp(' var '.' nav '),end">' name '</a>'];

end

% LocalWords:  newstr linkstr
