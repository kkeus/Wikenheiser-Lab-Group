function pinsString = renderArrayOfPinStringsToRangedString(pins)
%RENDERPINSARRAYOFSTRINGSTOSTRING Accepts an array of pin strings and
%converts into a string
% 1. Expects an ascendingly sorted array of pin strings. Unsorted / Descending
% sorted array will not provide expected results
% Example:
% m = microbit;
% %% Ascendingly Sorted array of strings (m.AvailableAnalogPins)
% matlabshared.hwsdk.internal.renderPinsArrayOfStringsToString(m.AvailableAnalogPins)
% ans = 
%    ""P0-P4", "P10""
% %% Descendingly sorted array of strings (m.AvailableAnalogPins(end:-1:1))
% matlabshared.hwsdk.internal.renderPinsArrayOfStringsToString(m.AvailableAnalogPins(end:-1:1))
% ans = 
%     ""P10", "P4", "P3", "P2", "P1", "P0""
%
% 
% 2. Can render different pin groups
% Example:
% a = arduino;
% matlabshared.hwsdk.internal.renderPinsArrayOfStringsToString(a.AvailablePins)
% ans = 
%     ""D2-D13", "A0-A5""
%
% 3. Expects an array of strings and not character vectors

%   Copyright 2018 The MathWorks, Inc.

    numOfPins = numel(pins);
    numAlpha = [];
    index = [];
    parser = 1;
    while (numOfPins >= parser)
        % Get the information about a pin group
        [f, b] = getPinGroupInfo(pins(parser:end));
        % The pin number is available between numAlpha and length(str)
        numAlpha = [numAlpha,f]; %#ok<AGROW>
        % index -> number of pins in the range
        index = [index,parser+b]; %#ok<AGROW>
        % Jump to the next pin group
        parser = parser + b + 1;
    end
    
    % Get the pins string to be printed
    pinsString = "";
    numPins = length(pins);
    i = 1;
    while i <= numPins
        % Get a range of consecutive pins
        pinsString = pinsString + printPins(pins(i:index(1)), numAlpha(1));
        % Jump to the next set of consecutive pins
        i = index(1) + 1;
        if i <= numPins
            pinsString = pinsString + ", ";
        end
        
        % Destroy the information about the printed range
        numAlpha(1) = [];
        index(1) = [];
    end
end

function pins = printPins(pins, numAlpha, ~)
    container = 1;
    pinsOutput = "";
    pinsOutput = pinsOutput + """" + pins(1);
    numPins = length(pins);

    for i = 2:numPins
        pin1Num = str2double(extractBetween(pins(i-1), ... % Extract the pin number
                            numAlpha + 1, ... % Between the front substring
                            length(char(pins(i-1))))); % And end of string
        if isnan(pin1Num)
            pinsOutput = pinsOutput + """, ";
            pinsOutput = pinsOutput + """" + char(pins(i));
            container = 1;
        else
            % Extract the pin number
            pin2Num = str2double(extractBetween(pins(i), ...
                                numAlpha + 1, ...
                                length(char(pins(i)))));
            difference = pin2Num - pin1Num;
            if difference ~= 1
                % End of a set of consecutive pins
                if container ~= 1
                    pinsOutput = pinsOutput + "-" + char(pins(i-1));
                end
                pinsOutput = pinsOutput + """, ";
                
                % Start of next set of consecutive pins
                pinsOutput = pinsOutput + """" + char(pins(i));
                container = 1;
            elseif i == numPins
                % Last pin of the group
                pinsOutput = pinsOutput + "-" + char(pins(i));
            else
                % Consecutive pins. Nothing to display.
                container = container + 1;
            end
        end
    end
    % End of display
    pins = pinsOutput + """";
end

function [numberOfAlphabets, numberOfPins] = getPinGroupInfo(pinsArray)
% GETPINGROUPINFO
% numberOfAlphabets - Number of matching alphabets from the start of Pin string
% numberOfPins - Number of Pins in the current pin group
    len1 = lengthOfPinString(pinsArray(1));
    numberOfAlphabets = 0;
    numberOfPins = 0;
    for pin = pinsArray(2:end)
        len2 = lengthOfPinString(pin);
        switch len1
            case 0
                % only numbers in the pinstring1
                % Alphabets end at index 0
                numberOfAlphabets = len1;
                numberOfPins = numberOfPins + 1;
            case strlength(pinsArray(1))
                % only characters in the pinstring1 => Cannot range.
                % Because there cannot two pins with same name (full of
                % characters)
            otherwise
                % mix of leading characters and trailing numbers in
                % pinstring1
                if 0~=len2 && strlength(pin)~=len2
                    if len1 == len2
                        % Same number of alphabets in the pinstrings

                        % Check if the alphabets match in both pinstrings
                        if strncmpi(pinsArray(1),pin,len1)
                            % Strings are from same pin group (D1,D2)/(P1,P2)/(A1,A2)
                            % Alphabets end at len1/len2
                            numberOfAlphabets = len1;
                            % Have a count of pins in a pin group
                            numberOfPins = numberOfPins + 1;
                        else
                            % No match between pinstrings
                            % End of pin group
                            break;
                        end
                    end
                end
        end
    end
end

function length = lengthOfPinString(pin)
    % Indicate all characters as 0
    charactersInPin = isstrprop(pin, 'digit');
    % Find the index of last character from the end of pin string
    indexOfLastAlphabet = find(~flip(charactersInPin), 1, 'first');
    if isempty(indexOfLastAlphabet)
        % No characters in pin
        length = 0;
    else
        % Get the length of pin string
        length = strlength(pin) - indexOfLastAlphabet + 1;
    end
end