% readJsonFile - Reads a JSON file from disk and returns its contents as a MATLAB structure.
%
% USAGE:
%   jsonData = readJsonFile(fName)
%
% INPUT PARAMETERS:
%   fName - The full path to the JSON file to be read.
%
% OUTPUT PARAMETERS:
%   jsonData - A MATLAB structure containing the data from the JSON file.
%
% EXAMPLE:
%   data = readJsonFile('/path/to/file.json');
%
% NOTES:
%   This function relies on the built-in 'jsondecode' function to parse the file contents.
%   Ensure that the JSON file is properly formatted.
%
function jsonData = readJsonFile(fName)
  jsonStr  = fileread(fName);       % Read the JSON file into a string
  jsonData = jsondecode(jsonStr);   % Decode the JSON string into a MATLAB structure
end
