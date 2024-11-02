%find_best_and_worst_papr_frames: Finds the WLAN frames with the lowest and
% highest Peak-to-Average Power Ratio (PAPR) over a specified number of frames.
%
% USAGE
%   [lowestPAPRFrame, highestPAPRFrame, lowestPAPR, highestPAPR] = find_best_and_worst_papr_frames(cfgHT, numSeeds)
%
% INPUT PARAMETERS
%   cfgHT   : WLAN configuration object specifying the frame parameters.
%   numSeeds: Number of random seeds to generate frames and test PAPR.
%
% OUTPUT PARAMETERS
%   lowestPAPRFrame : Frame with the lowest PAPR.
%   highestPAPRFrame: Frame with the highest PAPR.
%   lowestPAPR      : Lowest PAPR value found (in dB).
%   highestPAPR     : Highest PAPR value found (in dB).
%
% DETAILS
%   This function generates WLAN frames using random data and calculates
%   the PAPR for each frame. It then identifies and outputs the frames
%   with the lowest and highest PAPR, along with their respective PAPR values.
%   A seed is reset for each frame generation for reproducibility.
%
% REVISIT
%   Potential improvements include exploring different scrambling or normalization
%   options for further PAPR optimization.
%
% REFERENCES
%   See "IEEE Std 802.11-2016" for WLAN configuration specifications.

function [lowestPAPRFrame, highestPAPRFrame, lowestPAPR, highestPAPR] = find_best_and_worst_papr_frames(cfgHT, numSeeds)

  % Initialize variables for tracking the lowest and highest PAPR
  lowestPAPR       = inf;
  highestPAPR      = -inf;
  lowestPAPRFrame  = [];
  highestPAPRFrame = [];

  % Loop through the specified number of seeds to generate frames and compute PAPR
  for seed = 1:numSeeds
    rng(seed);                % Set initial seed for reproducibility
    newseed = randi([0, 2^31-1]);
    rng(newseed);

    psdu      = randi([0, 1], 8 * cfgHT.PSDULength, 1);  % Generate random PSDU data
    wlanFrame = wlanWaveformGenerator(psdu, cfgHT);      % Generate WLAN frame

    % Calculate PAPR
    peakPower = max(abs(wlanFrame).^2);
    avgPower  = mean(abs(wlanFrame).^2);
    papr      = pow2db(peakPower / avgPower);

    % Check and update lowest PAPR
    if papr < lowestPAPR
      lowestPAPR      = papr;
      lowestPAPRFrame = wlanFrame;
    end

    % Check and update highest PAPR
    if papr > highestPAPR
      highestPAPR      = papr;
      highestPAPRFrame = wlanFrame;
    end
  end

  % Display results for the lowest and highest PAPR values
  fprintf('Lowest PAPR: %.2f dB\n', lowestPAPR);
  fprintf('Highest PAPR: %.2f dB\n', highestPAPR);
end
