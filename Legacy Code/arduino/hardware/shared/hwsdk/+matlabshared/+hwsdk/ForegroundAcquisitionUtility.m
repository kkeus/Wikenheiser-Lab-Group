classdef ForegroundAcquisitionUtility <handle
% helper class for providing all the foreground streaming related
% function for HWSDK

% Copyright 2024 The MathWorks, Inc.

    methods(Access = ?matlabshared.hwsdk.internal.base)

        function preRegistrationConfig(obj,protocolObj)
        % Function to do all settings before registering requestID for
        % streaming
            setIgnoreOnetimeConfig(protocolObj, 0);
            setFlushBufferOnDemandWhileStreaming(protocolObj, 1);
            startConfigureStreaming(protocolObj);
            setIOProtocolReadMode(protocolObj, 'oldest');
        end
        function postRegistrationConfig(obj,protocolObj,SampleRate,hostSPF)
        % Function to do all settings after registering requestID for
        % streaming
            setRate(protocolObj, 1 / SampleRate);
            TargetSamplesPerFrame = 1;
            setSPFiOProtocol(protocolObj, TargetSamplesPerFrame);
            setHostSamplesPerFrame(protocolObj, hostSPF);
            setIgnoreOnetimeConfig(protocolObj, 0);
            stopConfigureStreaming(protocolObj);
            enableTimestamp(protocolObj, 1);
            protocolObj.IOProtocolTimeoutThreshold = 2*(hostSPF/SampleRate);
        end
        function [counts,timestamps] = record(obj,protocolObj,functionHandle)
            if ~(ispref('MATLAB_HARDWARE','HostIOServerEnabled') && getpref('MATLAB_HARDWARE','HostIOServerEnabled'))
                % Not calling startStreaming for HostIOServer till it is supported by the utility
                try
                    startStreaming(protocolObj);
                catch ME
                    throwAsCaller(ME);
                end
            end
            flushBuffers(protocolObj);
            [counts, ~,timestamps] = functionHandle();
            stopStreaming(protocolObj);
        end
        % Clean up function to handle edge cases like cltr+c or stop
        % button
        function cleanUpRecording(obj,protocolObj)
            % Check whether the device is in startConfiguration Streaming
            % mode.
            if(protocolObj.StartStreamModeConfiguration)
                stopConfigureStreaming(protocolObj);
            end
            % Check whether device is already streaming
            if(protocolObj.StreamingModeOn)
            % Stop streaming if the device is already streaming
                stopStreaming(protocolObj);
            end
        end
    end
end
