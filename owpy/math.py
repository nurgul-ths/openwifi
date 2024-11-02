"""
Mathematical utility functions for signal processing applications, complementing NumPy,
SciPy, and the standard math package.

This module provides specialized functions for:
- Decibel conversions
- Fixed-point arithmetic operations
- Data representation analysis
"""

import numpy as np

#------------------------------------------------------------------------------
# Decibels
#------------------------------------------------------------------------------

def magnitude_to_db(magnitude):
  """Converts magnitude to decibels."""
  return 20 * np.log10(magnitude)

def db_to_magnitude(db):
  """Converts decibels to magnitude."""
  return 10**(db / 20)

def power_to_db(power):
  """Converts power to decibels."""
  return 10 * np.log10(power)

def db_to_power(db):
  """Converts decibels to power."""
  return 10**(db / 10)

def power_array(array):
  """Calculates the average power of an array."""
  return (np.mean(np.abs(array)**2))

def power_array_db(array):
  """Calculates the average power of an array in dB"""
  return power_to_db(power_array(array))

#------------------------------------------------------------------------------
# Fixed-point
#------------------------------------------------------------------------------

def fixed_point_signed_min_max(n_int, n_frac):
  """Returns the minimum and maximum values for a signed fixed-point number."""
  min_val = -2**(n_int - 1)
  max_val =  2**(n_int - 1) - 2**(-n_frac) # Step size is 2**(-n_frac)
  return min_val, max_val


def fixed_point_min_max(n_int, n_frac):
  """Returns the minimum and maximum values for an unsigned fixed-point number."""
  min_val = 0
  max_val = 2**(n_int) - 2**(-n_frac)
  return min_val, max_val


def convert_to_unsigned(value, bitwidth):
  """
  Convert a signed integer to its unsigned representation using two's complement notation.

  The conversion is based on the principle of two's complement notation:
  1. Positive numbers remain the same in both signed and unsigned representations.
  2. Negative numbers are represented by the bit pattern that would result if one took
     the positive version of the number, complemented all the bits (changed zeros to ones
     and ones to zeros), and then added one to the result.

  For example, for a `bitwidth` of 8 (an 8-bit number):

  To represent `-1` in two's complement:
  1. Represent `1` in binary: `00000001`
  2. Complement all the bits: `11111110`
  3. Add one: `11111111`

  Thus, `-1` is represented as `11111111` in two's complement notation. When treated as
  an unsigned integer, `11111111` is equal to `255`. This function converts `-1` to `255`
  using the formula: value + 2**bitwidth. Same with `-2` and `11111110` where -2 + 2**8 = 254.

  Args:
    value (int): The signed integer value to convert.
    bitwidth (int): The bit width of the integer representation.

  Returns:
      int: The unsigned representation of the signed integer.
  """
  if value < 0:
    return value + 2**bitwidth
  else:
    return value


def required_bits_to_represent(data):
  """
  Calculate the number of bits required to represent data in two's complement.

  Args:
    data (ndarray): Data array.

  Returns:
    int: Number of bits required to represent data.
  """
  # Get the maximum absolute value from data
  max_abs_value = np.max(np.abs(data))

  # Calculate the number of bits required
  return np.ceil(np.log2(max_abs_value)) + 1
