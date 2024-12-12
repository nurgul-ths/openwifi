% filterCSI - Filters CSI data using a moving mean filter, handling gaps in subcarrier data.
%
% This function applies a smoothing operation to Channel State Information (CSI) data
% across frequency (subcarriers), while taking into account that some subcarriers may
% be inactive (e.g., DC or guard bands), resulting in missing (NaN) data. To address
% this, it first interpolates across these gaps to create a continuous frequency
% representation and then applies a moving mean filter. This process reduces noise
% and yields more reliable CSI estimates.
%
% WHY SEPARATE MAGNITUDE AND PHASE?
%   Averaging complex CSI data directly can produce misleading results due to phase
%   wrapping. When phase values approach π and wrap to –π, naive averaging can create
%   abrupt jumps. Similarly, filtering real and imaginary parts independently can
%   distort the underlying physical meaning because it ignores the inherent coupling
%   between them as a magnitude-phase representation.
%
%   By converting to magnitude and phase and then unwrapping the phase, we ensure
%   that filtering sees a smooth, continuous phase trajectory rather than one with
%   artificial discontinuities. This approach respects the underlying physics of
%   the signal and prevents artifacts that would arise from directly smoothing
%   complex values or separate real/imag parts.
%
% ALTERNATIVE APPROACHES AND THEIR ISSUES:
%   - Direct complex filtering:
%       Directly applying a moving mean filter to complex values can average phases
%       near ±π together, creating abrupt and unphysical jumps.
%
%   - Filtering real/imag parts separately:
%       Treating real and imaginary parts independently can lose the coherent
%       relationship between magnitude and phase, potentially causing the filtered
%       data to represent a signal that never actually existed.
%
%   - Not interpolating inactive subcarriers:
%       If inactive subcarriers remain as NaNs, the filter window may span gaps,
%       reducing filter effectiveness and introducing edge artifacts. Interpolating
%       these gaps before filtering ensures a well-defined frequency response
%       across all subcarriers.
%
% By unwrapping and smoothing phase separately, handling magnitude independently,
% and interpolating inactive subcarriers first, this method provides a more physically
% meaningful and consistent smoothing of CSI data.
%
% USAGE:
%   csiFilt = filterCSI(csiTensor, infoWlanField, filterSize)
%
% INPUT PARAMETERS:
%   csiTensor     - CSI data, size (nFrames x nSubcarriers) or (1 x nSubcarriers) if a single set.
%                   Each row is a frame/measurement, and each column is a subcarrier.
%   infoWlanField - A structure containing at least the field 'ActiveFFTIndices',
%                   which indicates which subcarriers are active.
%   filterSize    - (Optional) The window size of the moving mean filter across subcarriers.
%                   Default is 5. If filterSize <= 1, only interpolation is performed,
%                   without moving mean smoothing.
%
% OUTPUT PARAMETERS:
%   csiFilt       - Filtered CSI data, size (nFrames x length(ActiveFFTIndices)).
%                   Contains only the active subcarriers after smoothing.
%
% EXAMPLE:
%   Suppose you have CSI data (100 x 52) for 100 frames and 52 active subcarriers:
%   csiFilt = filterCSI(csiData, infoWlanField, 5);
%
%   This would:
%   - Interpolate missing subcarriers to create a continuous frequency response.
%   - Unwrap and separately smooth phase and magnitude.
%   - Apply a 5-point moving mean filter across frequency.
%   - Return the smoothed CSI for only the active subcarriers.
%
% NOTES:
%   - If filterSize <= 1, the function only interpolates missing subcarriers without
%     additional smoothing.
%   - By focusing on magnitude and unwrapped phase, we avoid discontinuities and
%     produce cleaner, more physically plausible filtered CSI.
%
function csiFilt = filterCSI(csiTensor, infoWlanField, filterSize)
  nFramesDim = 1;  % Frames dimension
  nScDim     = 2;  % Subcarrier dimension

  if nargin < 3 || isempty(filterSize)
    filterSize = 5;  % Default filter size
  end

  % Ensure csiTensor is 2D, with rows as frames and columns as subcarriers
  if isvector(csiTensor)
    csiTensor = reshape(csiTensor, 1, []);
  end

  activeIndices = infoWlanField.ActiveFFTIndices;
  firstIdx      = activeIndices(1);
  lastIdx       = activeIndices(end);
  fullRange     = firstIdx:lastIdx;

  % Identify inactive subcarriers within the full range
  inactiveIndices = setdiff(fullRange, activeIndices);
  inactiveIndices = inactiveIndices - firstIdx + 1;

  % Initialize arrays to hold the full range of subcarriers (active + inactive)
  magFull   = NaN(size(csiTensor, 1), length(fullRange));
  phaseFull = NaN(size(csiTensor, 1), length(fullRange));

  % Map active indices to the continuous subcarrier range
  mappedIndices = activeIndices - firstIdx + 1;
  magFull(:, mappedIndices)   = abs(csiTensor);
  phaseFull(:, mappedIndices) = unwrap(angle(csiTensor), [], nScDim);

  % Fill missing values (inactive subcarriers) by linear interpolation
  magFilled   = fillmissing(magFull, 'linear', nScDim, 'EndValues', 'extrap');
  phaseFilled = fillmissing(phaseFull, 'linear', nScDim, 'EndValues', 'extrap');

  % If filterSize <= 1, just return the interpolated data (no smoothing)
  if filterSize <= 1
    csiFull = magFilled .* exp(1j * phaseFilled);
    csiFilt = csiFull(:, mappedIndices);
    return;
  end

  % Smooth magnitude directly
  magSmoothed = movmean(magFilled, filterSize, nScDim, 'omitnan');

  % Smooth phase using a detrended approach (smoothPhaseDetrended)
  phaseSmoothed = smoothPhaseDetrended(phaseFilled, filterSize, nScDim);

  % Combine smoothed magnitude and phase
  csiFull = magSmoothed .* exp(1j * phaseSmoothed);

  % Extract only active subcarriers after smoothing
  csiFilt = csiFull(:, mappedIndices);
end






















% % filterCSI - Filters CSI data with moving mean filter by first fillin in NaNs
% % where we don't have subcarriers (DC and edges
% %
% % Inputs:
% %   csiTensor - CSI data, shape (nFrames, nSubcarriers)
% %   infoWlanField - Structure with ActiveFFTIndices field
% %   filterSize - Size of moving mean filter (default: 5)
% %
% % Outputs:
% %   csiFilt - Filtered CSI data, same size as input
% %
% function csiFilt = filterCSI(csiTensor, infoWlanField, filterSize)
%   nFramesDim = 1;  % Frames dimension
%   nScDim     = 2;  % Subcarrier dimension

%   if nargin < 3 || isempty(filterSize)
%     filterSize = 5;  % Default filter size
%   end

%   % Ensure correct shape
%   if isvector(csiTensor)
%     csiTensor = reshape(csiTensor, 1, []);
%   end

%   % Get indices
%   activeIndices = infoWlanField.ActiveFFTIndices;
%   firstIdx      = activeIndices(1);
%   lastIdx       = activeIndices(end);
%   fullRange     = firstIdx:lastIdx;

%   % Get inactive indices in mapped space
%   inactiveIndices = setdiff(fullRange, activeIndices);
%   inactiveIndices = inactiveIndices - firstIdx + 1;

%   % Initialize arrays just covering the range we need
%   magFull   = NaN(size(csiTensor, 1), length(fullRange));
%   phaseFull = NaN(size(csiTensor, 1), length(fullRange));

%   % Map active indices to new range
%   mappedIndices = activeIndices - firstIdx + 1;
%   magFull(:, mappedIndices)   = abs(csiTensor);
%   phaseFull(:, mappedIndices) = unwrap(angle(csiTensor), [], nScDim);

%   % Fill only inactive indices using linear interpolation
%   magFilled   = fillmissing(magFull, 'linear', nScDim, 'EndValues', 'extrap');
%   phaseFilled = fillmissing(phaseFull, 'linear', nScDim, 'EndValues', 'extrap');

%   % Just interpolate
%   if filterSize <= 1
%     csiFull = magFilled .* exp(1j * phaseFilled);
%     csiFilt = csiFull(:, mappedIndices);
%     return;
%   end

%   % Smooth magnitude directly
%   magSmoothed = movmean(magFilled, filterSize, nScDim, 'omitnan');

%   % Smooth phase using detrended approach (the detrended approach works much better when we interpolate the inner sub-carriers if any are missing!)
%   phaseSmoothed = smoothPhaseDetrended(phaseFilled, filterSize, nScDim);

%   % Combine and extract only the active indices
%   csiFull = magSmoothed .* exp(1j * phaseSmoothed);
%   csiFilt = csiFull(:, mappedIndices);
% end





































%
%
%
%
%
%
% % filterCSI - Filters CSI data with moving mean filter, handling gaps where there are
% % no sub-carriers by first interpolating. Large gaps are perfectly fine as we just filter in the region
% % where we have sub-carriers and later remove the ones not used.
% % It can only work with inner indices!
% %
% % USAGE
% %   [csiFilt, csiFiltFull] = filterCSI(csiTensor, infoWlanField, filterSize)
% %
% % INPUT PARAMETERS
% %   csiTensor     - Spliced CSI information containing both magnitude and phase. Shape must be (nFrames/nSymbols, nSubcarriers).
% %   infoWlanField - Splicing information containing active frequency indices. Information on the WLAN field
% %   filterSize    - (Optional) Maximum window size for median filtering, default is 3.
% %   smoothSize    - (Optional) Size of the moving mean filter, default is 5.
% %
% % OUTPUT PARAMETERS
% %   csiFilt - Filtered CSI information
% %   csiFiltFull - Filtered CSI information with all sub-carriers
% %
% function [csiFilt, csiFiltFull] = filterCSI(csiTensor, infoWlanField, filterSize, smoothSize)
%
%   nFramesDim = 1; % Frames dimension
%   nScDim     = 2; % Subcarrier dimension
%
%   if nargin < 3 || isempty(filterSize)
%     filterSize = 1; % Disable filtering, but we still fix the NaNs
%   end
%
%   if nargin < 4 || isempty(smoothSize)
%     smoothSize = 5; % Always smooth a bit by default
%   end
%
%   if isvector(csiTensor)
%     csiTensor = reshape(csiTensor, 1, []); % If single measurement, ensure subcarrier dimension is last
%   end
%
%   activeIndices = infoWlanField.ActiveFFTIndices;
%   nFrames       = size(csiTensor, nFramesDim);
%
%   %% Filter magnitude and phase separately
%   magFull   = NaN(nFrames, infoWlanField.FFTLength);
%   phaseFull = NaN(nFrames, infoWlanField.FFTLength);
%   magFull(:, activeIndices)   = abs(csiTensor);
%   phaseFull(:, activeIndices) = unwrap(angle(csiTensor), [], nScDim);
%
%   % Inner indices are when activeIndices has gaps inside
%   innerIndices =
% ;
%   innerIndices = setdiff(innerIndices, activeIndices);
%
%   % Get the general indices to fill in from where we don't have data and any NaNs if there are any
%   nanIndices        = isnan(magFull);
%   nonNanIndices     = ~isnan(phaseFull);
%   subcarrierIndices = 1:infoWlanField.FFTLength;
%
%   %% Moving averaging
%   % This must be applied before filling, this is just used for filling the missing values so heavier smoothing is fine here
%   % WE DO NOT USE THE MOVMEAN RESULTS HERE FOR THE FINAL CSI, JUST FOR FILLING THE MISSING VALUES
%   magFullInterp   = fillmissing(magFull, 'linear', nScDim, 'EndValues', 'extrap');
%   phaseFullInterp = fillmissing(phaseFull, 'linear', nScDim, 'EndValues', 'extrap');
%
%   magFullInterp   = movmean(magFullInterp, smoothSize, nScDim, 'omitnan');
%   phaseFullInterp = smoothPhaseDetrended(phaseFullInterp, smoothSize, nScDim); % Does not handle NaN
%
%   if filterSize <= 1
%     csiFiltFull = magFullInterp .* exp(1j * phaseFullInterp);
%     csiFilt     = csiFiltFull(:, activeIndices);
%     return;
%   end
%
%   %% Filtering
%   % Interpolation, revisit, should really use the end point approach
%   % REVISIT: Can this be done with fill missing? Would be much faster
%   % Note that we use interpolation now instead of fillmissing, as fillmissing does not work well with the phase
%   % Fill end points and remaining (fillmissing does not work so well with the phase)
%   % magFullInterp   = fillmissing(magFullInterp, 'linear', nScDim, 'EndValues', 'extrap');
%   % phaseFullInterp = fillmissing(phaseFullInterp, 'linear', nScDim, 'EndValues', 'extrap');
%
%   % Process each frame only if it has NaN values, Use the fitted data to fill the end points
%   % Note that this is just used for having better filtering at the end, we don't actually use csiFiltFull
%   % only csiFilt
%   % REVISIT: Consider adding the filtering we did in another place here! Or do the clipping of the
%   % CIR to go back and forth here and interpolate!
%   for iFrame = 1:nFrames
%     frameNanIndices = find(nanIndices(iFrame, :));
%
%     % Skip frame if no NaN values
%     if ~isempty(frameNanIndices)
%       % Find valid indices for this frame
%       interpIndices = find(nonNanIndices(iFrame, :));
%
%       % Fit and interpolate magnitude
%       fitCoeffs = polyfit(interpIndices, magFullInterp(iFrame, interpIndices), 1);
%       magFullInterp(iFrame, :) = polyval(fitCoeffs, subcarrierIndices);
%
%       % Fit and interpolate phase
%       fitCoeffs = polyfit(interpIndices, phaseFullInterp(iFrame, interpIndices), 1);
%       phaseFullInterp(iFrame, :) = polyval(fitCoeffs, subcarrierIndices);
%
%       % Fill only the NaN values for this frame
%       magFull(iFrame, frameNanIndices)   = magFullInterp(iFrame, frameNanIndices);
%       phaseFull(iFrame, frameNanIndices) = phaseFullInterp(iFrame, frameNanIndices);
%     end
%   end
%
%   % Smoothing of final results
%   % Phase smoothing needs to work on detrendded unwrapped or it can do some crazy stuff
%   magFull   = movmean(magFull, filterSize, nScDim, 'omitnan');
%   phaseFull = smoothPhaseDetrended(phaseFull, filterSize, nScDim);
%
%   csiFiltFull = magFull .* exp(1j * phaseFull);
%   csiFilt     = csiFiltFull(:, activeIndices);
% end
%





  % % Filter complex CSI data (seems that it is slighly better to do the movmean on the abs and angle separately)
  % csiFiltFull = NaN(nFrames, infoWlanField.FFTLength, "like", 1j);
  % csiFiltFull(:, activeIndices)  = csiTensor;

  % % Fill end points and remaining with nearest before moving mean filtering
  % csiFiltFull   = fillmissing(csiFiltFull, 'linear', nScDim, 'EndValues', 'extrap');
  % csiFiltFull   = movmean(csiFiltFull, filterSize, nScDim);

  % csiFiltFull = csiFiltFull;
  % csiFilt     = csiFiltFull(:, activeIndices);
