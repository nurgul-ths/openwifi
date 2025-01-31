% combine_symmetric_frequencies : Combines frequency components at +/- f for spectral analysis
%
% USAGE:
%   [spectrum, freq] = combine_symmetric_frequencies(spectrum, freq)
%
% INPUT PARAMETERS:
%   spectrum : Frequency domain values [numFreqBins × numTimeOrComp]
%             Can be magnitude or power. Don't use raw FFT output as input!
%   freq     : Frequency axis, symmetric around zero (e.g., [-fN...0...fN])
%
% OUTPUT PARAMETERS:
%   spectrum : Combined magnitude/power values [numPosFreqBins × numTimeOrComp]
%   freq     : Positive frequencies only [f1...fN]
%
% DETAILS:
%   Purpose:
%   Any frequency component f0 can exist in both positive and negative frequencies with different
%   magnitudes (representing clockwise/counterclockwise rotation or standing waves). This function
%   combines these components to get total magnitude/power at each frequency, simplifying analysis
%   when directional information is not needed.
%
%   Key Processing Steps:
%   1. Separate positive/negative frequencies (excluding DC at f=0)
%   2. Handle even-length FFTs which have unpaired Nyquist frequency:
%      - Odd N:  (N-1)/2 symmetric pairs
%      - Even N: N/2-1 positive freqs (excluding Nyquist and DC), (N/2) negative
%   3. Verify frequency symmetry within 1% of frequency resolution
%   4. Sum paired frequency components
%
%   Example:
%   Input  freq = [-50,-40,-30,-20,-10,0,10,20,30,40]
%   Output freq = [10,20,30,40]
%   Each output bin contains combined magnitude/power from ±f
%
%   Notes:
%   - DC (f=0) and Nyquist require separate handling if needed
%   - Verifies symmetry using frequency resolution for robustness
%   - Works with both power spectra and complex FFT outputs
%   - Preserves matrix structure for time/component dimensions
%   - The current structure of the code tries to minimize memory usage and computation time
%     hence something like removeNeg is used like it is used
%
% See also: spectrum_psd, periodogram, fft, fftshift
%
function [spectrum, freq] = combine_symmetric_frequencies(spectrum, freq)

  % Input validation
  validateattributes(spectrum, {'numeric'}, {'real', 'finite'});
  validateattributes(freq, {'numeric'}, {'vector', 'real', 'finite'});

  if isvector(spectrum)
    spectrum = spectrum(:);
  end

  inputSize = size(spectrum);

  % Identify negative and positive frequency indices
  negFreqIdx = freq < 0;
  posFreqIdx = freq > 0;

  freqNeg = freq(negFreqIdx);
  freqPos = freq(posFreqIdx);

  % If even number of total bins, remove the leftmost negative bin (the "extra" one).
  % Or check if there is one more positive (we may also have one more positive)
  if mod(length(freq), 2) == 0

    % Double check that freqNeg(1) is the leftmost negative bin, otherwise something is wrong and the freq are not in right
    % order for both 'centered' and 'twosided' cases. We also find the maximum negative and positive frequencies to decide which
    if abs(freqNeg(1)) < abs(freqNeg(2))
      error('Frequency axis is not sorted correctly.');
    else
      freqNegMax = freqNeg(1);
    end
    if abs(freqPos(end)) < abs(freqPos(end-1))
      error('Frequency axis is not sorted correctly.');
    else
      freqPosMax = freqPos(end);
    end

    % In this case, as we later need to also index the spectrum, we need to modify the indices here as freq is a list so smaller than modifying matrix
    if freqPosMax > abs(freqNegMax)
      freqPos    = freqPos(1:end-1); % Remove the largest positive frequency
      posFreqIdx = find(posFreqIdx);
      posFreqIdx = posFreqIdx(1:end-1);
    else
      freqNeg    = freqNeg(2:end); % Remove the largest negative frequency
      negFreqIdx = find(negFreqIdx);
      negFreqIdx = negFreqIdx(2:end);
    end
  end

  % Extract and validate frequency symmetry
  freqNegFlip = abs(flip(freqNeg));
  freqResolution = abs(freq(2) - freq(1));
  if ~all(abs(freqNegFlip - freqPos) < freqResolution/100)  % Allow 1% of freq resolution as tolerance
    error('Frequency axis is not symmetric around zero.');
  end

  % Combine spectrum components
  spectrumPos = spectrum(posFreqIdx, :);
  spectrumNeg = spectrum(negFreqIdx, :);

  spectrum = spectrumPos + flip(spectrumNeg, 1);

  % Return positive frequencies only
  freq = freq(posFreqIdx);

  % Reshape into original dimensions
  spectrum = reshape(spectrum, [length(freq), inputSize(2:end)]);
 end
