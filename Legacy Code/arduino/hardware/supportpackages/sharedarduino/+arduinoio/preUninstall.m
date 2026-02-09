function preUninstall()
%PREUNINSTALL Uninstall the Arduino CLI files from the CLIRoot
%  after MATLAB Support Package for Arduino Hardware or
%  Simulink Support Package for Arduino Hardware uninstaller
%  is initiated.
%

%  Copyright 2021-2023 The MathWorks, Inc.

    try
        % NOTE: Do not remove the exclude pragma.
        % This is responsible for suppressing the
        % compiler warnings associated with
        % matlabshared.supportpkg.getInstalled
        installedSupportPackages = matlabshared.supportpkg.getInstalled; %#exclude matlabshared.supportpkg.getInstalled
        installedSupportPackages = {installedSupportPackages.Name};
        % Remove Arduino CLI files from the CLIRoot if any one of
        % the SPPKGs is installed on windows only
        if ~all(ismember({'Simulink Support Package for Arduino Hardware','MATLAB Support Package for Arduino Hardware'}, installedSupportPackages))
            pathName = fullfile(matlabshared.supportpkg.getSupportPackageRoot, 'aCLI');
            if ~isempty(pathName)
                [~, ~] = rmdir(pathName, 's');
            end
        end
    catch
        % Do not error
    end
end
