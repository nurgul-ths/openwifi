% computeCirCorr: Estimate the Channel Impulse Response (CIR) via cross-correlation.
%
% USAGE
%   cir = computeCirCorr(txData, rxData, rxStartIndex, fftLength)
%
% INPUT PARAMETERS
%   txData      : Transmitted time-domain OFDM symbols, vector [nSamplesTx x 1].
%   rxData      : Received time-domain OFDM symbols,   vector [nSamplesRx x 1].
%   rxStartIndex: Integer start index in rxData where the received frame begins.
%   fftLength   : Length of the FFT (e.g., 64 for 20 MHz Wi-Fi).
%
% OUTPUT PARAMETERS
%   cir : Estimated CIR, length = fftLength, with the main tap (zero-lag) at cir(1).
%
% DETAILS
%   This function estimates the CIR by cross-correlating received data with the
%   known transmitted sequence. The peak of the cross-correlation indicates the
%   dominant path delay, and extracting a window of size fftLength around that peak
%   captures all significant multipath components within one OFDM symbol duration.
%
%   After extracting and ifftshifting the result, cir(1) corresponds to zero-lag,
%   and subsequent indices represent increasing path delays. Normalization by
%   length(txData) provides a reasonable scaling, though alternative normalizations
%   (e.g., transmit power) are possible.
%
%   Conceptual Equivalence to Frequency-Domain CSI:
%   When OFDM-based systems estimate CSI via pilot demodulation (removing the CP,
%   performing an FFT, and dividing received pilots by known transmitted pilots),
%   they obtain the channel frequency response. Taking the FFT of the CIR estimated
%   here would yield a similar channel frequency response, meaning both time-domain
%   (cross-correlation) and frequency-domain (demodulation) approaches extract the
%   same underlying channel information. The difference is that demodulation works
%   directly in frequency-domain subcarriers, while cross-correlation operates in
%   the time domain.
%
%   Note on the Cyclic Prefix:
%   Unlike the frequency-domain method, we do not explicitly remove the cyclic prefix.
%   This is acceptable for CIR estimation since cross-correlation inherently captures
%   the channel’s multipath structure and aligns the main tap correctly. While the CP
%   is essential for maintaining subcarrier orthogonality in frequency-domain methods,
%   its presence here does not prevent correct CIR estimation.
%
%   In practice, CSI estimation methods are influenced by real-world conditions such
%   as multipath (modeled by scattering or ray-tracing approaches), noise, and
%   hardware imperfections. Regardless of approach, the goal is the same: accurate
%   characterization of the wireless channel for improved performance (e.g., MU-MIMO
%   beamforming, link adaptation, and advanced sensing applications).
%
% REFERENCES
%   - IEEE 802.11 standards
%   - Common OFDM-based WLAN channel estimation methods
%
% REVISIT
%   - Consider normalizing by transmit signal energy (e.g., sum(abs(txData).^2)).
%
function cir = computeCirCorr(txData, rxData, rxStartIndex, fftLength)

  % Set maximum correlation lag
  maxLag = fftLength;

  % Validate inputs
  if rxStartIndex > length(rxData)
    error('rxStartIndex exceeds the length of rxData.');
  end
  if mod(fftLength, 2) ~= 0
    warning('fftLength is not even. Ensure indexing for extracting CIR is correct.');
  end

  % Align Rx data according to the known offset
  alignedTxData = txData;
  alignedRxData = rxData(rxStartIndex:end);

  % Compute cross-correlation:
  % xcorr output length = 2*maxLag + 1, zero lag is at index (maxLag+1)
  cirXcorr = xcorr(alignedRxData, alignedTxData, maxLag);

  % Record the maximum correlation value before extraction
  fullCorrMax = max(abs(cirXcorr));

  % Zero-lag index in cirXcorr
  midPoint = maxLag + 1;

  % Extract fftLength samples centered at zero lag
  startPoint = midPoint - fftLength/2;
  endPoint   = midPoint + fftLength/2 - 1;

  if startPoint < 1 || endPoint > length(cirXcorr)
    error('Extraction range for CIR exceeds cross-correlation result bounds.');
  end

  cir = cirXcorr(startPoint:endPoint);

  % ifftshift to move the main peak (zero-lag) to the start
  cir = ifftshift(cir);

  % Compare maximum values before and after processing
  cirMax = max(abs(cir));
  if abs(fullCorrMax - cirMax) > 1e-10
    warning(['Possible peak discrepancy in CIR extraction:' newline ...
             'Original peak value: ' num2str(fullCorrMax) newline ...
             'Extracted peak value: ' num2str(cirMax) newline ...
             'Difference: ' num2str(fullCorrMax - cirMax)]);
  end

  % Normalize by length of transmitted data
  cir = cir / length(alignedTxData);
end
