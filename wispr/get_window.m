function window = get_window(kaiserBeta, sigLength, normMethod)
  % get_window returns a window function with selectable normalization/scaling.
  %
  % Returns a window function (Kaiser, Hamming, Hann, or rectangular) with
  % configurable shape and normalization. The Kaiser window parameter provides
  % a flexible family of windows, with special cases matching common windows.
  %
  % Args:
  %   kaiserBeta: Kaiser window shape parameter
  %     0: Returns rectangular window (no windowing)
  %     5: Returns Hamming window ('periodic' type)
  %     6: Returns Hann window ('periodic' type)
  %     other values: Returns Kaiser window with specified beta
  %   sigLength: Length of the output window in samples
  %   normMethod: Optional. Normalization method (default: 'energy')
  %     'energy': Energy normalization (RMS) preserving total signal power
  %     'peak': Peak normalization, preserving maximum amplitude
  %     'coherent': Coherent gain compensation for sinusoidal analysis
  %     'noise': Noise bandwidth normalization for SNR calculations
  %     'none': No normalization applied
  %
  % Returns:
  %   window: Normalized window function of length sigLength
  %
  % Window Selection Details:
  %   The Kaiser window with varying beta provides a flexible window family:
  %   - beta = 0 gives near-rectangular characteristics
  %   - beta ≈ 4.86 gives near-Hamming characteristics (we use exact Hamming at beta = 5)
  %   - beta ≈ 5.44 gives near-Hann characteristics (we use exact Hann at beta = 6)
  %   - larger beta values give wider mainlobes but lower sidelobes
  %
  %   For spectral analysis, the function returns 'periodic' versions of Hamming and Hann windows which are optimal
  %   for spectral analysis.
  %
  % Normalization Methods Details:
  %   Quick Summary:
  %   - Energy: Preserves total power for methods that rely on consistent energy
  %   - Peak: Ensures window cannot clip or alter original signal's max amplitude.
  %   - Coherent: Corrects amplitude measurements of sinusoidal signals
  %   - Noise: Vital for comparing noise levels or computing SNR across windows
  %   - None: Preferred when amplitude changes are irrelevant or handled elsewhere
  %
  %   Detailed Behavior:
  %   - Energy (RMS): Divides by RMS value to ensure the windowed signal's total power remains the same after
  %     windowing. Critical for eigenanalysis and adaptive combination methods where power preservation affects
  %     eigenvalue accuracy. Required for optimize_signal_combination_eig_adaptive.m.
  %
  %   - Peak: Scales the window so its maximum amplitude is 1. This ensures uniform peak levels and preserves the
  %     original signal's maximum amplitude. Essential for time-domain signal detection or applications sensitive
  %     to the maximum amplitude.
  %
  %   - Coherent: Divides by the window's mean to compensate for amplitude reduction in sinusoidal signals.
  %     Essential for accurate amplitude estimation of frequency components in spectral analysis.
  %
  %   - Noise: Normalizes by equivalent noise bandwidth for correct noise power estimation across different window
  %     types. Required for comparing noise levels or computing SNR between different windows.
  %
  % Example:
  %   % Create a Hamming window of length 1024 with energy normalization
  %   win = get_window(5, 1024, 'energy');
  %
  % See also:
  %   kaiser, hamming, hann

  if nargin < 3
    normMethod = 'energy';
  end

  if kaiserBeta == 0
    window = ones(sigLength, 1);
  elseif kaiserBeta == 5
    window = hamming(sigLength, 'periodic');
  elseif kaiserBeta == 6
    window = hann(sigLength, 'periodic');
  else
    window = kaiser(sigLength, kaiserBeta);
  end

  switch lower(normMethod)
    case 'energy'
      window = window / rms(window);
    case 'peak'
      window = window / max(abs(window));
    case 'coherent'
      window = window / mean(window);
    case 'noise'

      bw = enbw(window);  % Two-sided ENB, normalized by bin width. % Use MATLAB's built-in enbw() to find equivalent noise bandwidth
      if bw ~= 0
        window = window / sqrt(bw); % Scale so final ENB = 1
      end

    case 'none'
      % No normalization applied
    otherwise
      error('Invalid normalization method specified: %s', normMethod);
  end
end
