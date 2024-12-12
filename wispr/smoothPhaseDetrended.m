% smoothPhaseDetrended - Smoothes phase data using a moving mean filter in a detrended domain.
%
% This function removes linear trends in the phase data before smoothing, ensuring that
% the moving mean filter does not distort underlying gradients. After smoothing the detrended
% data, the original trend is reintroduced. This approach is most effective when the phase
% is already continuous and free of NaNs (e.g., after interpolation of missing data).
%
% USAGE:
%   phaseSmoothed = smoothPhaseDetrended(phase, filterSize, nScDim)
%
% INPUT PARAMETERS:
%   phase      : Phase data array (N x M or a vector), with no NaNs.
%   filterSize : Size of the moving mean filter window.
%   nScDim     : Dimension along which subcarriers vary (1 for rows, 2 for columns).
%
% OUTPUT PARAMETERS:
%   phaseSmoothed : Phase data after detrending, smoothing, and reapplying the trend.
%
function phaseSmoothed = smoothPhaseDetrended(phase, filterSize, nScDim)

  if any(isnan(phase(:)))
    error('Input phase contains NaN values. Interpolate missing data first.');
  end

  origSize = size(phase);

  % Ensure subcarriers vary along rows
  if nScDim == 2 && ~isvector(phase)
    phase = transpose(phase);
    subcarriersAlongDim1 = true;
  else
    subcarriersAlongDim1 = false;
  end

  % Detrend along dimension 1
  phaseDetrended = detrend(phase, 1);
  phaseTrend     = phase - phaseDetrended;

  % Smooth detrended phase
  phaseDetrended = movmean(phaseDetrended, filterSize, 1, 'omitnan');
  phaseSmoothed  = phaseDetrended + phaseTrend;

  % Restore original orientation if needed
  if subcarriersAlongDim1
    phaseSmoothed = transpose(phaseSmoothed);
  end

  % Restore original shape if changed
  if ~isequal(size(phaseSmoothed), origSize)
    phaseSmoothed = reshape(phaseSmoothed, origSize);
  end
end
