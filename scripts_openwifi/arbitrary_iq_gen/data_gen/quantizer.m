% quantizer: Quantizes complex data to a specified bitwidth and clips values to fit within a 16-bit dynamic range.
%
% USAGE
%   [realPart, imagPart, scalingFactor] = quantizer(dataComplex, bitwidth)
%   [realPart, imagPart, scalingFactor] = quantizer(dataComplex, bitwidth, scalingFactor)
%
% INPUT PARAMETERS
%   dataComplex   : Complex input data to be quantized.
%   bitwidth      : Desired bitwidth for scaling the data (e.g., 15.5 bits). Must be ≤ 16.
%   scalingFactor : (Optional) scaling factor for normalization. If not provided or empty,
%                   the function will calculate it.
%
% OUTPUT PARAMETERS
%   realPart      : Quantized and clipped real part of the data.
%   imagPart      : Quantized and clipped imaginary part of the data.
%   scalingFactor : Scaling factor used for normalization.
%
% DETAILS
%   This function scales complex data to the specified bitwidth, clips values to a 16-bit range,
%   and calculates Peak-to-Average Power Ratio (PAPR) before and after clipping. It also reports
%   the number of samples clipped and the maximum bitwidth required to represent the clipped data.
%
% EXAMPLES
%   [realPart, imagPart, scalingFactor] = quantizer(dataComplex, 15.5);
%
% REVISIT
%   Improve efficiency for large datasets and consider adding automatic bitwidth detection.
%
function [realPart, imagPart, scalingFactor] = quantizer(dataComplex, bitwidth, scalingFactor)

  % Define the maximum datapath bitwidth for signed 16-bit integers
  datapathBitwidth = 16;
  maxIntValue = 2^(datapathBitwidth - 1) - 1; % Max value for signed 16-bit integer

  %===============================================================================
  % Determine the scaling factor if not provided
  if nargin < 3 || isempty(scalingFactor)
    scalingFactor = max(abs(dataComplex)); % Normalize to max value of 1
    if scalingFactor == 0
      scalingFactor = 1; % Avoid division by zero if dataComplex is all zeros
    end
  end

  normalizedData = dataComplex / scalingFactor;

  %===============================================================================
  % Scale the normalized data to the desired bitwidth and round
  adcScalingFactor = 2^(bitwidth - 1) - 1;
  realPartScaled = real(normalizedData) * adcScalingFactor;
  imagPartScaled = imag(normalizedData) * adcScalingFactor;
  realPartScaled = reshape(round(realPartScaled), 1, []);
  imagPartScaled = reshape(round(imagPartScaled), 1, []);

  %===============================================================================
  % Calculate PAPR before clipping
  frame = realPartScaled + 1j * imagPartScaled;
  papr = pow2db(max(abs(frame).^2) / mean(abs(frame).^2));
  fprintf('\tPAPR pre-clipping: %.2f dB\n', papr);

  %===============================================================================
  % Clip values to fit within 16-bit range
  realPartClipped = min(max(realPartScaled, -maxIntValue), maxIntValue);
  imagPartClipped = min(max(imagPartScaled, -maxIntValue), maxIntValue);

  %===============================================================================
  % Calculate PAPR after clipping
  frame = realPartClipped + 1j * imagPartClipped;
  papr = pow2db(max(abs(frame).^2) / mean(abs(frame).^2));
  fprintf('\tPAPR post-clipping: %.2f dB\n', papr);

  %===============================================================================
  % Calculate and report the number of clipped samples
  realClippedCount = sum(abs(realPartScaled) > maxIntValue);
  imagClippedCount = sum(abs(imagPartScaled) > maxIntValue);
  totalClippedCount = realClippedCount + imagClippedCount;
  totalSamples = numel(realPartScaled) + numel(imagPartScaled);

  fprintf('\tSamples clipped: %d / %d for bitwidth %.1f\n', totalClippedCount, totalSamples, bitwidth);

  %===============================================================================
  % Calculate the maximum bitwidth required for real and imaginary parts
  % +1 ensures a minimum of 1 bit when the value is zero, and another +1 accounts for the signed bit
  maxBitsReal = ceil(log2(max(abs(realPartClipped)) + 1)) + 1;
  maxBitsImag = ceil(log2(max(abs(imagPartClipped)) + 1)) + 1;

  fprintf('\tMaximum bits required for real part: %d\n', maxBitsReal);
  fprintf('\tMaximum bits required for imaginary part: %d\n', maxBitsImag);

  %===============================================================================
  % Return the quantized and clipped real and imaginary parts
  realPart = reshape(fix(realPartClipped), 1, []);
  imagPart = reshape(fix(imagPartClipped), 1, []);

end
