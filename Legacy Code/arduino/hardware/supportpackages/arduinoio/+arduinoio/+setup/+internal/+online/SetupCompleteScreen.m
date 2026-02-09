classdef SetupCompleteScreen < arduinoio.setup.internal.SetupCompleteScreen
    %SETUPCOMPLETESCREEN Setup screen shown at the end of the
    %Arduino online setup process, with option to launch examples.

    % Copyright 2023 The MathWorks, Inc.

    properties
        SetupCompleteInfo
        RestartSetupInfo
        ShowExamplesCheckBox
    end
    
    methods
        function obj = SetupCompleteScreen(workflow)
            arguments
                workflow matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow
            end

            obj@arduinoio.setup.internal.SetupCompleteScreen(workflow);

            stepIdx = obj.Workflow.getStepIdx(obj.Workflow.SpkgSetupStep);
            if ~isempty(stepIdx)
                obj.setActiveStep(stepIdx);
            end
        end

        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.TestConnectionScreen';
        end
    end
end

