"""
Functions to assist with logging statistical details of complex-valued data.

This module focuses on detailed statistical logging but will only perform the
expensive computations when the logger is set to DEBUG level.
"""

import numpy as np
import inspect

from owpy.math import required_bits_to_represent, power_to_db

def log_complex_data_statistics(data, label, logger):
  """
  Log detailed statistics of a complex data array at DEBUG level.

  This function will:
  - Retrieve the caller function's name for better traceability in the logs.
  - Compute and log various statistics of the complex data (real/imag parts, magnitudes, powers, phases).
  - Determine the number of bits required to represent the data.
  - Check for overflows relative to the computed bit depth.

  **Important:**
  All the computations and logging in this function are only performed if the logger level is set to DEBUG.
  For levels INFO, WARNING, ERROR, or CRITICAL, this function returns immediately, avoiding unnecessary overhead.

  Logging levels (for reference):
    - DEBUG (10): Detailed information, intended for diagnosing issues.
    - INFO (20): Confirm that things are working as expected.
    - WARNING (30): Something unexpected happened or an issue might occur soon.
    - ERROR (40): A problem occurred that prevented some functionality.
    - CRITICAL (50): A serious error occurred, possibly requiring immediate attention.

  Args:
    data (np.ndarray): Complex data array.
    label (str): Identifier for the data in the logs.
    logger (logging.Logger): Logger instance to write log messages to.
  """

  # Only proceed if the logger level is DEBUG (which is 10 or lower).
  # If logger.level > logging.DEBUG (i.e., > 10), return immediately.
  if logger.level > 10:
    return

  # Log caller function for better debugging context
  caller_function = inspect.stack()[1].function
  logger.debug("Caller function: %s", caller_function)
  logger.debug("%s.shape: %s", label, data.shape)

  # Flatten the data for uniform processing
  data = data.flatten()

  # Determine indices for extremal values in real, imag, and magnitude domains
  real_max_idx = np.argmax(data.real)
  real_min_idx = np.argmin(data.real)
  imag_max_idx = np.argmax(data.imag)
  imag_min_idx = np.argmin(data.imag)
  mag_max_idx  = np.argmax(np.abs(data))
  mag_min_idx  = np.argmin(np.abs(data))

  # Log extremal values for real, imag, and magnitude
  logger.debug("%s.real max: %s at index %s", label, data.real[real_max_idx], real_max_idx)
  logger.debug("%s.real min: %s at index %s", label, data.real[real_min_idx], real_min_idx)
  logger.debug("%s.imag max: %s at index %s", label, data.imag[imag_max_idx], imag_max_idx)
  logger.debug("%s.imag min: %s at index %s", label, data.imag[imag_min_idx], imag_min_idx)
  logger.debug("%s max magnitude: %s at index %s", label, np.abs(data[mag_max_idx]), mag_max_idx)
  logger.debug("%s min magnitude: %s at index %s", label, np.abs(data[mag_min_idx]), mag_min_idx)

  # Standard deviation of the complex data
  logger.debug("%s standard deviation: %s", label, np.std(data))

  # Compute and log power-related statistics
  power = np.abs(data)**2
  mean_power = np.mean(power)
  logger.debug("%s mean power: %s", label, mean_power)
  logger.debug("%s mean power (dB): %s", label, power_to_db(mean_power))
  logger.debug("%s max power: %s at index %s", label, power[mag_max_idx], mag_max_idx)
  logger.debug("%s max power (dB): %s at index %s", label, power_to_db(power[mag_max_idx]), mag_max_idx)

  # Minimum power check (avoid log of zero)
  if np.abs(data[mag_min_idx]) != 0:
    logger.debug("%s min power: %s at index %s", label, power[mag_min_idx], mag_min_idx)
    logger.debug("%s min power (dB): %s at index %s", label, power_to_db(power[mag_min_idx]), mag_min_idx)

  # Phase-related statistics
  mean_phase = np.mean(np.angle(data))
  logger.debug("%s phase mean: %s rad", label, mean_phase)
  phase_max_idx = np.argmax(np.angle(data))
  phase_min_idx = np.argmin(np.angle(data))
  logger.debug("%s phase max: %s rad at index %s", label, np.max(np.angle(data)), phase_max_idx)
  logger.debug("%s phase min: %s rad at index %s", label, np.min(np.angle(data)), phase_min_idx)

  # Bit depth calculations for real and imaginary parts
  bits_data_real = required_bits_to_represent(data.real)
  bits_data_imag = required_bits_to_represent(data.imag)
  logger.debug("Bits required for real %s: %s", label, bits_data_real)
  logger.debug("Bits required for imag %s: %s", label, bits_data_imag)

  # Check for overflow relative to the computed bit depths
  overflow_real = np.any(np.abs(data.real) > 2**(bits_data_real - 1))
  overflow_imag = np.any(np.abs(data.imag) > 2**(bits_data_imag - 1))
  logger.debug("Overflow in %s.real: %s", label, overflow_real)
  logger.debug("Overflow in %s.imag: %s", label, overflow_imag)
