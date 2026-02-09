function result = findSubClasses(namespaceName, superclassName, searchSubnamespaces, filterAbstract)
%FINDSUBCLASSES   Find sub-classes within a namespace
%
%   CLASSES = FINDSUBCLASSES(NAMESPACE, SUPERCLASS) is an nx1 cell-array of
%   meta.class objects, each element being a concrete sub-class of
%   the class defined by the string SUPERCLASS and a member of the namespace
%   defined by the string NAMESPACE.
%
%   CLASSES = FINDSUBCLASSES(NAMESPACE, SUPERCLASS, SEARCHSUBNAMESPACES)
%   searches all subnamespaces of NAMESPACE if SEARCHSUBNAMESPACES is true.
%
%   Note that classes with abstract properties or methods will not be
%   returned, and SUPERCLASS itself will not be returned.
%
%    This undocumented function may be removed in a future release.
%
%   Example
%      classes = findSubClasses( 'sftoolgui.plugins', 'sftoolgui.Plugin' )

%   Copyright 2009-2023 The MathWorks, Inc.

    narginchk(2,4);

    if ~ischar(namespaceName) || ~ischar(superclassName)
        error(message('testmeaslib:findSubClasses:classNamesMustBeStrings'));
    end

    if nargin<3
        searchSubnamespaces = false;
    else
        if ~islogical(searchSubnamespaces)
            error(message('testmeaslib:findSubClasses:invalidSearchSubnamespaces'));
        end
    end

    if nargin<4
        filterAbstract = true;
    end

    % Get the namespace object
    namespaces{1} = meta.package.fromName( namespaceName );

    if isempty(namespaces{1})
        error(message('testmeaslib:findSubClasses:unknownNamespace',namespaceName));
    end

    if searchSubnamespaces
        % Expand the namespaces
        namespaces = [namespaces getSubNamespaces(namespaces{1})];
    end


    % For each class in each namespace ...
    %  1. check for given super-class
    %  2. check for abstract classes
    result = cell(0);
    for iNamespace = 1:length(namespaces)
        classes = namespaces{iNamespace}.Classes;
        keep = cellfun(@testClass, classes );

        % Return list of non-abstract classes that sub-class the given super-class
        result = [result;classes(keep)]; %#ok<AGROW>
    end

    function result = testClass(x)
        try
            if filterAbstract
                result = isAClass( superclassName, x.SuperClasses ) && ~isAbstract( x );
            else
                result = isAClass( superclassName, x.SuperClasses );
            end
        catch %#ok<CTCH>
              %The reference of SuperClasses can fail the first time that the JIT
              %runs on a class, if there's a syntax error, etc.  Ignore bad
              %classes.
            result = false;
        end
    end
end

function tf = isAClass( className, list )
% Check the LIST of classes and their superclasses for given CLASSNAME
    tf = false;
    for i = 1:length( list )
        tf = strcmp( className, list{i}.Name ) || isAClass( className, list{i}.SuperClasses );
        if tf
            break
        end
    end

end

function tf = isAbstract( class )
% A class is abstract if it has any abstract methods or properties
    tf = any( cellfun( @(x) x.Abstract, class.Methods ) ) ...
         || any( cellfun( @(x) x.Abstract, class.Properties ) );
end

function result = getSubNamespaces(namespace)
% Recursively returns cell array of meta.package objects of the
% subnamespaces of meta.package passed in.
    result = cell(0);
    subNamespaces = namespace.Packages;
    for iSubNamespace=1:length(subNamespaces)
        result = [result...
                  subNamespaces(iSubNamespace)...
                  getSubNamespaces(subNamespaces{iSubNamespace})]; %#ok<AGROW>
    end
end

% LocalWords:  nx sftoolgui plugins Plugin
