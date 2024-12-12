% createInterimLogFile - Function to create a transformed "interim" log file from a raw experimental log file.
%
% This function reads a JSON file containing experiment details and modifies the directory and filename fields
% to reflect a transition from an original ("raw") state to a new ("interim") state. This is useful when
% transitioning data and logs from one stage of processing to another. The function then writes the updated
% information to a new JSON log file.
%
% USAGE:
%   createInterimLogFile(repoPath, rxExpJsonDataFile, fileNameBase)
%
% INPUT PARAMETERS:
%   repoPath          - Path to the repository where log files are stored.
%   rxExpJsonDataFile - Struct with at least a field 'fname_base' identifying the base filename of the original log JSON file.
%   fileNameBase      - The base name for the resulting interim output file.
%   orig              - (Optional) String specifying the original folder/tag name (default: 'raw').
%   new               - (Optional) String specifying the new folder/tag name (default: 'interim').
%
% OUTPUT PARAMETERS:
%   None. This function writes an updated JSON log file with interim filenames and directories.
%
% EXAMPLE:
%   createInterimLogFile('/path/to/repo', rxExpJsonDataFile, 'mydata')
%
% NOTE:
%   The function assumes that the original log file name ends with a consistent suffix (e.g. '_openwifi_log.txt').
%   This suffix is reused in the interim log file name.
%

function createInterimLogFile(repoPath, rxExpJsonDataFile, fileNameBase, orig, new)
  if nargin < 4 || isempty(orig)
    orig = 'raw';
    new = 'interim';
  end

  logFileSuffix = '_openwifi_log.txt';

  % Read the original JSON log file
  owLogjsonFname = strcat(repoPath, '/', rxExpJsonDataFile.fname_base, logFileSuffix);
  owLogjsonData  = readJsonFile(owLogjsonFname);

  % Update fields to reflect the interim state
  owLogjsonData.exp_dir    = strrep(owLogjsonData.exp_dir, orig, new);
  owLogjsonData.fname_base = strrep(owLogjsonData.fname_base, orig, new);
  owLogjsonData.log_fname  = strrep(owLogjsonData.log_fname, orig, new);

  % Write out the new interim JSON log file
  interimOwLogjsonFname = strcat(repoPath, '/', fileNameBase, logFileSuffix);
  writeJsonFile(owLogjsonData, interimOwLogjsonFname);
end
