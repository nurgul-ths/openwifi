% script_process_dataset_demo.m
%
% This script sets up and processes datasets.

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
  'respiration_test', 1:3
};

% Loop through all datasets
for datasetIndex = 1:size(datasets, 1)
  datasetName = datasets{datasetIndex, 1};
  fileList    = datasets{datasetIndex, 2};
  inDataPath  = [defaultInDataPath, datasetName];

  fprintf('Processing dataset: %s with file list: %s\n', datasetName, mat2str(fileList));
  [cfgInterim, cfg80211] = setup_interim_settings();

  % Here, you can overwrite defaults from setup_interim_settings() if needed

  create_interim_data(inDataPath, fileList, cfgInterim, cfg80211, repoPath);
  fprintf('Finished processing dataset: %s\n\n', datasetName);
end
