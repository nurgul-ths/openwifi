function cir = computeCirCorr(txData, rxData, rxStartIndex, fftLength)
  % computeCirCorr estimates the Channel Impulse Response (CIR) via cross-correlation.
  %
  % Estimates CIR by cross-correlating received data with known transmitted sequence.
  % The peak of cross-correlation indicates dominant path delay. A window of size
  % fftLength around that peak captures significant multipath components within one
  % OFDM symbol duration.
  %
  % Args:
  %   txData: Transmitted time-domain OFDM symbols (nSamplesTx × 1)
  %   rxData: Received time-domain OFDM symbols (nSamplesRx × 1)
  %   rxStartIndex: Integer start index in rxData (scalar)
  %   fftLength: Length of the FFT, must be even (scalar)
  %
  % Returns:
  %   cir: Estimated CIR (fftLength × 1), with main tap at cir(1)
  %
  % Note:
  %   After extracting and ifftshifting the result, cir(1) corresponds to zero-lag,
  %   and subsequent indices represent increasing path delays. Normalization by
  %   length(txData) provides reasonable scaling, though alternative normalizations
  %   (e.g., transmit power) are possible.
  %
  % Implementation Details:
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
  %   the channel's multipath structure and aligns the main tap correctly. While the CP
  %   is essential for maintaining subcarrier orthogonality in frequency-domain methods,
  %   its presence here does not prevent correct CIR estimation.
  %
  %   In practice, CSI estimation methods are influenced by real-world conditions such
  %   as multipath (modeled by scattering or ray-tracing approaches), noise, and
  %   hardware imperfections. Regardless of approach, the goal is the same: accurate
  %   characterization of the wireless channel for improved performance (e.g., MU-MIMO
  %   beamforming, link adaptation, and advanced sensing applications).
  %
  % Complexity:
  %   O(N log N) where N is length(txData), due to FFT-based xcorr implementation
  %
  % Future Improvements:
  %   Consider normalizing by transmit signal energy (e.g., sum(abs(txData).^2))
  %
  % Example:
  %   tx = randn(1024, 1);
  %   rx = conv(tx, [1; 0.5; 0.2]); % Simple multipath channel
  %   cir = computeCirCorr(tx, rx, 1, 64);
  %
  % See also:
  %   xcorr, ifftshift, conv

  % Validate inputs
  if rxStartIndex > length(rxData)
    error('rxStartIndex exceeds the length of rxData.');
  end
  if mod(fftLength, 2) ~= 0
    warning('fftLength is not even. Ensure indexing for extracting CIR is correct.');
  end

  validateattributes(txData, {'numeric'}, {'vector', 'finite'}, 'computeCirCorr', 'txData');
  validateattributes(rxData, {'numeric'}, {'vector', 'finite'}, 'computeCirCorr', 'rxData');

  % Set maximum correlation lag
  maxLag = fftLength;

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
