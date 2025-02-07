% script_process_dataset_demo.m
%
% This script sets up and processes datasets.
clear all
close all;
clc;
% dbclear all;  % Remove all breakpoints
rehash;       % Ensure MATLAB updates functions
clear functions;

%% Settings
%------------------------------------------------------------------------------

% Default input path
defaultInDataPath = 'data/raw/test/zed_fmcs2/tx_rx_iq0/air/';
repoPath          = '../';

% Dataset and file list definitions
datasets = {
  'respiration_test', 2
};

function [signalOut, timestampsOut] = apply_resample(signalIn, timestampsIn, fResample, movMedianSize, movMeanSize, timeCutResampleSec)
  % apply_resample applies median filtering, resampling, edge trimming, and mean filtering.
  %
  % Args:
  %   signalIn (matrix): Input signal, time in dimension 1
  %   timestampsIn (vector): Time array
  %   fResample (double): Resampling frequency (Hz)
  %   movMedianSize (integer): Window size for moving median
  %   movMeanSize (integer): Window size for moving mean
  %   timeCutResampleSec (double): Duration to cut at resampled edges
  %
  % Returns:
  %   signal (matrix): Filtered signal
  %   timestampsOut (vector): Updated time after resampling and trimming

  % First apply movmedian
  sigMed = movmedian(signalIn, movMedianSize, 1);

  % Resample the data
  [sigResamp, tResamp] = resample(sigMed, timestampsIn, fResample);

  % Cut the edges to remove ringing effects
  subs = {[], ':', ':', ':', ':', ':'};
  subs{1} = find(tResamp >= tResamp(1) + timeCutResampleSec & tResamp <= tResamp(end) - timeCutResampleSec);

  % % Apply the cuts
  sigResamp = sigResamp(subs{:});
  tResamp   = tResamp(subs{1});

  %Finally apply movmean
  signalOut     = movmean(sigResamp, movMeanSize);
  timestampsOut = tResamp - tResamp(1);

  %  signalOut     = sigResamp;
  % timestampsOut = tResamp;


end





% Resampling parameters
fResample = 60;        % Target resampling frequency in Hz
movMedianSize = 3;      % Window size for moving median filter
movMeanSize = 3;        % Window size for moving mean filter
timeCutResampleSec = 1; % Time to cut from edges after resampling

%% Process each dataset
for datasetIndex = 1:size(datasets, 1)
    datasetName = datasets{datasetIndex, 1};
    fileList    = datasets{datasetIndex, 2};
    inDataPath  = [defaultInDataPath, datasetName];
    [cfgInterim, cfg80211] = setup_interim_settings();

    fprintf('Processing dataset: %s with file list: %s\n', datasetName, mat2str(fileList));
    
    % Load and preprocess data (custom function)
    x = create_interim_data(inDataPath, fileList, cfgInterim, cfg80211, repoPath);

    % Extract CIR and timestamps
    cirArray = squeeze(x.cirArray);   % Remove singleton dimensions if needed
    timestamps = x.timestamps;       % Corresponding time array for CIR

    % Select main delay bins (first 10 bins as an example)
    selectedDelayBins = cirArray(:, 1:10);
    numBins = 10; 
    combinedSpectrumDensity = zeros(255, 1); 
    spectrum_density_matrix = []; % To store PSD values for each column
    freq_combined_matrix = [];

    for binIndex = 1:numBins
            % Resample the current delay bin`
            [resampledSignal, resampledTimestamps] = apply_resample(selectedDelayBins(:, binIndex), ...
                                                                    timestamps, ...
                                                                    fResample, ...
                                                                    movMedianSize, ...
                                                                    movMeanSize, ...
                                                                    timeCutResampleSec);
    
            % Compute spectrum for the resampled signal
            [spectrumDensity, freqCombined] = spectrum_psd(resampledSignal, fResample);
            freqCombined = freqCombined * 60;
            combinedSpectrumDensity = combinedSpectrumDensity + spectrumDensity;
    
            spectrum_density_matrix(:, binIndex) = spectrumDensity; % Each column corresponds to a signal's PSD
            freq_combined_matrix(:, binIndex) = freqCombined; % Each column corresponds to frequency values in BPM
    end
 
    combinedSpectrumDensity = combinedSpectrumDensity / numBins;
%     % Normalize combined spectrum density
    combinedSpectrumDensity = combinedSpectrumDensity / max(combinedSpectrumDensity); % Normalize to max value
        
    plot(freq_combined_matrix, pow2db(abs(combinedSpectrumDensity)));
    xlim([0 300]);
    % Plot the PSD for each column (optional)
    figure;
    hold on;
    numColumns = 10;
    for col = 1:numColumns
        plot(freq_combined_matrix(:, 1), mag2db(spectrum_density_matrix(:, col)));
    end
    xlim([0 60]);
    hold off;
    xlabel('Frequency (BPM)');
    ylabel('Power/Frequency (dB/Hz)');
    title('Power Spectral Density for Each Column');
    % legend(arrayfun(@(x) sprintf('Column %d', x), 1:numColumns, 'UniformOutput', false));


end








% 
% 
% 
% 
% 
% 
% 
% % TEST 2
% 
% % Resampling parameters
% fResample = 120;        % Target resampling frequency in Hz
% movMedianSize = 5;      % Window size for moving median filter1024
% movMeanSize = 5;        % Window size for moving mean filter
% timeCutResampleSec = 1; % Time to cut from edges after resampling
% 
% %% Process each dataset
% for datasetIndex = 1:size(datasets, 1)
%     datasetName = datasets{datasetIndex, 1};
%     fileList    = datasets{datasetIndex, 2};
%     inDataPath  = [defaultInDataPath, datasetName];
% 
%     fprintf('Processing dataset: %s with file list: %s\n', datasetName, mat2str(fileList));
% 
%     % Load and preprocess data (custom function)
%     x = create_interim_data(inDataPath, fileList, cfgInterim, cfg80211, repoPath);
% 
%     % Extract CIR and timestamps
%     cirArray = squeeze(x.cirArray);   % Remove singleton dimensions if needed
%     timestamps = x.timestamps;       % Corresponding time array for CIR
% 
%     % Select main delay bins (first 10 bins as an example)
%     selectedDelayBins = cirArray(:, 4:6);
% 
%     %% Resample each delay bin and compute spectrum
%     numBins = 3; % Number of delay bins (columns)
%     combinedSpectrumDensity = zeros(511, 1); % Accumulate PSD across bins
% 
%     % in the loop save the spectrum of each bin separately
% 
%     for binIndex = 1:numBins
%         % Resample the current delay bin`
%         [resampledSignal, resampledTimestamps] = apply_resample(selectedDelayBins(:, binIndex), ...
%                                                                 timestamps, ...
%                                                                 fResample, ...
%                                                                 movMedianSize, ...
%                                                                 movMeanSize, ...
%                                                                 timeCutResampleSec);
% 
%         % Compute spectrum for the resampled signal
%         [spectrumDensity, freqCombined] = spectrum_psd(resampledSignal, fResample);
% 
%         % Accumulate spectrum density (sum or average across bins)
%         combinedSpectrumDensity = combinedSpectrumDensity + spectrumDensity;
%     end
% 
%     % Average the spectrum density across all bins (optional)
%     combinedSpectrumDensity = combinedSpectrumDensity / numBins;
%     % Normalize combined spectrum density
%     combinedSpectrumDensity = combinedSpectrumDensity / max(combinedSpectrumDensity); % Normalize to max value
% 
%     %% Convert frequency to BPM and plot spectrum density in dB
%     freqCombinedBPM = freqCombined * 60; % Convert frequency to BPM
% 
%     figure;
%     plot(freqCombinedBPM, mag2db(abs(combinedSpectrumDensity))); % Convert power to dB scale
%     xlabel('Frequency (BPM)');
%     ylabel('Power/Frequency (dB/Hz)');
%     title(sprintf('Combined Spectrum Density for Dataset: %s', datasetName));
%     xlim([0 120])
%     grid on;
% 
%     fprintf('Finished processing dataset: %s\n\n', datasetName);
% end
% 
% 
% % END OF TEST 2
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% 
% %GHOLAMREZA'S CODE

% % Loop through all datasets
% for datasetIndex = 1:size(datasets, 1)
%   datasetName = datasets{datasetIndex, 1};
%   fileList    = datasets{datasetIndex, 2};
%   inDataPath  = [defaultInDataPath, datasetName];
% 
%   fprintf('Processing dataset: %s with file list: %s\n', datasetName, mat2str(fileList));
%   [cfgInterim, cfg80211] = setup_interim_settings();
% 
%   % Here, you can overwrite defaults from setup_interim_settings() if needed
% 
%   x = create_interim_data(inDataPath, fileList, cfgInterim, cfg80211, repoPath);
%   % resampled = resample(squeeze(x.cirArray),x.timestamps)
%   Intermediate_Signal=squeeze(x.cirArray);
%   Selected_Delay_Bins=Intermediate_Signal(:,1:10);
% 
%   %[resampled_signal, resampled_timestamp] = apply_resample(x.cirArray,x.timestamps,120,2,2,1);
%   [resampled_signal, resampled_timestamp] = apply_resample(Selected_Delay_Bins,x.timestamps,120,2,2,1);
% 
% 
%   %resampled_signal=resampled_signal./max(max(abs(resampled_signal))); % just for temporary normalization
%   % resampled_truncated = resampled(:,1:11);
%   %[spectrum_density,freq_combined] = spectrum_psd(resampled_signal(:,1),120);
%   [spectrum_density,freq_combined] = spectrum_psd(resampled_signal(1,:), 120);%, 'nfft', 2048, 'fMax', 400);
% 
%   %spectrum_density=spectrum_density/max(spectrum_density);
%   freq_combined= freq_combined *60;
%     % freq_combined = 10*log(10)*freq_combined;
%   plot(freq_combined, mag2db(spectrum_density))
%   %xlim([0 60])
%   % test_bpm= test *60;
%   % test_db= 10 *log(10)*(test1);
%   fprintf('Finished processing dataset: %s\n\n', datasetName);
%  end
