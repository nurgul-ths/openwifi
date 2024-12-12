% getPrunedDFTMatrix - Generates a pruned DFT matrix for selective subcarrier processing.
%
% This function creates a pruned DFT matrix that maps between time and frequency
% domains, considering only active subcarriers. The matrix is oriented so that
% each row corresponds to a subcarrier and each column corresponds to a time/delay
% sample. By applying fftshift along the row dimension, the DC subcarrier is
% centered, aligning with the WiFi-style indexing of subcarriers:
% negative frequencies first, then DC, then positive frequencies.
%
% In practice, when you have frequency-domain data (e.g., CFR) arranged with
% subcarriers along the columns, multiplying by this DFT matrix (or its inverse)
% on the right will transform it into time-domain data (e.g., CIR), and vice versa.
% Because we only retain active subcarriers, this pruned DFT matrix ignores
% subcarriers that are never used, such as guard bands or null carriers.
%
% USAGE:
%   prunedDFTMat = getPrunedDFTMatrix(nfft, activeFFTIndices)
%   prunedDFTMat = getPrunedDFTMatrix(nfft, activeFFTIndices, fftDcIdx)
%
% INPUT PARAMETERS:
%   nfft             : The length of the FFT.
%   activeFFTIndices : The indices of the active FFT subcarriers to retain.
%   fftDcIdx         : (Optional) The index of the DC carrier. Defaults to floor(nfft/2) + 1.
%
% OUTPUT PARAMETERS:
%   prunedDFTMat     : The pruned DFT matrix of size (M x N), where M is the number
%                      of active subcarriers (length of activeFFTIndices) and N is nfft.
%
% EXAMPLES:
%   % Example 1: Converting CIR to CFR
%   nfft = 64;
%   activeIndices = 1:52;  % Example: Using 52 active subcarriers
%   dftMat = getPrunedDFTMatrix(nfft, activeIndices);
%
%   % Suppose cirData is (10 x 64), with each column representing a time-domain sample
%   % (delay bin) and each row representing an observation/sample.
%   cirData = randn(10, nfft) + 1j*randn(10, nfft);
%
%   % To convert CIR to CFR:
%   % Multiplying cirData (10 x 64) by transpose(dftMat) (64 x 52) yields a (10 x 52) CFR matrix.
%   cfrData = cirData * transpose(dftMat);
%
%   % Example 2: Converting CFR back to CIR using a pseudo-inverse (least squares)
%   % Multiplying cfrData (10 x 52) by the transpose of pinv(dftMat) (52 x 64)
%   % yields a (10 x 64) CIR matrix.
%   cirEst = cfrData * transpose(pinv(dftMat));
%
% TECHNICAL DETAILS:
%   1. Matrix Orientation:
%      - The pruned DFT matrix has subcarriers along its rows and time samples along its columns.
%      - Your data matrix should have the dimension corresponding to these domains along its columns,
%        so that multiplication on the right applies the transform appropriately.
%
%   2. FFT Shifting:
%      - We apply fftshift along the row dimension only to center the DC subcarrier.
%      - No column shift is performed, preserving the natural time ordering, so t=0 is at the start.
%
%   3. Pruning:
%      - We select only the rows corresponding to active subcarriers. Inactive subcarriers
%        (guard bands, nulls) are removed.
%      - This ensures the frequency-domain data and the DFT matrix align perfectly.
%
% NOTE:
%   When working with CSI or CFR measurements, ensure that the order of subcarriers in your frequency-domain
%   data matches activeFFTIndices. The pseudo-inverse can be used for least-squares channel estimation
%   (transforming CFR back to CIR).
%
function [prunedDFTMat] = getPrunedDFTMatrix(nfft, activeFFTIndices, fftDcIdx)
  if nargin < 3
    fftDcIdx = floor(nfft / 2) + 1;
  end

  % Generate the full DFT matrix (nfft x nfft)
  dftMatCenter = dftmtx(nfft);

  % Shift frequency bins along the rows to center DC (WiFi-style indexing)
  % We don't shift columns to maintain proper time-domain representation where t=0 starts at the beginning
  dftMatCenter = fftshift(dftMatCenter, 1);

  % Prune the matrix to keep only active subcarriers
  prunedDFTMat = dftMatCenter(activeFFTIndices, :);

  % Verify the DC row
  if ~all(dftMatCenter(fftDcIdx, :) == 1)
    warning('The DC carrier row does not match the expected pattern, indicating different indexing assumptions.');
  end
end
