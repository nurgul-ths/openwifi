%getFftDcIdx: Computes the FFT DC index for a given FFT length.
%
% USAGE
%   fftDcIdx = getFftDcIdx(nfft);
%
% INPUT PARAMETERS
%   nfft: Length of the FFT for which the DC index is to be determined.
%
% OUTPUT PARAMETERS
%   fftDcIdx: FFT DC index for the given FFT length.
%
% DETAILS
%   This function calculates the position of the DC component in an FFT result when the
%   DC component is in the center.
%
%   The DC index is (nfft / 2 + 1) for even nfft, and ((nfft + 1) / 2) for odd nfft (counting from 1)
%   Doing floor(nfft / 2) + 1 will give the same result for both even and odd nfft.
%
%   For example, for nfft=64, the DC index is 33 (counting from 1) since the first 32 bins are negative frequencies
%   and the next 32 bins are positive frequencies (the 0th frequency is included in positive).
%   So, just remember that the DC is always included in the positive frequencies which means that
%   if nfft is even, there will be one less positive (excluding DC) than negative frequency, and if nfft is odd,
%   there will be the same number of positive (excluding DC) and negative frequencies.
%
function fftDcIdx = getFftDcIdx(nfft)
  fftDcIdx = floor(nfft / 2) + 1;
end
