% readRxData - Reads received signal (RX) data from an experiment dataset.
%
% This function loads the received IQ data (real and imaginary parts) for one or two
% receive antennas, depending on the specified dataType. It expects files named:
% - '<expFnameBase>_rx_iq0_real' and '<expFnameBase>_rx_iq0_imag' for the first antenna.
% - If dataType='rx_iq0_iq1', it also expects '<expFnameBase>_rx_iq1_real' and
%   '<expFnameBase>_rx_iq1_imag' for the second antenna.
%
% The function can load from HDF5 or CSV and may operate in chunked mode for large datasets.
% Additionally, it can return dataset metadata if requested (based on the first loaded dataset).
%
% USAGE:
%   [dataStruct, info] = readRxData(expFnameBase, dataType, loadHDF5, verbose, chunkNum, returnInfo)
%
% INPUT PARAMETERS:
%   expFnameBase : A string specifying the base name of the experiment files.
%   dataType     : A string specifying the type of RX data, such as 'tx_rx_iq0' or 'rx_iq0_iq1',
%                  indicating whether one or two sets of RX IQ data are needed.
%   loadHDF5     : A boolean indicating whether to load from HDF5 (true) or CSV (false).
%   verbose      : A boolean that, if true, enables verbose output (e.g., dataset info).
%   chunkNum     : (Optional) A positive integer specifying which chunk of data to load.
%                  If empty or not provided, the entire dataset is loaded.
%   returnInfo   : (Optional) A boolean indicating whether to return dataset metadata only.
%                  If true, 'dataStruct' is not returned with data, and 'info' contains metadata.
%                  Defaults to false.
%
% OUTPUT PARAMETERS:
%   dataStruct : A structure containing the received IQ data. The field dataStruct.rxIqArray
%                is of size (N x R x M), where:
%                - N is the number of frames (observations),
%                - R is the number of receive antennas (1 or 2),
%                - M is the number of samples per frame.
%                If returnInfo=true, dataStruct is not returned with data.
%   info       : (Optional) A structure containing dataset metadata when returnInfo=true
%                or if loading from HDF5.
%
% EXAMPLE:
%   % Load single-antenna RX IQ data from HDF5:
%   rxData = readRxData('myExperiment', 'tx_rx_iq0', true, false);
%
%   % Load two-antenna RX IQ data, chunked:
%   rxDataChunk = readRxData('myExperiment', 'rx_iq0_iq1', true, false, 2);
%
%   % Get dataset info only (no actual data):
%   [~, datasetInfo] = readRxData('myExperiment', 'tx_rx_iq0', true, true, [], true);
%
% NOTES:
%   - The function selects which files to load based on dataType.
%   - If returnInfo is true, only the info from the first dataset (e.g., rx_iq0_real) is returned,
%     and no data is loaded.
%   - If chunkNum is provided, only that portion of the data is loaded.
%
function [dataStruct, info] = readRxData(expFnameBase, dataType, loadHDF5, verbose, chunkNum, returnInfo)
  if nargin < 5, chunkNum   = []; end
  if nargin < 6, returnInfo = false; end

  RX_IQ0_REAL = 'rx_iq0_real';
  RX_IQ0_IMAG = 'rx_iq0_imag';
  RX_IQ1_REAL = 'rx_iq1_real';
  RX_IQ1_IMAG = 'rx_iq1_imag';
  HDF5_DATA   = '/data';

  switch dataType
    case 'tx_rx_iq0'
      [rxIq0Real, info] = loadData([expFnameBase, '_', RX_IQ0_REAL], HDF5_DATA, loadHDF5, verbose, chunkNum, returnInfo);

      if returnInfo
        dataStruct = [];
        return;
      end

      rxIq0Imag = loadData([expFnameBase, '_', RX_IQ0_IMAG], HDF5_DATA, loadHDF5, verbose, chunkNum, false);

      rxIq0 = rxIq0Real + 1i * rxIq0Imag;

      nFrames = size(rxIq0, 1);
      nIq     = size(rxIq0, 2);
      nRxAnt  = 1;

      dataStruct.rxIqArray = zeros(nFrames, nRxAnt, nIq);
      dataStruct.rxIqArray(:, 1, :) = rxIq0;

    case 'rx_iq0_iq1'
      [rxIq0Real, info] = loadData([expFnameBase, '_', RX_IQ0_REAL], HDF5_DATA, loadHDF5, verbose, chunkNum, returnInfo);

      if returnInfo
        dataStruct = [];
        return;
      end

      rxIq0Imag = loadData([expFnameBase, '_', RX_IQ0_IMAG], HDF5_DATA, loadHDF5, verbose, chunkNum, false);
      rxIq1Real = loadData([expFnameBase, '_', RX_IQ1_REAL], HDF5_DATA, loadHDF5, verbose, chunkNum, false);
      rxIq1Imag = loadData([expFnameBase, '_', RX_IQ1_IMAG], HDF5_DATA, loadHDF5, verbose, chunkNum, false);

      rxIq0 = rxIq0Real + 1i * rxIq0Imag;
      rxIq1 = rxIq1Real + 1i * rxIq1Imag;

      nFrames = size(rxIq0, 1);
      nIq     = size(rxIq0, 2);
      nRxAnt  = 2;

      dataStruct.rxIqArray = zeros(nFrames, nRxAnt, nIq);
      dataStruct.rxIqArray(:, 1, :) = rxIq0;
      dataStruct.rxIqArray(:, 2, :) = rxIq1;

  end
end
