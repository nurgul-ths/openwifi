% setup_interim_settings - Default settings for simplified CSI processing.
%
% This function provides default configuration settings for the simplified CSI
% processing pipeline. Settings include data loading options, ADC parameters,
% CSI filtering, and sample alignment configurations.
%
% USAGE:
%   [cfgInterim, cfg80211] = setup_interim_settings()
%
% OUTPUT PARAMETERS:
%   cfgInterim : Structure containing interim processing settings:
%                - Data loading (HDF5, verbosity, reference TX)
%                - ADC and clipping detection
%                - Time range parameters
%   cfg80211   : Structure containing 802.11 specific settings:
%                - Sample alignment parameters
%                - CSI filtering options
%
% NOTES:
%   - Adjust hard-coded values as needed for specific processing requirements
%   - Used by script_create_interim_data_simple.m for basic CSI computation
%
function [cfgInterim, cfg80211] = setup_interim_settings()
  %% Data Loading Settings
  cfgInterim.loadHDF5  = true;   % Use HDF5 format for data loading
  cfgInterim.verbose   = false;  % Verbose output during processing
  cfgInterim.getRefTx  = false;  % Use reference TX data

  %% ADC and Clipping Detection Settings
  cfgInterim.adcBw               = 12;   % ADC bit width
  cfgInterim.clippingThreshold   = 5;    % Percentage threshold for clipping warning
  cfgInterim.clippingMaxWarnings = 100;  % Maximum number of clipping warnings

  %% Time Range Settings
  cfgInterim.startTime = 0;    % Start time for processing (seconds)
  cfgInterim.endTime   = -1;   % End time for processing (-1 for all data)

  %% 802.11 Specific Settings
  % Alignment Settings
  cfg80211.refOffTx        = 0;     % TX reference offset
  cfg80211.refOffRx        = 68;    % RX reference offset (affects CIR peak position)
  cfg80211.useFixedOffsets = true;  % Use fixed offsets instead of calculated ones

  % CSI Filtering
  cfg80211.csiFiltSize     = 1;     % Size of CSI domain filtering (1 for no filtering)
 end
