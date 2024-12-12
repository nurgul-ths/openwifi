% getSubcarrierMapping - Compute detailed subcarrier mapping and related parameters for HT configurations
%
% This function uses wlanHTOFDMInfo to obtain core OFDM-related parameters from a given
% HT (High Throughput) configuration object (wlanHTConfig) and field name, and then augments
% the returned information with additional subcarrier mapping, frequency axes, indices, and
% spacing details. It provides a comprehensive set of indices to understand how data, pilot,
% and null subcarriers are laid out in the frequency domain.
%
% USAGE:
%   info = getSubcarrierMapping(fieldname, cfgHT)
%   info = getSubcarrierMapping(fieldname, cfgHT, sampleRate)
%
% INPUT PARAMETERS:
%   fieldname - A string specifying the field to analyze. Common values include:
%               'L-LTF', 'L-SIG', 'HT-SIG', 'HT-LTF', 'HT-Data'.
%   cfgHT     - A wlanHTConfig object specifying the configuration. For example:
%                  cfgHT = wlanHTConfig;
%                  cfgHT.ChannelBandwidth    = 'CBW20';
%                  cfgHT.NumTransmitAntennas = 1;
%                  cfgHT.NumSpaceTimeStreams = 1;
%                  cfgHT.RecommendSmoothing  = false;
%
%               The wlanHTConfig object sets the parameters for an IEEE 802.11 HT PPDU.
%               See "help wlanHTConfig" for more details.
%
%   sampleRate (optional) - A custom sample rate in Hz. If you are using a MATLAB release
%                           where wlanHTOFDMInfo does not return the SampleRate field,
%                           you must specify this parameter. If not provided and the info
%                           struct does not include SampleRate, an error is raised.
%
% OUTPUT PARAMETERS:
%   info - A structure containing extensive information about the OFDM subcarrier layout:
%
%   Fields originally from wlanHTOFDMInfo:
%     FFTLength              - FFT length used by the OFDM system.
%     SampleRate             - Sample rate of the waveform (returned if available, otherwise user must provide).
%     CPLength               - Length of the cyclic prefix.
%     NumTones               - Number of active (used) subcarriers.
%     NumSubchannels         - Number of 20 MHz subchannels aggregated in the configuration.
%     ActiveFrequencyIndices - Indices of active subcarriers relative to DC.
%     ActiveFFTIndices       - 1-based indices of active subcarriers within the FFT [1 ... FFTLength].
%     DataIndices            - 1-based indices (within the active set) of data subcarriers.
%     PilotIndices           - 1-based indices (within the active set) of pilot subcarriers.
%
%   Additional fields added by this function:
%     FreqSpacing            - Frequency spacing between adjacent subcarriers (Hz).
%     CarrierIdx             - DC index (FFTLength/2) used for reference.
%     FrequencyIndices       - A vector of length FFTLength with frequency bin indices in [-NFFT/2 ... NFFT/2-1].
%                              DC is at index 0, negative frequencies before DC, positive after DC.
%     NullFrequencyIndices   - Frequency indices of null subcarriers (those not used by either data or pilots).
%     PilotFrequencyIndices  - Frequency indices (relative to DC) of the pilot subcarriers.
%     DataFrequencyIndices   - Frequency indices (relative to DC) of the data subcarriers.
%     FrequencyAxis          - Frequency axis (Hz) for all subcarriers. Derived from FrequencyIndices * FreqSpacing.
%     ActiveFrequencyAxis    - Frequency axis (Hz) for active subcarriers only.
%     Indices                - A 1-based index vector [1:FFTLength].
%     FFTIndices             - A 1-based vector of active subcarrier indices (data+pilots).
%     NullIndices            - A 1-based vector of null subcarrier indices.
%
% EXAMPLE:
%   cfgHT = wlanHTConfig('ChannelBandwidth','CBW20','NumTransmitAntennas',1,'NumSpaceTimeStreams',1,'RecommendSmoothing',false);
%   info = getSubcarrierMapping('HT-Data', cfgHT);
%
%   This returns a structure `info` with details about subcarrier layouts, frequency indices,
%   data/pilot/null placement, and frequency axes for a 20 MHz HT-Data field.
%
% NOTE:
%   - The mapping is derived from the wlanHTOFDMInfo function, which internally uses the cfgHT settings.
%   - If wlanHTOFDMInfo does not return SampleRate (e.g., in MATLAB releases before R2023a), you must provide
%     the sampleRate argument. If sampleRate is not provided and is not available in info, the function will error.
%
%   The following notes provide known pilot and data subcarrier ranges for standard 20/40/80 MHz bandwidths
%   (purely informational, not used directly here since wlanHTOFDMInfo and cfgHT handle this internally):
%
%   For 20 MHz (NFFT=64):
%     pilotSubcarrierList = [-21, -7, 7, 21];
%     subcarrierRange     = [-28, 28]; % excluding DC
%
%   For 40 MHz (NFFT=128):
%     pilotSubcarrierList = [-53, -25, -11, 11, 25, 53];
%     subcarrierRange     = [-58, 58]; % excluding DC
%
%   For 80 MHz (NFFT=256):
%     pilotSubcarrierList = [-103, -75, -39, -11, 11, 39, 75, 103];
%     subcarrierRange     = [-122, 122]; % excluding DC
%
%   These notes are for reference to understand standard OFDM subcarrier placements used in WLAN standards.
%
% REFERENCES:
%   - IEEE Std 802.11-2020
%   - MATLAB wlan Toolbox documentation for wlanHTOFDMInfo, wlanHTConfig
%   - O'Reilly: "802.11ac: A Survival Guide" for channel descriptions.
%
% SEE ALSO:
%   wlanHTOFDMInfo, wlanHTConfig, wlanVHTOFDMInfo, wlanNonHTOFDMInfo, wlanEHTOFDMInfo
%
function info = getSubcarrierMapping(fieldname, cfgHT, sampleRate)

  % Obtain base information from wlanHTOFDMInfo
  info = wlanHTOFDMInfo(fieldname, cfgHT);

  % Handle SampleRate availability
  if ~isfield(info, 'SampleRate')
    if nargin < 3 || isempty(sampleRate)
      error('SampleRate not provided by wlanHTOFDMInfo. Please specify it as a third argument.');
    else
      info.SampleRate = sampleRate;
    end
  end

  % Compute frequency spacing and carrier reference index
  info.FreqSpacing = info.SampleRate / info.FFTLength;
  info.CarrierIdx  = info.FFTLength / 2;

  % Compute frequency indices from [-NFFT/2, NFFT/2-1]
  info.FrequencyIndices = reshape((0:(info.FFTLength - 1)) - info.CarrierIdx, [], 1);

  % Determine null frequencies (those not in the active set)
  info.NullFrequencyIndices = setdiff(info.FrequencyIndices, info.ActiveFrequencyIndices);

  % Compute frequency-based indices for pilots and data
  info.PilotFrequencyIndices = info.ActiveFFTIndices(info.PilotIndices) - info.CarrierIdx - 1;
  info.DataFrequencyIndices  = info.ActiveFFTIndices(info.DataIndices)  - info.CarrierIdx - 1;

  % Compute frequency axes (in Hz)
  info.FrequencyAxis       = info.FrequencyIndices * info.FreqSpacing;
  info.ActiveFrequencyAxis = info.ActiveFrequencyIndices * info.FreqSpacing;

  % Create 1-based index arrays
  info.Indices     = reshape((0:(info.FFTLength - 1)) + 1, [], 1);
  info.FFTIndices  = union(info.DataIndices, info.PilotIndices);
  info.NullIndices = setdiff(info.Indices, info.ActiveFFTIndices);
end
