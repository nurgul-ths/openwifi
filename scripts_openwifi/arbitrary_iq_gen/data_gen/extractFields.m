%extractFields: Extracts various fields from an HT (High Throughput) configuration structure
% for IEEE 802.11n WLAN physical layer processing.
%
% USAGE
%   [lstf, lltf, lsig, htsig, htstf, htltf, nonHtpreamble, htPreamble] = extractFields(cfgHT)
%
% INPUT PARAMETERS
%   cfgHT: Configuration object containing IEEE 802.11n HT parameters
%
% OUTPUT PARAMETERS
%   lstf          : Legacy Short Training Field (L-STF)
%   lltf          : Legacy Long Training Field (L-LTF)
%   lsig          : Legacy Signal Field (L-SIG)
%   htsig         : High Throughput Signal Field (HT-SIG)
%   htstf         : High Throughput Short Training Field (HT-STF)
%   htltf         : High Throughput Long Training Field (HT-LTF)
%   nonHtpreamble : Concatenated non-HT preamble fields (L-STF, L-LTF, L-SIG)
%   htPreamble    : Complete HT preamble including all fields
%
% DETAILS
%   This function extracts and generates various training and signal fields
%   required for IEEE 802.11n High Throughput (HT) WLAN transmission.
%   The function utilizes WLAN Toolbox functions to generate individual fields
%   and concatenates them to form the complete preamble structures.
%
% REFERENCES
%   IEEE Std 802.11n-2009, Section 20.3.9 - Transmission of HT PPDUs
%
% REVISIT
%   TODO: Validate field lengths against the standard specifications
%   TODO: Add error checking for configuration parameters
%   TODO: Consider adding support for multiple spatial streams
%
function [lstf, lltf, lsig, htsig, htstf, htltf, nonHtpreamble, htPreamble] = extractFields(cfgHT)
  lstf  = wlanLSTF(cfgHT);
  lltf  = wlanLLTF(cfgHT);
  lsig  = wlanLSIG(cfgHT);
  htsig = wlanHTSIG(cfgHT);
  htstf = wlanHTSTF(cfgHT);
  htltf = wlanHTLTF(cfgHT);

  nonHtpreamble = vertcat(lstf, lltf, lsig);
  htPreamble    = vertcat(lstf, lltf, lsig, htsig, htstf, htltf);
end
