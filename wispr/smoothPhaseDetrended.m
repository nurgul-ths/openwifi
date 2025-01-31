function phaseSmoothed = smoothPhaseDetrended(phaseTensor, filterSize)
  % smoothPhaseDetrended smooths CSI phase while preserving linear trends.
  %
  % WiFi CSI data often has a slope in the phase response across subcarriers,
  % particularly when the main path isn't perfectly aligned at tap 0. This slope
  % can distort results if we apply a moving average directly. By detrending
  % (removing the slope) before smoothing, then reapplying the slope afterward,
  % we avoid flattening the meaningful phase gradient.
  %
  % Args:
  %   phaseTensor (matrix): CSI phase data (Time x Subcarriers)
  %     Must be 2D with no NaN values
  %   filterSize (integer): Moving mean filter window size
  %     Should be smaller than number of subcarriers to preserve slope
  %
  % Returns:
  %   matrix: Smoothed phase data with same shape as input, preserving low-frequency
  %     trends while reducing high-frequency fluctuations
  %
  % Processing Steps:
  %   1) Verify no NaN values in 'phaseTensor'
  %   2) Unwrap phase along subcarrier dimension to handle 2π discontinuities
  %   3) Detrend along the subcarrier dimension, removing linear slopes
  %   4) Smooth the detrended data using zero-phase moving average filter
  %   5) Reapply the linear trend
  %
  % Note:
  %   - If higher-order polynomial trends are suspected, consider 'detrend(…, 2)' or
  %     a custom polynomial fit. Although this then starts making some assumptions
  %   - Zero-phase filtering is used to avoid phase distortion in the smoothing
  %   - This approach preserves any large-scale slope while removing short-range noise
  %   - Subcarriers are assumed to be in the last dimension as this is the common
  %     format in most WiFi CSI processing pipelines
  %
  % Example:
  %   % Suppose 'phaseData' is 1000 time samples x 64 subcarriers
  %   phaseSm = smoothPhaseDetrended(phaseData, 5);
  %   % Now 'phaseSm' is smoothed over subcarriers, preserving the overall slope
  %   % but reducing high-frequency fluctuations

  if any(isnan(phaseTensor(:)))
    error('Input phaseTensor contains NaN values. Interpolate missing data first.');
  end

  if ndims(phaseTensor) > 2
    error('Input phaseTensor must be 2-dimensional (Time x Subcarriers)');
  end

  % Transpose once to work with subcarriers in first dimension
  phaseTensor = transpose(phaseTensor);

  % Ensure the phase is unwrapped along subcarrier dimension (now first)
  phaseTensor = unwrap(phaseTensor, [], 1);

  % Linear detrend along subcarrier dimension
  phaseDetrended = detrend(phaseTensor, 1);
  phaseTrend     = phaseTensor - phaseDetrended; % Obtain the line trend so we can later add it back

  % Smooth detrended phase using zero-phase filtering
  phaseDetrended = movmeanfb(phaseDetrended, filterSize); % This requires that there cannot be NaN values in the input but we have already checked for that
  phaseSmoothed  = phaseDetrended + phaseTrend;

  % Restore original orientation
  phaseSmoothed = transpose(phaseSmoothed);
end
