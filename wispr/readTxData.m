% readTxData - Reads transmitted signal (TX) data from an experiment dataset.
%
% This function loads the transmitted IQ data (real and imaginary parts) associated
% with the given experiment filename base. It expects files named '<expFnameBase>_tx_iq0_real'
% and '<expFnameBase>_tx_iq0_imag' containing the real and imaginary components
% of the transmitted waveform. The function can load from HDF5 or CSV and may operate
% in chunked mode for large datasets. Additionally, it can return dataset metadata
% if requested.
%
% USAGE:
%   [dataStruct, info] = readTxData(expFnameBase, loadHDF5, verbose, chunkNum, returnInfo)
%
% INPUT PARAMETERS:
%   expFnameBase : A string specifying the base name of the experiment files.
%   loadHDF5     : A boolean indicating whether to load from HDF5 (true) or CSV (false).
%   verbose      : A boolean that, if true, enables verbose output (e.g., dataset info).
%   chunkNum     : (Optional) A positive integer specifying which chunk of data to load.
%                  If empty or not provided, the entire dataset is loaded.
%   returnInfo   : (Optional) A boolean indicating whether to return dataset metadata only.
%                  If true, 'dataStruct' is not populated with data, and 'info' contains metadata.
%                  Defaults to false.
%
% OUTPUT PARAMETERS:
%   dataStruct : A structure containing the transmitted IQ data, with:
%                dataStruct.txIqArray = (N x M) complex array (or possibly N x 1 x M if desired),
%                where N is the number of frames (observations) and M is the number of samples per frame.
%                If returnInfo=true, dataStruct is not returned with data.
%   info       : (Optional) A structure containing dataset metadata when returnInfo=true
%                or if loading from HDF5.
%
% EXAMPLE:
%   % Load entire TX IQ data from HDF5:
%   txData = readTxData('myExperiment', true, false);
%
%   % Get dataset info without loading actual data:
%   [~, datasetInfo] = readTxData('myExperiment', true, false, [], true);
%
% NOTES:
%   - The function uses 'loadData' to load real and imaginary parts of the TX IQ data.
%   - If returnInfo is true, only the info from the first dataset (real part) is returned,
%     and data is not loaded.
%   - If chunkNum is provided, only that portion of data is loaded.
%
function [dataStruct, info] = readTxData(expFnameBase, loadHDF5, verbose, chunkNum, returnInfo)
  if nargin < 4, chunkNum   = []; end
  if nargin < 5, returnInfo = false; end

  TX_IQ0_REAL = 'tx_iq0_real';
  TX_IQ0_IMAG = 'tx_iq0_imag';
  HDF5_DATA   = '/data';

  [txIq0Real, info] = loadData([expFnameBase, '_', TX_IQ0_REAL], HDF5_DATA, loadHDF5, verbose, chunkNum, returnInfo);

  if returnInfo
    % If only info was requested, return without loading data
    dataStruct = [];
    return;
  end

  txIq0Imag = loadData([expFnameBase, '_', TX_IQ0_IMAG], HDF5_DATA, loadHDF5, verbose, chunkNum, false);

  dataStruct.txIqArray = txIq0Real + 1i * txIq0Imag;
end
