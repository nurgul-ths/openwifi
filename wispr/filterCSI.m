function csiFilt = filterCSI(csiTensor, infoWlanField, filterSize)
  % filterCSI filters CSI data, handling gaps in subcarrier data.
  %
  % In certain communication systems, the Channel State Information (CSI) may not be
  % available or valid for all subcarriers (e.g., DC subcarrier, guard bands). This
  % function aims to create a smooth, physically meaningful estimate of the CSI by:
  %   1. Interpolating across subcarriers that are inactive or missing. Note we only
  %      care about the active subcarriers and hence only deal with guard bands
  %      between active subcarriers and not guard bands at the edges.
  %   2. Converting CSI to magnitude and unwrapped phase, so that phase wrapping
  %      issues are avoided.
  %   3. Applying a moving mean filter across frequency to reduce noise, then
  %      recombining magnitude and phase.
  %
  % Args:
  %   csiTensor (complex matrix): CSI data (nFrames x nSubcarriers) or (1 x nSubcarriers)
  %     Each row is a frame/measurement, each column a subcarrier
  %   infoWlanField (struct): Contains at least ActiveFFTIndices field
  %     Indicates which subcarriers are active
  %   filterSize (integer, optional): Window size for moving mean filter
  %     Default: 5. If ≤1, only interpolation is performed
  %
  % Returns:
  %   complex matrix: Filtered CSI data (nFrames x length(ActiveFFTIndices))
  %     Contains only active subcarriers after smoothing
  %
  % Why separate magnitude and phase?
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
  % Alternative approaches and their issues:
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
  % Example:
  %   Suppose you have CSI data (100 x 52) for 100 frames and 52 active subcarriers:
  %   csiFilt = filterCSI(csiData, infoWlanField, 5);
  %
  %   This would:
  %   - Interpolate missing subcarriers to create a continuous frequency response
  %   - Unwrap and separately smooth phase and magnitude
  %   - Apply a 5-point moving mean filter across frequency
  %   - Return the smoothed CSI for only the active subcarriers
  %
  % Note:
  %   - If filterSize <= 1, only interpolates missing subcarriers without smoothing
  %   - By focusing on magnitude and unwrapped phase, we avoid discontinuities and
  %     produce cleaner, more physically plausible filtered CSI
  %   - It is crucial that we use zero-phase filtering to avoid phase distortion etc. as we have to splice potentially
  %
  % See also:
  %   smoothPhaseDetrended, movmean, unwrap, fillmissing

  % 0) Preprocess CSI data
  inputSize = size(csiTensor);

  nFramesDim = 1; % Frames dimension
  nScDim     = 2; % Subcarrier dimension
  activeIndices = infoWlanField.ActiveFFTIndices; % This must be postive, for Wi-Fi 20 MHz, it would be like 5,6,7,...,61

  if nargin < 3 || isempty(filterSize)
    filterSize = 5;  % Default filter size
  end

  if isvector(csiTensor)
    csiTensor = reshape(csiTensor, 1, []);
  else
    csiTensor = csiTensor(:, :);
  end

  firstIdx  = activeIndices(1);
  lastIdx   = activeIndices(end);
  fullRange = firstIdx:lastIdx;
  inactiveIndices = setdiff(fullRange, activeIndices); % Keep this one in case we want to use in future

  % 1) Map active indices to the continuous subcarrier range
  magFull   = NaN(size(csiTensor, 1), length(fullRange)); % Arrays to hold the full range of subcarriers (active + inactive)
  phaseFull = NaN(size(csiTensor, 1), length(fullRange));

  mappedIndices = activeIndices - firstIdx + 1; % Note that we do not care about edges, we just want to filter the active subcarriers and handle any
                                                % nulls in between the active. We need to subtract the first index to get the correct mapping
  magFull(:, mappedIndices)   = abs(csiTensor);
  phaseFull(:, mappedIndices) = unwrap(angle(csiTensor), [], nScDim);

  % 2) Fill missing values (inactive subcarriers) by linear interpolation
  % Linear interpolation for phase is fine here, it's just the smoothing which needs to be careful and use the detrended approach
  magFilled   = fillmissing(magFull, 'linear', nScDim, 'EndValues', 'extrap');
  phaseFilled = fillmissing(phaseFull, 'linear', nScDim, 'EndValues', 'extrap');

  % 3) If filterSize <= 1, just return the interpolated data (no smoothing) directly
  if filterSize <= 1
    csiFull = magFilled .* exp(1j * phaseFilled);
    csiFilt = csiFull(:, mappedIndices);
    return;
  end

  % Smooth magnitude and phase separately
  % magSmoothed   = movmean(magFilled, filterSize, nScDim, 'omitnan'); % Magnitude is smoothened directly
  magSmoothed   = transpose(movmeanfb(transpose(magFilled), filterSize)); % Magnitude is smoothened directly, but we transpose to work on the subcarrier dimension
  phaseSmoothed = smoothPhaseDetrended(phaseFilled, filterSize);         % Smooth phase using a detrended approach (smoothPhaseDetrended)
  csiFull = magSmoothed .* exp(1j * phaseSmoothed);

  % Extract only active subcarriers after smoothing
  csiFilt = csiFull(:, mappedIndices);

  if ~isequal(size(csiFilt), inputSize)
    csiFilt = reshape(csiFilt, inputSize);
  end
end
