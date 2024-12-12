% readFreq - Reads the carrier frequency vector from an experiment dataset.
%
% This function extracts the carrier frequency values associated with a given
% experiment. It expects a file named '<expFnameBase>_freq' that contains the
% frequency data. Depending on the input arguments, it can load the entire dataset
% or a specified chunk of it, and can optionally return additional informational
% metadata.
%
% USAGE:
%   [freq, info] = readFreq(expFnameBase, loadHDF5, verbose, chunkNum, returnInfo)
%
% INPUT PARAMETERS:
%   expFnameBase : A string specifying the base name of the experiment files.
%   loadHDF5     : A boolean indicating whether to load from HDF5 format (true)
%                  or from a default format (false).
%   verbose      : A boolean that, if true, enables verbose output (e.g., printing
%                  progress messages).
%   chunkNum     : (Optional) If provided, specifies a particular chunk of data
%                  to load instead of the full dataset. If empty or not provided,
%                  the entire dataset is loaded.
%   returnInfo   : (Optional) A boolean flag indicating whether to return additional
%                  dataset information. Defaults to false.
%
% OUTPUT PARAMETERS:
%   freq : A vector containing the carrier frequency values extracted from the data file.
%   info : (Optional) A structure containing additional information about the dataset,
%          returned only if returnInfo is true.
%
% EXAMPLE:
%   % Suppose your experiment files are named 'myExperiment_freq.hdf5' and
%   % you want to load them using HDF5:
%   freqData = readFreq('myExperiment', true, true);
%
%   % If you also want informational metadata:
%   [freqData, datasetInfo] = readFreq('myExperiment', true, true, [], true);
%
% NOTES:
%   - The function relies on 'loadData' to handle both HDF5 and non-HDF5 loading modes.
%   - If 'chunkNum' is provided, only that portion of the data is loaded. This can be
%     useful for handling large datasets without loading them entirely into memory.
%   - If 'returnInfo' is true, 'info' may contain metadata such as the dimensions
%     or attributes of the loaded data.
%
function [freq, info] = readFreq(expFnameBase, loadHDF5, verbose, chunkNum, returnInfo)
  if nargin < 4, chunkNum   = []; end
  if nargin < 5, returnInfo = false; end

  FREQ      = 'freq';
  HDF5_DATA = '/data';

  [freq, info] = loadData([expFnameBase, '_', FREQ], HDF5_DATA, loadHDF5, verbose, chunkNum, returnInfo);
end
