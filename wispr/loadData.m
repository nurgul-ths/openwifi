% loadData - Loads data from either an HDF5 or CSV file, with optional chunked reading.
%
% This function attempts to load data from an HDF5 file if 'loadHdf5' is true and
% the corresponding HDF5 file exists. Otherwise, it falls back to a CSV file if
% available. The loaded data is typically arranged such that each row corresponds
% to a frame (observation) and each column corresponds to a data dimension (e.g., I/Q samples).
%
% Chunked reading is supported for HDF5 files to allow partial loading of large datasets.
% By specifying 'chunkNum', you can read a subset of the data rows, which can help
% manage memory usage for large datasets.
%
% Setting 'returnInfo' to true retrieves dataset metadata (dimensions, attributes)
% without loading the actual data.
%
% USAGE:
%   [data, info] = loadData(fName, dataset, loadHdf5, verbose, chunkNum, returnInfo)
%
% INPUT PARAMETERS:
%   fName      : Base filename (without extension). The function will look for
%                '<fName>.hdf5' or '<fName>.csv'.
%   dataset    : The dataset path (for HDF5), typically something like '/data'.
%   loadHdf5   : A boolean indicating whether to attempt loading from HDF5. If false
%                or if the HDF5 file does not exist, the function attempts to load CSV.
%   verbose    : A boolean. If true, additional output (like h5disp) is displayed
%                when reading from HDF5.
%   chunkNum   : (Optional) A positive integer specifying which chunk of rows to load
%                from the HDF5 dataset. Each chunk is defined as 'nRows' worth of data.
%                If empty or not provided, the entire dataset is loaded.
%   returnInfo : (Optional) A boolean indicating if only dataset info should be returned.
%                If true, 'data' is returned as NaN and 'info' contains dataset metadata.
%                Defaults to false.
%
% OUTPUT PARAMETERS:
%   data : Loaded data, typically (N x M) where N is the number of frames (observations)
%          and M is the number of data dimensions (e.g., I/Q samples). If chunked reading
%          is used, 'data' corresponds to the specified chunk.
%          If returnInfo=true, data is NaN.
%   info : If reading from HDF5 and returnInfo=false, info may contain metadata such as
%          the HDF5 dataset dimensions. If returnInfo=true, 'info' holds dataset metadata
%          and no data is loaded. If reading from CSV or if no metadata is available,
%          info is empty.
%
% EXAMPLES:
%   % Load the entire dataset from HDF5:
%   [data, info] = loadData('myExperiment_freq', '/data', true, true);
%
%   % Load only the second chunk of data (rows 1001 to 2000):
%   [data, info] = loadData('myExperiment_freq', '/data', true, false, 2);
%
%   % Just get info without loading data:
%   [~, datasetInfo] = loadData('myExperiment_freq', '/data', true, false, [], true);
%
% NOTES:
%   - If both HDF5 and CSV files are present and loadHdf5=true, the HDF5 file is
%     loaded by default. If HDF5 does not exist, CSV is used.
%   - If loadHdf5=false, CSV is loaded if it exists, even if HDF5 is available.
%   - The function attempts to reshape or transpose the data so that the final
%     orientation places observations (e.g., frames) along the rows.
%   - A default chunk size (nRows=1000) is defined internally.
%
function [data, info] = loadData(fName, dataset, loadHdf5, verbose, chunkNum, returnInfo)
  if nargin < 6, returnInfo = false; end

  nRows = 1000; % Default number of rows to read at a time for chunked reading

  hdf5FileName = [fName, '.hdf5'];
  csvFileName  = [fName, '.csv'];

  hdf5Exists = exist(hdf5FileName, 'file') == 2;
  csvExists  = exist(csvFileName, 'file') == 2;

  if ~csvExists && ~hdf5Exists
    warning(['Neither ' hdf5FileName ' nor ' csvFileName ' exist.']);
    data = NaN;
    info = [];
    return;
  end

  if loadHdf5 && hdf5Exists
    if verbose
      h5disp(hdf5FileName);
    end

    info = h5info(hdf5FileName, dataset);

    if returnInfo
      data = NaN;
      return;
    end

    if nargin < 5 || isempty(chunkNum)
      % Read the entire dataset
      data = h5read(hdf5FileName, dataset);
      data = reshape(data, [], 1);
    else
      % Partial read using chunkNum
      dataSize = info.Dataspace.Size;
      startRow = (chunkNum - 1) * nRows + 1;

      if numel(dataSize) == 1
        % One-dimensional data: just read entire dataset
        data = h5read(hdf5FileName, dataset);
        data = reshape(data, [], 1);
      else
        % Data is two-dimensional: [nDatapoints, nFrames]
        endRow   = min(chunkNum * nRows, dataSize(2));
        rowCount = endRow - startRow + 1;

        startLoc = [1, startRow];          % Start from the first datapoint and 'startRow'th frame
        countLoc = [dataSize(1), rowCount];% Select all datapoints and 'rowCount' frames
        data     = h5read(hdf5FileName, dataset, startLoc, countLoc);

        % Transpose so that rows correspond to frames and columns to data points
        data     = transpose(data);
      end
    end

  elseif loadHdf5 && ~hdf5Exists
    fprintf('loadData: %s does not exist. CSV file will be loaded instead.\n', hdf5FileName);
    data = readmatrix(csvFileName);
    info = [];

  elseif ~loadHdf5
    data = readmatrix(csvFileName);
    info = [];
    if hdf5Exists
      fprintf('loadData: %s exists, but loadHdf5 is false. Loading CSV instead (slower).\n', hdf5FileName);
    end
  end
end
