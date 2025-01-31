function [prunedDFTMat] = getPrunedDFTMatrix(nfft, activeFFTIndices, fftDcIdx)
  % getPrunedDFTMatrix: generates a pruned DFT matrix for selective subcarrier processing.
  %
  % Creates a pruned DFT matrix that maps between time and frequency domains,
  % considering only active subcarriers. The matrix is oriented with rows as
  % subcarriers and columns as time/delay samples. Uses fftshift along rows to
  % center the DC subcarrier, matching WiFi-style subcarrier indexing
  % (negative frequencies, DC, positive frequencies).
  % This is similar to using the non-uniform FFT (NUFFT) for selective subcarriers.
  %
  % Args:
  %   nfft: Length of the FFT
  %   activeFFTIndices: Indices of active FFT subcarriers to retain
  %   fftDcIdx: Optional. Index of DC carrier. Defaults to floor(nfft/2) + 1
  %
  % Returns:
  %   prunedDFTMat: Pruned DFT matrix (M x N), where M is number of active subcarriers and N is nfft
  %
  % Matrix Usage:
  %   For frequency-domain data (CFR) with subcarriers along columns,
  %   multiplying by this DFT matrix (or its inverse) on the right transforms
  %   to time-domain data (CIR) and vice versa. The pruned matrix ignores
  %   unused subcarriers like guard bands or null carriers.
  %
  % Examples:
  %   % Convert CIR to CFR
  %   nfft = 64;
  %   activeIndices = 1:52;  % Using 52 active subcarriers
  %   dftMat = getPrunedDFTMatrix(nfft, activeIndices);
  %
  %   % For cirData (10 x 64), each column is a time-domain sample
  %   cirData = randn(10, nfft) + 1j*randn(10, nfft);
  %
  %   % CIR to CFR: cirData (10x64) * transpose(dftMat) (64x52) -> (10x52)
  %   cfrData = cirData * transpose(dftMat);
  %
  %   % CFR back to CIR using pseudo-inverse
  %   cirEst = cfrData * transpose(pinv(dftMat));
  %
  % Technical Details:
  %   1. Matrix Organization:
  %      - Rows: Frequency domain (subcarriers)
  %      - Columns: Time domain (delay samples)
  %      - For 802.11a/g 20MHz: nfft=64, 52 active subcarriers
  %
  %   2. FFT Shifting:
  %      - Row-wise fftshift centers DC
  %      - No column shifting preserves time-domain causality
  %      - DC index for nfft=64: 33 (MATLAB 1-based)
  %
  %   3. Subcarrier Layout:
  %      - Negative frequencies: indices 1:26 (after shift)
  %      - Positive frequencies: indices 27:52 (after shift)
  %      - Guards and DC excluded
  %
  % Note:
  %   - Match CSI/CFR measurements to activeFFTIndices order
  %   - Use pseudo-inverse (pinv) for channel estimation
  %   - Multiplication order matters:
  %     * CIR->CFR: cirData * transpose(dftMat)
  %     * CFR->CIR: cfrData * transpose(pinv(dftMat))
  %
  % See also:
  %   dftmtx, fftshift, nufft

  if nargin < 3
    fftDcIdx = floor(nfft / 2) + 1;
  end

  % Generate the full DFT matrix (nfft x nfft)
  dftMatCenter = dftmtx(nfft);

  % Shift frequency bins along rows to center DC (WiFi-style indexing)
  % Don't shift columns to maintain proper time-domain representation
  dftMatCenter = fftshift(dftMatCenter, 1);

  % Prune matrix rows to keep only active subcarriers
  prunedDFTMat = dftMatCenter(activeFFTIndices, :);

  % Verify DC row
  if ~all(dftMatCenter(fftDcIdx, :) == 1)
    warning('DC carrier row does not match expected pattern, indicating different indexing assumptions.');
  end
end
