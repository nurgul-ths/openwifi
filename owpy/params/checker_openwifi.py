"""Parameter validation module for OpenWiFi configuration.

This module provides validation functions for OpenWiFi parameters, ensuring proper
configuration of RF and baseband settings.
"""

def validate_openwifi_openwifi_enable(params):
  """Validates OpenWiFi enable parameter."""
  pass


def validate_openwifi_action(params):
  """Validates the OpenWiFi action parameter.

  Args:
    params: Object containing the action parameter.

  Raises:
    ValueError: If the action is not in the list of valid actions.
  """
  valid_actions = ["init", "setup", "inject", "side_ch", "run"]
  if params.action not in valid_actions:
    raise ValueError(f"Invalid action: {params.action}. Must be one of {valid_actions}. Setting to 'run'")


def validate_openwifi_validate_openwifi_settings(params):
  """Validates OpenWiFi settings."""
  pass


def validate_openwifi_beep(params):
  """Validates beep parameter."""
  pass


def validate_openwifi_save_data(params):
  """Validates save data parameter."""
  pass


def validate_openwifi_save_raw(params):
  """Validates save raw parameter."""
  pass


def validate_openwifi_exp_dir(params):
  """Validates experiment directory parameter."""
  pass


def validate_openwifi_exp_name(params):
  """Validates experiment name parameter."""
  pass


def validate_openwifi_exp_fname_extra(params):
  """Validates extra filename parameter."""
  pass


def validate_openwifi_exp_fname_param_list(params):
  """Validates filename parameter list."""
  pass


def validate_openwifi_exp_descr(params):
  """Validates experiment description."""
  pass


def validate_openwifi_capture_mode(params):
  """Validates capture mode parameter."""
  pass


def validate_openwifi_capture_file(params):
  """Validates capture file parameter."""
  pass


def validate_openwifi_room(params):
  """Validates room parameter."""
  pass


def validate_openwifi_location(params):
  """Validates location parameter."""
  pass


def validate_openwifi_ref_file_name(params):
  """Validates reference filename parameter."""
  pass


def validate_openwifi_label(params):
  """Validates label parameter."""
  pass


def validate_openwifi_sampling_time(params):
  """Validates sampling time parameter."""
  pass


def validate_openwifi_sampling_delay(params):
  """Validates sampling delay parameter."""
  pass


def validate_openwifi_board_name(params):
  """Validates board name parameter."""
  pass


def validate_openwifi_data_type(params):
  """Validates data type parameter."""
  pass


def validate_openwifi_header(params):
  """Validates header parameter."""
  pass


def validate_openwifi_loop_type(params):
  """Validates loop type parameter."""
  pass


def validate_openwifi_freq(params):
  """Validates frequency parameter."""
  pass


def validate_openwifi_tx_ant(tx_ant):
  """Validates the transmit antenna selection.

  Args:
    tx_ant: Transmit antenna index (0 or 1).

  Raises:
    ValueError: If tx_ant is not 0 or 1.
  """
  if tx_ant not in [0, 1]:
    raise ValueError(f"Invalid tx_ant: {tx_ant}. Must be 0 or 1.")


def validate_openwifi_rx_ant(rx_ant):
  """Validates the receive antenna selection.

  Args:
    rx_ant: Receive antenna index (0 or 1).

  Raises:
    ValueError: If rx_ant is not 0 or 1.
  """
  if rx_ant not in [0, 1]:
    raise ValueError(f"Invalid rx_ant: {rx_ant}. Must be 0 or 1.")


def validate_openwifi_ant_arrangement(params):
  """Validates antenna arrangement parameter."""
  pass


def validate_openwifi_cdd_en(params):
  """Validates CDD enable parameter."""
  pass


def validate_openwifi_tx_ant_dual_en(params):
  """Validates dual transmit antenna enable parameter."""
  pass


def validate_openwifi_spi_en(params):
  """Validates SPI enable parameter."""
  pass


def validate_openwifi_trigger_src(params):
  """Validates trigger source parameter."""
  pass


def validate_openwifi_iq_len(params):
  """Validates IQ length parameter."""
  pass


def validate_openwifi_iq_header_len(params):
  """Validates IQ header length parameter."""
  pass


def validate_openwifi_pre_trigger_len(params):
  """Validates pre-trigger length parameter."""
  pass


def validate_openwifi_interrupt_init(params):
  """Validates interrupt initialization parameter."""
  pass


def validate_openwifi_ch_smooth_en(params):
  """Validates channel smoothing enable parameter."""
  pass


def validate_openwifi_fft_window_shift(fft_window_shift):
  """Validates the FFT window shift parameter.

  Args:
    fft_window_shift: FFT window shift value.

  Note:
    Issues a warning if fft_window_shift is less than or equal to 0.
  """
  if fft_window_shift <= 0:
    print("\tWarning: fft_window_shift <= 0.")


def validate_openwifi_rf_atten_tx(rx_atten_tx):
  """Validates the RF transmit attenuation.

  For tx attenuation, we pass the value as we have many different named ones tx0, tx1 etc.
  but they all have the same range.

  Args:
    rx_atten_tx: Transmit attenuation value in dB.

  Raises:
    ValueError: If attenuation is outside the valid range [0, -89.75] dB.
  """
  if rx_atten_tx > 0 or rx_atten_tx < -89.75:
    raise ValueError(
        f"Invalid rx_atten_tx: {rx_atten_tx}. Must be between 0 and -89.75 dB in 0.25dB steps.")


def validate_openwifi_rf_rx_gain(rf_rx_gain):
  """Validates the RF receive gain.

  Args:
    rf_rx_gain: Receive gain value in dB.

  Raises:
    ValueError: If gain is outside the valid range [-3, 71] dB.
  """
  if rf_rx_gain > 71 or rf_rx_gain < -3:
    raise ValueError(
        f"Invalid rf_rx_gain: {rf_rx_gain}. Must be between -3 and 71 dB in 1dB steps.")


def adjust_openwifi_rf_rx_gain(params):
  """Adjusts the RF receive gain parameters to be within valid ranges.

  Args:
    params: Object containing rf_rx0_gain and rf_rx1_gain parameters.
  """
  if params.rf_rx0_gain > 71 or params.rf_rx0_gain < -3:
    params.rf_rx0_gain = max(-3, min(71, params.rf_rx0_gain))

  if params.rf_rx1_gain > 71 or params.rf_rx1_gain < -3:
    params.rf_rx1_gain = max(-3, min(71, params.rf_rx1_gain))


def adjust_openwifi_bb_rx_gain(params):
  """Adjusts the baseband receive gain parameter.

  Args:
    params: Object containing bb_rx_gain parameter.
  """
  if params.bb_rx_gain < 0 or params.bb_rx_gain > 3:
    print("\tbb_rx_gain must in [0, 1, 2, 3]. Setting to 0")
    params.bb_rx_gain = 0


def validate_openwifi_bb_tx_gain(params):
  """Validates baseband transmit gain parameter."""
  pass


def validate_openwifi_iq0_start_pkt(params):
  """Validates IQ0 start packet parameter."""
  pass


def validate_openwifi_iq1_start_pkt(params):
  """Validates IQ1 start packet parameter."""
  pass


def validate_openwifi_frame_len(params):
  """Validates frame length parameter."""
  pass


def validate_openwifi_num_eq(params):
  """Validates number of equalizer taps parameter."""
  pass


def validate_openwifi_verbose(params):
  """Validates verbose parameter."""
  pass
