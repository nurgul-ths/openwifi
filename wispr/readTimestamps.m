% readTimestamps - Reads timestamp information from an experiment dataset.
%
% This function loads timestamp data associated with the given experiment filename base.
% It expects a file named '<expFnameBase>_timestamps_iq' containing timestamps
% for frames or samples. The function can load from HDF5 or CSV and can operate in
% chunked mode for large datasets. Additionally, it can return informational metadata
% about the dataset if requested.
%
% USAGE:
%   [timestamps, info] = readTimestamps(expFnameBase, loadHDF5, verbose, chunkNum, returnInfo)
%
% INPUT PARAMETERS:
%   expFnameBase : A string specifying the base name of the experiment files.
%   loadHDF5     : A boolean indicating whether to load data from HDF5 format (true)
%                  or from CSV format (false).
%   verbose      : A boolean that, if true, enables verbose output (e.g., displaying
%                  dataset information for HDF5 files).
%   chunkNum     : (Optional) A positive integer specifying which chunk of data to load.
%                  If empty or not provided, the entire dataset is loaded.
%   returnInfo   : (Optional) A boolean indicating whether to return dataset metadata only.
%                  If true, 'timestamps' is returned as NaN and 'info' contains metadata.
%                  Defaults to false.
%
% OUTPUT PARAMETERS:
%   timestamps : A vector or matrix of timestamps. The exact dimensions depend on the dataset.
%                If returnInfo=true, timestamps is NaN.
%   info       : (Optional) A structure containing additional information about the dataset.
%                Returned only if returnInfo=true or if loading from HDF5.
%
% EXAMPLE:
%   % Load all timestamps from an HDF5 dataset with verbose output:
%   timestampsData = readTimestamps('myExperiment', true, true);
%
%   % Get dataset info without loading the actual timestamps:
%   [~, datasetInfo] = readTimestamps('myExperiment', true, false, [], true);
%
% NOTES:
%   - This function relies on 'loadData' to handle the details of loading from HDF5 or CSV.
%   - If chunkNum is specified, only that portion of timestamps is loaded.
%
function [timestamps, info] = readTimestamps(expFnameBase, loadHDF5, verbose, chunkNum, returnInfo)
  if nargin < 4, chunkNum   = []; end
  if nargin < 5, returnInfo = false; end

  TIMESTAMPS_IQ   = 'timestamps_iq';
  HDF5_TIMESTAMPS = '/timestamp';

  [timestamps, info] = loadData([expFnameBase, '_', TIMESTAMPS_IQ], HDF5_TIMESTAMPS, loadHDF5, verbose, chunkNum, returnInfo);
end
