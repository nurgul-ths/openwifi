function [pxx, freqCombined] = spectrum_psd(signal, fs, varargin)
  % spectrum_psd Compute one-sided power spectral density using periodogram.
  %
  % Args:
  %   signal (vector):
  %     Input time series signal. Must be a numeric vector (row or column).
  %   fs (double):
  %     Sampling frequency in Hz. Must be a positive scalar.
  %   varargin (Name-Value pairs):
  %     'nfft' (numeric):
  %       FFT size. Default is 2^nextpow2(length(signal)).
  %       A larger FFT size gives finer frequency resolution but can increase noise.
  %     'kaiserBeta' (numeric):
  %       Window shape parameter. Default is 5.0.
  %       - 0: Rectangular window (best resolution, highest leakage)
  %       - 5: Hamming-like window (good resolution/leakage balance)
  %       - 6: Hann-like window (better sidelobe suppression)
  %       - Other numeric values: Kaiser window with specified beta
  %     'fMin' (numeric):
  %       Minimum frequency to keep (Hz). Default is 0.
  %     'fMax' (numeric):
  %       Maximum frequency to keep (Hz). Default is fs/2.
  %     'detrend' (numeric):
  %       Polynomial order for detrending (0 for mean removal, 1 for linear, etc.).
  %       Default is 0.
  %
  % Returns:
  %   pxx (vector):
  %     One-sided power spectral density estimate.
  %   freqCombined (vector):
  %     Frequency axis in Hz (positive frequencies only).
  %
  % Processing Steps:
  %   1. Apply polynomial detrending to handle offset/drift.
  %   2. Apply window function to reduce spectral leakage.
  %   3. Compute two-sided periodogram via FFT (with 'centered' frequency).
  %   4. Combine symmetric (negative) frequencies to create a one-sided PSD.
  %   5. Limit the PSD to the specified frequency range [fMin, fMax].
  %
  % Notes:
  %   - The one-sided PSD is scaled so total power is preserved after folding.
  %   - The window normalization (e.g., 'energy') in get_window can affect power levels.
  %   - If the signal is complex, combining negative frequencies might need reevaluation.
  %
  % Example:
  %   sig = randn(1,1024);
  %   fs  = 1000;
  %   [pxx, freq] = spectrum_psd(sig, fs, 'nfft', 2048, 'fMax', 400);
  %
  % See also:
  %   periodogram, get_window, combine_symmetric_frequencies

  % Parse input parameters
  p = inputParser;
  addParameter(p, 'nfft', [], @isnumeric);
  addParameter(p, 'kaiserBeta', 5.0, @isnumeric);
  addParameter(p, 'fMin', 0, @isnumeric);
  addParameter(p, 'fMax', fs/2, @isnumeric);
  addParameter(p, 'detrend', 0, @isnumeric);
  parse(p, varargin{:});
  opts = p.Results;

  % Set default nfft if not specified
  if isempty(opts.nfft)
    opts.nfft = 2^nextpow2(length(signal));
  end

  win    = get_window(opts.kaiserBeta, length(signal));
  signal = detrend(signal, opts.detrend);
  [psd, freq] = periodogram(signal, win, opts.nfft, fs, 'centered');

  % Combine symmetric frequencies
  [pxx, freqCombined] = combine_symmetric_frequencies(psd, freq);

  % Apply frequency range limits
  freqMask     = (freqCombined >= opts.fMin) & (freqCombined <= opts.fMax);
  freqCombined = freqCombined(freqMask);
  pxx = pxx(freqMask);
 end
