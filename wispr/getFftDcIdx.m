function fftDcIdx = getFftDcIdx(nfft)
  % getFftDcIdx returns the DC (zero frequency) index in centered FFT output.
  %
  % Returns the index of the DC (zero frequency) component in FFT results when
  % frequencies are centered around zero. Handles both even and odd FFT lengths.
  % This uses that the MATLAB FFT function will return for an even length of L,
  % the frequency domain starts from the negative of the Nyquist frequency
  % -Fs/2 up to Fs/2-Fs/L with a spacing or frequency resolution of Fs/L.
  %
  % However, in practice, we use this function mostly for Wi-Fi signals where
  % the FFT is centered around DC (zero frequency) and the DC component is
  % where the carrier frequency is located. This function returns the index
  % of the DC component in the FFT output assuming size 1 to 64, for instance
  % for 802.11n.
  %
  % Args:
  %   nfft: FFT length (positive integer)
  %
  % Returns:
  %   fftDcIdx: Index of DC component (1-based indexing)
  %
  % Note:
  %   For even length FFTs (e.g., nfft = 64):
  %     - Indices 1 to nfft/2: negative frequencies
  %     - Index nfft/2 + 1: DC (zero frequency)
  %     - Remaining indices: positive frequencies
  %
  %   Example for nfft = 64:
  %     - Indices 1-32: negative frequencies
  %     - Index 33: DC
  %     - Indices 34-64: positive frequencies
  %
  %   For odd length FFTs (e.g., nfft = 65):
  %     - Indices 1 to floor(nfft/2): negative frequencies
  %     - Index floor(nfft/2) + 1: DC
  %     - Remaining indices: positive frequencies
  %
  %   Example for nfft = 65:
  %     - Indices 1-32: negative frequencies
  %     - Index 33: DC
  %     - Indices 34-65: positive frequencies
  %
  % Example:
  %   dcIdx = getFftDcIdx(64);  % Returns 33
  %   dcIdx = getFftDcIdx(65);  % Also returns 33
  %
  % See also:
  %   fft, fftshift, ifftshift

  validateattributes(nfft, {'numeric'}, {'scalar', 'positive', 'integer'});
  fftDcIdx = floor(nfft / 2) + 1;
end
