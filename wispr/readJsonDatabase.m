% readJsonDatabase - Reads a database JSON file containing experiment metadata and retrieves information for a specific experiment.
%
% This function expects a structured JSON file named 'database.json' in the specified directory.
% The JSON file contains data indexed by numeric file numbers (prefixed with 'x'), each corresponding
% to a particular experiment. Using the provided fileNumber, this function returns the base filename
% and the corresponding metadata for that experiment.
%
% USAGE:
%   [expFnameBase, expJsonDataFile] = readJsonDatabase(path, fileNumber)
%
% INPUT PARAMETERS:
%   path       - The directory containing 'database.json'.
%   fileNumber - A numeric identifier for the experiment entry in the database.
%                The JSON keys are assumed to be of the form 'x<number>', e.g. 'x1', 'x2', etc.
%
% OUTPUT PARAMETERS:
%   expFnameBase    - The base filename for the experiment files (a string).
%   expJsonDataFile - A struct containing metadata fields for the specified experiment.
%
% EXAMPLE:
%   [base, data] = readJsonDatabase('/path/to/repo', 1);
%   % This returns the metadata for the experiment indexed by 'x1' in the database.json.
%
% NOTES:
%   For details on the database structure and how it is created, see the related script:
%   openwifi_boards/scripts/data/create_database.py
%
function [expFnameBase, expJsonDataFile] = readJsonDatabase(path, fileNumber)
  jsonData = readJsonFile(fullfile(path, 'database.json'));

  % Extract the specific experiment's data using the key 'x<fileNumber>'
  expJsonDataFile = jsonData.(strcat('x', num2str(fileNumber)));
  expFnameBase    = expJsonDataFile.fname_base;
end
