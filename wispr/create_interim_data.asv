% script_create_interim_data.m - Simplified CSI estimation from 802.11n signals
%
% This script provides a streamlined version of script_create_interim_data.m, focused solely
% on cross-correlation-based CSI estimation. While the full script implements multiple CSI
% estimation methods (LLTF, HTLTF, data-based, etc.), this version only implements the
% cross-correlation method which computes CSI by correlating received signals with known
% transmitted signals.
%
% Key differences from script_create_interim_data.m:
% - Only implements cross-correlation based CSI estimation
% - Saves directly to csiArray/cirArray (equivalent to csiCorrArray/cirCorrArray in full script)
% - Removes all other CSI estimation methods (LLTF, HTLTF, data-based)
% - Removes interpolation, phase correction, and advanced filtering options
% - Keeps only essential diagnostics (signal power, clipping detection)
% - Simplifies the save process to a single file
%
% Steps performed by this script:
% 1. Loads configuration and settings from standard config files (e.g., cfgHT, cfgInterim, cfg80211)
% 2. Processes each dataset:
%    - Reads TX/RX data in chunks
%    - Computes basic signal diagnostics (e.g., clipping)
%    - Estimates CSI using cross-correlation
%    - Optionally applies basic CSI filtering if configured
% 3. Saves results in interim_data format
%
% Dependencies (custom functions not defined in this script):
%   getSubcarrierMapping(fieldname, cfgHT)
%   getDataTypeFromPath(inDataPath)
%   getFftDcIdx(fftLength)
%   getPrunedDFTMatrix(FFTLength, ActiveFFTIndices, fftDcIdx)
%   readJsonFile(jsonFilePath)
%   readJsonDatabase(jsonPath, iDataset)
%   readTimestamps(expFnameBase, loadHDF5, verbose)
%   readFreq(expFnameBase, loadHDF5, verbose)
%   readTxData(expFnameBase, loadHDF5, verbose, iChunk)
%   readRxData(expFnameBase, dataType, loadHDF5, verbose, iChunk)
%   computeCirCorr(txIqData, rxIqData, rxStartIndex, FFTLength)
%   filterCSI(csi, info, csiFiltSize)
%   createInterimLogFile(repoPath, expJsonDataFile, fileNameBase)
%
% Dependencies (Toolbox or other standard functions):
%   wlanHTConfig (MATLAB WLAN Toolbox)
%   pinv (MATLAB built-in)
%
% Notes:
% - For advanced processing options, use the full script_create_interim_data.m instead.
% - The CSI/CIR arrays here correspond to csiCorrArray/cirCorrArray in the full script.


% createInterimData - Simplified CSI estimation from 802.11n signals using cross-correlation.
%
% This function replaces the script_create_interim_data.m script. It takes input parameters and
% configuration structures, processes the data, and saves the interim results.
%
% USAGE:
%   createInterimData(inDataPath, fileList, cfgInterim, cfg80211)
%
% INPUT PARAMETERS:
%   inDataPath : Path to the input data directory.
%   fileList   : List of dataset indices or -1 for all datasets.
%   cfgInterim : Configuration structure from setupInterimSettings (Interim settings).
%   cfg80211   : Configuration structure from setupInterimSettings (802.11 settings).
%
% NOTES:
%   This function uses external dependencies (readTxData, readRxData, etc.) and expects them
%   to be on the MATLAB path.


function create_interim_data(inDataPath, fileList, cfgInterim, cfg80211, repoPath)

  %% Settings and Configuration
  [jsonPath, dataType, ...
  cfgHT, infoWlanFieldMulti, clkRate, fftDcIdx, prunedDFTMat, prunedIDFTMat, ...
  jsonData, datasetsToProcess, tOffRxNonHT] = setupConfiguration(inDataPath, fileList, cfg80211, repoPath);

  numDatasets = numel(datasetsToProcess);

  for iDataset = datasetsToProcess
    %% Setup for this dataset
    [expFnameBase, expJsonDataFile, timestamps, freq, nFrames] = setupDataset(jsonPath, repoPath, iDataset, cfgInterim);

    % Calculate and display timestamp statistics
    timestamps = (timestamps - timestamps(1)) / clkRate;
    fprintf('\nTimestamp Statistics:\n-------------------\n');
    calculateTimestampStatistics(timestamps);

    % Initialize data structure
    dataStruct = initializeDataStruct(timestamps, freq, nFrames, infoWlanFieldMulti);

    %% Process frames in chunks
    iFrame = 0;
    iChunk = 0;
    cntClippedFrames = 0;

    fprintf('\nProcessing frames:\n');
    while iFrame < nFrames
      iChunk = iChunk + 1;

      [txDataStruct, rxDataStruct] = loadChunkData(expFnameBase, dataType, cfgInterim, iChunk);

      % If reference TX is enabled
      if cfgInterim.getRefTx && iChunk == 1
        txIqArray = txIqDataRef;
      else
        txIqArray = txDataStruct.txIqArray;
      end

      [dataStruct, iFrame, cntClippedFrames] = processChunk(iFrame, nFrames, ...
        dataStruct, txIqArray, rxDataStruct, cfgInterim, infoWlanFieldMulti, ...
        prunedDFTMat, tOffRxNonHT, cntClippedFrames);
    end

    % Post-processing (CSI filtering)
    if cfg80211.csiFiltSize > 1
      fprintf('\nApplying CSI filtering...\n');
      dataStruct = applyCsiFiltering(dataStruct, nFrames, infoWlanFieldMulti, cfg80211, prunedIDFTMat);
    end

    % Save results
    fileNameBase = strrep(expJsonDataFile.fname_base, 'raw', 'interim');
    fileName     = strcat(repoPath, '/', fileNameBase, '_interim.mat');

    % Strip fileNameBase of the last part after /
    [dirPath, ~, ~] = fileparts(fileNameBase);
    outDataPath  = strcat(repoPath, dirPath);

    % Ensure the folder exists
    if ~exist(outDataPath, 'dir')
      mkdir(outDataPath);
    end

    save(fileName, 'dataStruct', 'cfgInterim', 'cfg80211', 'cfgHT', 'infoWlanFieldMulti', '-v7.3');
    createInterimLogFile(repoPath, expJsonDataFile, fileNameBase);
  end
end


%% Subfunctions
%===============================================================================

% setupConfiguration - Initializes paths, configurations, and FFT parameters.
%
% This subfunction sets up the initial configuration including repository paths, loading
% JSON database info, setting up WLAN configurations, and creating the DFT matrices.
%
% USAGE:
%   [repoPath, jsonPath, dataType, outDataPath, cfgHT, infoWlanFieldMulti, clkRate, fftDcIdx, ...
%    prunedDFTMat, prunedIDFTMat, jsonData, datasetsToProcess, tOffRxNonHT] =
%       setupConfiguration(inDataPath, fileList, cfg80211)
%
% INPUT PARAMETERS:
%   inDataPath : The input data path (string)
%   fileList   : List of dataset indices or -1 for all
%   cfg80211   : Configuration structure for 802.11 parameters (contains offsets, etc.)
%
% OUTPUT PARAMETERS:
%   repoPath, jsonPath, dataType, outDataPath : Paths and data type strings
%   cfgHT                   : WLAN HT configuration object
%   infoWlanFieldMulti      : Structure with subcarrier mapping info
%   clkRate                 : Clock rate for timestamps
%   fftDcIdx                : DC index of the FFT
%   prunedDFTMat,prunedIDFTMat : DFT/IDFT matrices for CSI/CIR processing
%   jsonData                : Loaded JSON database structure
%   datasetsToProcess       : List of datasets to process
%   tOffRxNonHT             : Reference offset (if fixed offsets are used)
%
function [jsonPath, dataType, ...
          cfgHT, infoWlanFieldMulti, clkRate, fftDcIdx, prunedDFTMat, prunedIDFTMat, ...
          jsonData, datasetsToProcess, tOffRxNonHT] = setupConfiguration(inDataPath, fileList, cfg80211, repoPath)

  jsonPath = strcat(repoPath, inDataPath);
  dataType = getDataTypeFromPath(inDataPath);

  cfgHT = wlanHTConfig;
  cfgHT.ChannelBandwidth    = 'CBW20';
  cfgHT.NumTransmitAntennas = 1;
  cfgHT.NumSpaceTimeStreams = 1;
  cfgHT.RecommendSmoothing  = false;

  infoWlanFieldMulti.htltfOFDM = getSubcarrierMapping("HT-LTF", cfgHT);
  infoWlanFieldMulti.lltfOFDM  = getSubcarrierMapping("L-LTF", cfgHT);

  clkRate  = 100e6;
  fftDcIdx = getFftDcIdx(infoWlanFieldMulti.htltfOFDM.FFTLength);

  prunedDFTMat  = getPrunedDFTMatrix(infoWlanFieldMulti.htltfOFDM.FFTLength, infoWlanFieldMulti.htltfOFDM.ActiveFFTIndices, fftDcIdx);
  prunedIDFTMat = pinv(prunedDFTMat);

  jsonFilePath = fullfile(jsonPath, 'database.json');
  jsonData     = readJsonFile(jsonFilePath);
  datasetKeys  = fieldnames(jsonData);
  numDatasets  = numel(datasetKeys);

  if isequal(fileList, -1)
    datasetsToProcess = 1:numDatasets;
  else
    datasetsToProcess = fileList;
  end

  if cfg80211.useFixedOffsets
    tOffRxNonHT = cfg80211.refOffRx;
  else
    tOffRxNonHT = [];
  end
end


% setupDataset - Prepares a single dataset for processing by reading its metadata, timestamps, and frequency data.
%
% USAGE:
%   [expFnameBase, expJsonDataFile, timestamps, freq, nFrames] = setupDataset(jsonPath, repoPath, iDataset, cfgInterim)
%
% INPUT PARAMETERS:
%   jsonPath   : Path to the JSON database
%   repoPath   : Path to the repository
%   iDataset   : Index of the dataset to process
%   cfgInterim : Configuration structure for interim processing
%
% OUTPUT PARAMETERS:
%   expFnameBase   : Full base filename for the experiment
%   expJsonDataFile: JSON data structure with metadata for the experiment
%   timestamps      : Vector of timestamps for all frames
%   freq            : Frequency vector associated with the recorded signals
%   nFrames         : Number of frames in the dataset
%
function [expFnameBase, expJsonDataFile, timestamps, freq, nFrames] = setupDataset(jsonPath, repoPath, iDataset, cfgInterim)
  [expFnameBase, expJsonDataFile] = readJsonDatabase(jsonPath, iDataset);
  expFnameBase = strcat(repoPath, '/', expFnameBase);

  disp(['Processing dataset: ', expFnameBase]);

  timestamps = readTimestamps(expFnameBase, cfgInterim.loadHDF5, cfgInterim.verbose);
  freq       = readFreq(expFnameBase, cfgInterim.loadHDF5, cfgInterim.verbose);
  nFrames    = length(timestamps);
end


% initializeDataStruct - Initializes the data structure for storing CSI and CIR data.
%
% USAGE:
%   dataStruct = initializeDataStruct(timestamps, freq, nFrames, infoWlanFieldMulti)
%
% INPUT PARAMETERS:
%   timestamps        : Vector of timestamps for each frame
%   freq              : Frequency vector for the experiment
%   nFrames           : Number of frames
%   infoWlanFieldMulti: Structure containing OFDM field mapping info
%
% OUTPUT PARAMETERS:
%   dataStruct : A structure with preallocated arrays for timestamps, freq, csiArray, and cirArray.
%
function dataStruct = initializeDataStruct(timestamps, freq, nFrames, infoWlanFieldMulti)
  nRxAnt = 1; % Will be adapted later if multiple antennas are present
  dataStruct.timestamps = timestamps;
  dataStruct.freq       = freq;
  dataStruct.csiArray   = zeros(nFrames, nRxAnt, 1, infoWlanFieldMulti.htltfOFDM.NumTones, 'like', 1j);
  dataStruct.cirArray   = zeros(nFrames, nRxAnt, 1, infoWlanFieldMulti.htltfOFDM.FFTLength, 'like', 1j);
end


% loadChunkData - Loads TX and RX data for a given chunk.
%
% USAGE:
%   [txDataStruct, rxDataStruct] = loadChunkData(expFnameBase, dataType, cfgInterim, iChunk)
%
% INPUT PARAMETERS:
%   expFnameBase : Base filename for the experiment
%   dataType     : Type of RX data (e.g., 'tx_rx_iq0')
%   cfgInterim   : Configuration structure (contains loadHDF5, verbose)
%   iChunk       : Chunk number to load
%
% OUTPUT PARAMETERS:
%   txDataStruct : Structure containing the loaded TX IQ data
%   rxDataStruct : Structure containing the loaded RX IQ data
%
function [txDataStruct, rxDataStruct] = loadChunkData(expFnameBase, dataType, cfgInterim, iChunk)
  txDataStruct = readTxData(expFnameBase, cfgInterim.loadHDF5, cfgInterim.verbose, iChunk);
  rxDataStruct = readRxData(expFnameBase, dataType, cfgInterim.loadHDF5, cfgInterim.verbose, iChunk);
end


% processChunk - Processes a single chunk of frames, computing CSI and handling diagnostics.
%
% This function iterates through frames in the loaded chunk, computes CSI using cross-correlation,
% checks for clipping, and stores results in dataStruct.
%
% USAGE:
%   [dataStruct, iFrame, cntClippedFrames] = processChunk(iFrame, nFrames, dataStruct, txIqArray, rxDataStruct, cfgInterim, infoWlanFieldMulti, prunedDFTMat, tOffRxNonHT, cntClippedFrames)
%
% INPUT PARAMETERS:
%   iFrame             : Current frame index (will be updated)
%   nFrames            : Total number of frames
%   dataStruct         : Data structure holding results
%   txIqArray          : TX IQ data array
%   rxDataStruct       : RX data structure for the current chunk
%   cfgInterim         : Configuration structure (contains adcBw, verbose, etc.)
%   infoWlanFieldMulti : Structure with OFDM field info
%   prunedDFTMat       : Pruned DFT matrix for CSI computation
%   tOffRxNonHT        : Reference offset if fixed offsets are used, otherwise empty
%   cntClippedFrames   : Counter for clipped frames, will be updated
%
% OUTPUT PARAMETERS:
%   dataStruct       : Updated data structure with CSI/CIR results
%   iFrame           : Updated frame index after processing this chunk
%   cntClippedFrames : Updated count of clipped frames
%
function [dataStruct, iFrame, cntClippedFrames] = processChunk(iFrame, nFrames, dataStruct, txIqArray, rxDataStruct, cfgInterim, infoWlanFieldMulti, prunedDFTMat, tOffRxNonHT, cntClippedFrames)

  nFramesInChunk = size(rxDataStruct.rxIqArray, 1);
  nRxAnt         = size(rxDataStruct.rxIqArray, 2);

  % Adjust dataStruct if antenna count differs
  if size(dataStruct.csiArray, 2) ~= nRxAnt
    dataStruct.csiArray = zeros(nFrames, nRxAnt, 1, infoWlanFieldMulti.htltfOFDM.NumTones, 'like', 1j);
    dataStruct.cirArray = zeros(nFrames, nRxAnt, 1, infoWlanFieldMulti.htltfOFDM.FFTLength, 'like', 1j);
  end

  iFrameChunk = 0;
  while iFrameChunk < nFramesInChunk
    iFrameChunk = iFrameChunk + 1;
    iFrame      = iFrame + 1;

    if mod(iFrame, 100) == 0 && cfgInterim.verbose
      fprintf('Processing frame %d/%d\n', iFrame, nFrames);
    end

    tx0IqData = getTxDataArray(txIqArray, iFrameChunk, cfgInterim);

    for iRxAnt = 1:nRxAnt
      rxIqData = reshape(rxDataStruct.rxIqArray(iFrameChunk, iRxAnt, :), [], 1);

      % Check for clipping
      rxMagnitude     = abs(rxIqData);
      clippedSamples  = sum(rxMagnitude >= 2^(cfgInterim.adcBw-1)-1);
      if clippedSamples > 0
        cntClippedFrames = cntClippedFrames + 1;
        if cntClippedFrames <= cfgInterim.clippingMaxWarnings
          warning('Frame %d, Antenna %d: %d samples clipped', iFrame, iRxAnt, clippedSamples);
        end
      end

      % Compute CIR and CSI
      cirArray = computeCirCorr(tx0IqData, rxIqData, tOffRxNonHT, infoWlanFieldMulti.htltfOFDM.FFTLength);
      csiArray = prunedDFTMat * cirArray;

      % Store results
      dataStruct.cirArray(iFrame, iRxAnt, 1, :) = cirArray;
      dataStruct.csiArray(iFrame, iRxAnt, 1, :) = csiArray;
    end
  end
end


% getTxDataArray - Extracts the appropriate TX IQ data vector for a given frame.
%
% Depending on whether reference TX data is used or if the TX data is vectorized or
% multi-dimensional, this function ensures we have a proper vector form for tx0IqData.
%
% USAGE:
%   tx0IqData = getTxDataArray(txIqArray, iFrameChunk, cfgInterim)
%
% INPUT PARAMETERS:
%   txIqArray   : The TX IQ data array (could be vector or 2D)
%   iFrameChunk : The current frame index within the chunk
%   cfgInterim  : Configuration structure (contains getRefTx flag)
%
% OUTPUT PARAMETERS:
%   tx0IqData : Vectorized TX IQ data for the given frame
%
function tx0IqData = getTxDataArray(txIqArray, iFrameChunk, cfgInterim)
  if cfgInterim.getRefTx
    tx0IqData = txIqDataRef; % Provided externally
  else
    if isvector(squeeze(txIqArray))
      tx0IqData = reshape(txIqArray, [], 1);
    else
      tx0IqData = reshape(txIqArray(iFrameChunk, :, :), [], 1);
    end
  end
end


% applyCsiFiltering - Applies optional CSI filtering and updates CIR accordingly.
%
% If configured, this function applies a filter (via filterCSI) to the CSI data
% and updates CIR by performing an inverse DFT using prunedIDFTMat.
%
% USAGE:
%   dataStruct = applyCsiFiltering(dataStruct, nFrames, infoWlanFieldMulti, cfg80211, prunedIDFTMat)
%
% INPUT PARAMETERS:
%   dataStruct       : Data structure with csiArray and cirArray
%   nFrames          : Number of frames
%   infoWlanFieldMulti : Structure with OFDM field info
%   cfg80211         : Configuration structure (contains csiFiltSize)
%   prunedIDFTMat    : Inverse DFT matrix to convert CSI back to CIR
%
% OUTPUT PARAMETERS:
%   dataStruct : Updated dataStruct with filtered CSI and updated CIR.
%
function dataStruct = applyCsiFiltering(dataStruct, nFrames, infoWlanFieldMulti, cfg80211, prunedIDFTMat)
  nRxAnt = size(dataStruct.csiArray, 2);
  for iRxAnt = 1:nRxAnt
    csi = squeeze(dataStruct.csiArray(:, iRxAnt, 1, :));
    dataStruct.csiArray(:, iRxAnt, 1, :) = filterCSI(csi, infoWlanFieldMulti.htltfOFDM, cfg80211.csiFiltSize);
    dataStruct.cirArray(:, iRxAnt, 1, :) = squeeze(dataStruct.csiArray(:, iRxAnt, 1, :)) * transpose(prunedIDFTMat);
  end
end


% calculateTimestampStatistics - Computes and displays basic statistics about timestamp intervals.
%
% This function takes a vector of timestamps, computes the differences between
% consecutive timestamps to determine frame intervals, and calculates statistics
% on these intervals. It prints out the minimum, maximum, mean, and median intervals
% in both seconds and milliseconds, as well as the corresponding frame rates.
%
% USAGE:
%   calculateTimestampStatistics(timestamps)
%
% INPUT PARAMETERS:
%   timestamps : A vector of timestamps (in seconds) from which to compute the
%                interval statistics. The timestamps are assumed to be
%                monotonically increasing.
%
% OUTPUT PARAMETERS:
%   None. The function prints the computed statistics to the console.
%
function calculateTimestampStatistics(timestamps)
  timeDifferences = diff(timestamps);

  minDiffSec     = min(timeDifferences);
  maxDiffSec     = max(timeDifferences);
  meanDiffSec    = mean(timeDifferences);
  medianDiffSec  = median(timeDifferences);

  minDiffMs      = minDiffSec * 1e3;
  maxDiffMs      = maxDiffSec * 1e3;
  meanDiffMs     = meanDiffSec * 1e3;
  medianDiffMs   = medianDiffSec * 1e3;

  rateMin    = 1 / maxDiffSec;
  rateMax    = 1 / minDiffSec;
  rateMean   = 1 / meanDiffSec;
  rateMedian = 1 / medianDiffSec;

  fprintf('Minimum difference:  %.3f seconds (%.3f ms)\n', minDiffSec, minDiffMs);
  fprintf('Maximum difference:  %.3f seconds (%.3f ms)\n', maxDiffSec, maxDiffMs);
  fprintf('Mean difference:     %.3f seconds (%.3f ms)\n', meanDiffSec, meanDiffMs);
  fprintf('Median difference:   %.3f seconds (%.3f ms)\n', medianDiffSec, medianDiffMs);
  fprintf('Rates: Min=%.2f Hz, Max=%.2f Hz, Mean=%.2f Hz, Median=%.2f Hz\n', ...
          rateMin, rateMax, rateMean, rateMedian);
end
