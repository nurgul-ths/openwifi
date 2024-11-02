%write_complex_data_to_file: Writes complex data to a text file and binary file.
% The function expects quantized data. If the data is not quantized, it will
% provide a warning.
%
% USAGE
%   write_complex_data_to_file(data, filename_prefix)
%
% INPUT PARAMETERS
%   data           : Quantized complex data to write (real and imaginary parts).
%   filename_prefix: Prefix for output files (e.g., 'output' for 'output.txt').
%
% OUTPUT FILES
%   <filename_prefix>.txt       : Text file with real and imaginary parts in CSV format.
%   <filename_prefix>_debug.txt : Debug text file with data in hexadecimal format.
%   <filename_prefix>.bin       : Binary file with interleaved real and imaginary values.
%
% DETAILS
%   This function takes quantized complex data, splits it into real and
%   imaginary parts, and writes them in various formats for further processing.
%   Ensure data has been quantized prior to calling this function. An internal
%   check will warn if data appears unquantized.
%
% REVISIT
%   Consider adding an option to handle automatic quantization.
%
% EXAMPLES
%   write_complex_data_to_file(data, 'output', 16)

function write_complex_data_to_file(data, filename_prefix)

  % Check if data has already been quantized
  if ~all(mod(real(data), 1) == 0) || ~all(mod(imag(data), 1) == 0)
    warning('Data may not be quantized. Please quantize data before calling this function.');
  end

  % Split complex data into real and imaginary parts
  real_part = fix(real(data));
  imag_part = fix(imag(data));

  % Reshape data to interleave real and imaginary parts for binary output
  combined = vertcat(real_part, imag_part);
  combined = combined(:);

  %============================================================================
  % Write to TXT file
  filename_txt = [filename_prefix, '.txt'];
  fid_txt = fopen(filename_txt, 'w');
  if fid_txt == -1
    error('Failed to open %s for writing.', filename_txt);
  end
  len = length(data);
  for j = 1:len
      fprintf(fid_txt, '%d,%d\n', real_part(j), imag_part(j));
  end
  fclose(fid_txt);
  disp(['Saved to ', filename_txt]);

  %============================================================================
  % Write to TXT debug file (hexadecimal format)
  filename_debug_txt = [filename_prefix, '_debug.txt'];
  fid_debug_txt = fopen(filename_debug_txt, 'w');
  if fid_debug_txt == -1
    error('Failed to open %s for writing.', filename_debug_txt);
  end
  for j = 1:len
      fprintf(fid_debug_txt, '%s\n', dec2hex(imag_part(j) * 2^16 + real_part(j)));
  end
  fclose(fid_debug_txt);
  disp(['Saved to ', filename_debug_txt]);

  %============================================================================
  % Write to BIN file (interleaved real and imaginary parts)
  filename_bin = [filename_prefix, '.bin'];
  fid_bin = fopen(filename_bin, 'w');
  if fid_bin == -1
    error('Failed to open %s for writing.', filename_bin);
  end
  fwrite(fid_bin, combined, 'int16');
  fclose(fid_bin);
  disp(['Saved to ', filename_bin]);
end
