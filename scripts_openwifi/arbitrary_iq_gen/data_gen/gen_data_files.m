% gen_data_files - Configuration and Data Generation for IEEE 802.11n WLAN Frames
%
% This script configures WLAN high throughput (HT) settings for 802.11n,
% generates frames, and calculates key metrics such as PAPR (Peak-to-Average
% Power Ratio). It also quantizes and saves these frames to files.
%
% USAGE
%   Run the script to configure WLAN HT settings, generate frames, and save data.
%
% OUTPUT FILES
%   Saved to the `output` directory:
%     - Real and imaginary frame data in text files
%     - Binary files for further SDR processing
%
% DEPENDENCIES
%   MATLAB WLAN System Toolbox (for `wlanHTConfig`, `wlanWaveformGenerator`, etc.)
%
% Created by [Your Name], [Date]

close all;
clear all;
rng("default");

%===============================================================================
% Configuration Parameters
%===============================================================================

cfgHT = wlanHTConfig;
cfgHT.ChannelBandwidth    = 'CBW20';
cfgHT.NumTransmitAntennas = 1;
cfgHT.NumSpaceTimeStreams = 1;
cfgHT.MCS                 = 0;  % Range: 0 to 31
cfgHT.GuardInterval       = 'Long';
cfgHT.ChannelCoding       = 'BCC';
cfgHT.PSDULength          = 127;
cfgHT.AggregatedMPDU      = false;
cfgHT.RecommendSmoothing  = false;

% Sample rate and subcarrier spacing
fs        = 20e6;       % Sample rate of 20 MHz
scSpacing = 312.5e3;    % Subcarrier spacing

% DAC and digital gain settings
% Note: Using packet injection with a digital gain of 256 (a 2x multiplier)
% results in maximum real and imaginary values near -24576. Scaling at ~14.6
% (bitwidth 15.5) brings values close to this range.
bitwidth = 15.5; % DAC bitwidth is 12, but data path is 16, so values should fall between 12 and 16 bits.

% Display Configuration Info
cfgHTIssuesTable     = validateConfig(cfgHT, 'MCS');
wlanFrameDurationSec = cfgHT.transmitTime;
wlanFrameSamples     = round(wlanSampleRate(cfgHT) * wlanFrameDurationSec);
ind = wlanFieldIndices(cfgHT);

fprintf('Transmit time [s]: %d\n', wlanFrameDurationSec);
fprintf('Transmit time [ms]: %.4f\n', wlanFrameDurationSec * 1e3);
fprintf('Transmit time [us]: %.4f\n', wlanFrameDurationSec * 1e6);
fprintf('N samples: %d\n', wlanFrameSamples);
fprintf('N Data OFDM symbols: %d\n', round(cfgHTIssuesTable.NumDataSymbols));

numDataSymbols = calculate_num_data_symbols(ind);
fprintf('N Data OFDM symbols: %d\n', numDataSymbols);

%===============================================================================
% Generate Frames with Minimum and Maximum PAPR
%===============================================================================

numSeeds = 50;
[lowestPAPRFrame, highestPAPRFrame] = find_best_and_worst_papr_frames(cfgHT, numSeeds);
wlanFrameFull = lowestPAPRFrame;

% File names
TX_IQ0_REAL = 'tx_iq0_real.csv';
TX_IQ0_IMAG = 'tx_iq0_imag.csv';

% Extract fields
[lstf, lltf, lsig, htsig, htstf, htltf, nonHtpreamble, htPreamble] = extractFields(cfgHT);

% Base names
lstf_basename          = ['lstf_' num2str(length(lstf))];
lltf_basename          = ['lltf_' num2str(length(lstf) + length(lltf))];
nonHtpreamble_basename = ['nonHtpreamble_' num2str(length(nonHtpreamble))];
htPreamble_basename    = ['htPreamble_' num2str(length(htPreamble))];
wlanFrameFull_basename = ['wlanFrameFull_' num2str(length(wlanFrameFull))];

quantize_and_write_frame(lstf, bitwidth, lstf_basename, TX_IQ0_REAL, TX_IQ0_IMAG);
quantize_and_write_frame([lstf; lltf], bitwidth, lltf_basename, TX_IQ0_REAL, TX_IQ0_IMAG);
quantize_and_write_frame(nonHtpreamble, bitwidth, nonHtpreamble_basename, TX_IQ0_REAL, TX_IQ0_IMAG);
quantize_and_write_frame(htPreamble, bitwidth, htPreamble_basename, TX_IQ0_REAL, TX_IQ0_IMAG);
wlanFrameFullScalingFactor = quantize_and_write_frame(wlanFrameFull, bitwidth, wlanFrameFull_basename, TX_IQ0_REAL, TX_IQ0_IMAG);

%===============================================================================
% Write Frame Data with Different Bitwidths
%===============================================================================

bitwidths = [14.5 15 15.5 16 16.5 17];
for bw = bitwidths
  quantize_and_write_frame(wlanFrameFull, bw, wlanFrameFull_basename, TX_IQ0_REAL, TX_IQ0_IMAG);
end

%===============================================================================
% Generate and Write Random Data Frames
%===============================================================================

for i = 1:100
  rng(i);  % Set seed for reproducibility
  newseed = randi([0 2^31-1]);
  rng(newseed);

  psdu = randi([0 1], 8 * cfgHT.PSDULength, 1); % Generate random PSDU data
  randomFrame = wlanWaveformGenerator(psdu, cfgHT);

  randomFrame_basename = ['randomFrame_' num2str(i) '_' num2str(length(randomFrame))];
  quantize_and_write_frame(randomFrame, bitwidth, randomFrame_basename, TX_IQ0_REAL, TX_IQ0_IMAG, wlanFrameFullScalingFactor);
end

%===============================================================================
% Generate Frames with Different PSDULengths
%===============================================================================

numSymbolsToRemove = ceil((length(wlanFrameFull) - ind.HTLTF(2)) / 80);
wlanFrameFullCurrent = wlanFrameFull;

for i = 5:5:numSymbolsToRemove
  targetNumSymbols = numDataSymbols - i;
  cfgHT.PSDULength = find_optimal_psdu(cfgHT, targetNumSymbols);

  % Find frame with lowest PAPR for current PSDULength
  [lowestPAPRFrame, ~, ~, ~] = find_best_and_worst_papr_frames(cfgHT, numSeeds);

  wlanFrameFullShort_basename = ['wlanFrameFull_' num2str(length(lowestPAPRFrame))];
  quantize_and_write_frame(lowestPAPRFrame, bitwidth, wlanFrameFullShort_basename, TX_IQ0_REAL, TX_IQ0_IMAG);
end

fprintf('Quantization and saving for all frame lengths completed.\n');

%===============================================================================
% Functions
%===============================================================================

% quantize_and_write_frame: Quantizes a frame and writes real and imaginary parts to files.
%
% USAGE
%   scalingFactor = quantize_and_write_frame(frame, bitwidth, basename, TX_IQ0_REAL, TX_IQ0_IMAG)
%
% INPUT PARAMETERS
%   frame         : Complex frame to be quantized.
%   bitwidth      : Bitwidth for quantization.
%   basename      : Base filename for output files.
%   TX_IQ0_REAL   : Real component filename suffix.
%   TX_IQ0_IMAG   : Imaginary component filename suffix.
%   scalingFactor : (Optional) scaling factor for frame.
%
% OUTPUT PARAMETERS
%   scalingFactor : Scaling factor applied during quantization.
%
function [scalingFactor] = quantize_and_write_frame(frame, bitwidth, basename, TX_IQ0_REAL, TX_IQ0_IMAG, scalingFactor)
  if nargin < 6 || isempty(scalingFactor)
    scalingFactor = [];
  end

  [frameRe, frameIm, scalingFactor] = quantizer(frame, bitwidth, scalingFactor);
  write_frame(frameRe + 1j * frameIm, bitwidth, basename, TX_IQ0_REAL, TX_IQ0_IMAG);
end

% write_frame: Writes real and imaginary components of a frame to files.
%
% USAGE
%   write_frame(frame, bitwidth, basename, TX_IQ0_REAL, TX_IQ0_IMAG)
%
% INPUT PARAMETERS
%   frame       : Quantized complex frame.
%   bitwidth    : Bitwidth of quantized data.
%   basename    : Base filename for saving output files.
%   TX_IQ0_REAL : Real component filename suffix.
%   TX_IQ0_IMAG : Imaginary component filename suffix.
%
function write_frame(frame, bitwidth, basename, TX_IQ0_REAL, TX_IQ0_IMAG)
  outputFolder = 'output';
  if ~exist(outputFolder, 'dir')
    mkdir(outputFolder)
  end

  basename = fullfile(outputFolder, [basename, '_', strrep(num2str(bitwidth), '.', 'p')]);

  writematrix(real(frame), strcat(basename, '_', TX_IQ0_REAL), 'Delimiter', 'space');
  writematrix(imag(frame), strcat(basename, '_', TX_IQ0_IMAG), 'Delimiter', 'space');

  write_complex_data_to_file(frame, basename);
end

% find_optimal_psdu: Finds the optimal PSDULength to achieve the desired number of OFDM data symbols.
%
% USAGE
%   optimalPSDU = find_optimal_psdu(cfgHT, targetNumSymbols)
%
% INPUT PARAMETERS
%   cfgHT            : WLAN HT configuration.
%   targetNumSymbols : Target number of OFDM data symbols.
%
% OUTPUT PARAMETERS
%   optimalPSDU : Optimal PSDULength to meet the target symbol count.
%
function optimalPSDU = find_optimal_psdu(cfgHT, targetNumSymbols)
  found = false;
  while ~found
    for psduLen = 0:10000
      cfgHT.PSDULength = psduLen;
      ind            = wlanFieldIndices(cfgHT);
      numDataSymbols = calculate_num_data_symbols(ind);

      if numDataSymbols == targetNumSymbols
        optimalPSDU = psduLen;
        found = true;
        break;
      end
    end

    if ~found
      error('Optimal PSDULength not found within the given range.');
    end
  end
end

% calculate_num_data_symbols: Calculates the number of data symbols for the given configuration.
%
% USAGE
%   numDataSymbols = calculate_num_data_symbols(ind)
%
% INPUT PARAMETERS
%   ind   : Indices of WLAN fields.
%
% OUTPUT PARAMETERS
%   numDataSymbols : Calculated number of data OFDM symbols.
%
function numDataSymbols = calculate_num_data_symbols(ind)
  if isempty(ind.HTData)
    numDataSymbols = 0;
  else
    numDataSymbols = floor((ind.HTData(2) - ind.HTData(1) + 1) / 80);
  end
end
