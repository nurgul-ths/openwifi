function y = movmeanfb(x, k)
  % movmeanfb: Zero-phase moving average filter using filtfilt
  %
  % This function applies a zero-phase moving average filter to the input data
  % using filtfilt for forward-backward filtering, eliminating phase distortion.
  % It works on the first non-singleton dimension of the input data.
  %
  % Args:
  %   x: Input data (vector or N-D array)
  %   k: Window length (positive integer). If even, k+1 is used for symmetry
  %
  % Returns:
  %   y: Filtered signal with zero phase distortion. Same size as input x
  %
  % Notes:
  %   - Data length should be at least 3 times the window length
  %   - Edge effects are minimized by filtfilt's padding
  %   - NaN values in input will result in NaN outputs
  %
  % Example:
  %   x = randn(1000, 1);
  %   y = movmeanfb(x, 5);
  %
  % See also: filtfilt, movmean

  validateattributes(k, {'numeric'}, {'integer', 'positive', 'scalar'});

  % Handle edge case
  if k == 1
    y = x;
    return;
  end

  % Ensure odd window length for symmetry
  if mod(k, 2) == 0
    k = k + 1;
  end

  % Check data length
  if size(x, 1) < 3*k
    warning('Data length should be at least 3 times the window length');
  end

  % Create moving average filter coefficients
  b = ones(1, k) / k;
  a = 1;

  % Apply zero-phase filtering
  y = filtfilt(b, a, x);
end
