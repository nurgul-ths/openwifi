% getDataTypeFromPath - Determines the data type from a given input directory path.
%
% This function checks the directory components of the provided input data path
% (not the final filename) against a predefined list of known data types. If one
% of these known data types is found in the directory structure, that data type
% is returned. If no recognized data type is found, the function throws an error.
%
% USAGE:
%   dataType = getDataTypeFromPath(inDataPath)
%
% INPUT PARAMETERS:
%   inDataPath : A string specifying the input data path. The data type must
%                appear in one of the directories in this path (not the filename).
%
% OUTPUT PARAMETERS:
%   dataType   : A string representing the identified data type. It will be
%                one of the known data types, such as 'csi', 'rssi_rx_iq0',
%                'rx_iq0_iq1', 'tx_rx_iq0', or 'iq_all'.
%
% EXAMPLE:
%   Suppose you have a data file located at:
%   '/path/to/data/csi/samples.bin'
%
%   Calling:
%   dataType = getDataTypeFromPath('/path/to/data/csi/samples.bin')
%
%   Returns:
%   dataType = 'csi'
%
% NOTES:
%   - This function only inspects the directories in the given path. The actual
%     filename is not considered when identifying the data type.
%   - The matching is case-sensitive, so the directory names and data types
%     should use a consistent naming convention.
%   - If none of the known data types are found in the directory path, an error
%     is raised.
%
function dataType = getDataTypeFromPath(inDataPath)
  % List of known data types
  dataTypes = {'csi', 'rssi_rx_iq0', 'rx_iq0_iq1', 'tx_rx_iq0', 'iq_all'};
  dataType = [];

  % Extract only the directory portion of the path, ignoring the filename
  [dirPath, ~, ~] = fileparts(inDataPath);

  % Split the directory path into its components
  pathParts = strsplit(dirPath, filesep);

  % Check if any of the known data types are present in the directory structure
  for i = 1:length(dataTypes)
    if any(strcmp(pathParts, dataTypes{i}))
      dataType = dataTypes{i};
      break;
    end
  end

  % Throw an error if no known data type is found in the directory path
  if isempty(dataType)
    error('Unknown data type in the given directory path.');
  end
end
