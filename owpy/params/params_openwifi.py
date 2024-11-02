"""Helper functions for passing arguments

Note that if you really should think about certain settings, it's best to not add defaults to them so they will always have to be set.

Note to keep the text concise and to the point:
- Write small help messages
- If you don't write a default it will always default to None
- You don't have to write a default in the help text, this is done automatically
- It is not necessary to write "--openwifi-enable", dest="openwifi_enable" in the add_argument function call this is done automatically

REVISIT:
- Add check for iq_len, I think there is some minimum size
"""

import argparse
from owpy.params.formatting import CustomFormatter
from owpy.params.checker_openwifi import (
    adjust_openwifi_rf_rx_gain,
    adjust_openwifi_bb_rx_gain,
    validate_openwifi_fft_window_shift,
    validate_openwifi_tx_ant,
    validate_openwifi_rx_ant,
    validate_openwifi_rf_atten_tx,
)

#==============================================================================
# Argument checker code
#==============================================================================

def get_attr_no_check_openwifi(params: argparse.Namespace) -> list[str]:
  """Check if some parameters are unset

  Args:
    params (argparse.Namespace): Parsed parameters.

  Returns:
    list[str]: List of OpenWiFi arguments that can be unset based on configuration.
  """

  # Extract all openwifi arguments using argparser_openwifi
  parser = argparser_openwifi()
  openwifi_args = [action.dest for action in parser._actions]

  # Return all arguments if openwifi is not enabled
  if not hasattr(params, 'openwifi_enable') or not params.openwifi_enable:
    return openwifi_args

  # Parameters allowed to remain unset based on specific conditions
  attrs_no_check = [
    'exp_descr', 'exp_fname_param_list', 'exp_fname_extra', 'beep',
    'iq0_start_pkt', 'iq1_start_pkt', 'frame_len', 'num_eq', 'verbose',
    'ref_file_name', 'label', 'room', 'location', 'ant_arrangement',
    'capture_file'
  ]

  if not hasattr(params, 'capture_mode') or params.capture_mode == 'udp':
    attrs_no_check.extend(['capture_mode'])

  if not hasattr(params, 'system_mode') or params.system_mode != 'jmb':
    attrs_no_check.extend(['data_type_jmb', 'tx_jmb_interrupt_init', 'tx_jmb_interrupt_src'])

  return attrs_no_check

# REVISIT: Add use of checker_openwifi.py
def check_attr_openwifi(params: argparse.Namespace):
  """Validate and adjust OpenWiFi-specific attributes in the params object.

  Adjusts OpenWiFi RF and BB gain settings and checks antenna and attenuation parameters.
  Validation errors will raise exceptions if parameters are incompatible.

  Args:
    params (argparse.Namespace): Parsed parameters.

  Raises:
    ValueError: If any validation fails.
  """

  adjust_openwifi_rf_rx_gain(params)
  adjust_openwifi_bb_rx_gain(params)

  validate_openwifi_tx_ant(params.tx_ant)
  validate_openwifi_rx_ant(params.rx_ant)
  validate_openwifi_fft_window_shift(params.fft_window_shift)
  validate_openwifi_rf_atten_tx(params.rf_tx0_atten)
  validate_openwifi_rf_atten_tx(params.rf_tx1_atten)

  if params.verbose:
    print_gain_params(params)


def print_gain_params(params: argparse.Namespace):
  """
  Print gain settings for OpenWiFi RF and BB gain parameters for debugging.
  Note that in tx_iq_intf.v the data is divided by 2^7 after gain is applied.
  Signal is attenuated by params.rf_atten_tx, so -3 dB would mean half signal strength.
  """
  print("\nGain Settings")
  print(f"\tRF TX0 Gain (attenuation):\t-{params.rf_tx0_atten/1000} dB")
  print(f"\tRF TX1 Gain (attenuation):\t-{params.rf_tx1_atten/1000} dB")
  print(f"\tRF RX0 Gain:\t{params.rf_rx0_gain} dB")
  print(f"\tRF RX1 Gain:\t{params.rf_rx1_gain} dB")
  print(f"\tDigital TX Gain:\t{params.bb_tx_gain / 2**7}")
  print(f"\tDigital RX Gain:\t{2**(params.bb_rx_gain)}")


def process_params_openwifi(params: argparse.Namespace):
  """Process parameters to generate additional derived parameters based on initial inputs.

  REVISIT:
    Check settings on a board basis based on size. For example, `iq_len` constraint:
    For 4095, we get 4093 data because 2 is used for a header.
    if params.iq_len < 1:
      raise ValueError(f"Argument 'iq_len' must be greater than 0.")
  """
  pass


#==============================================================================
# Argument Parser for OpenWiFi
#==============================================================================

def argparser_openwifi(parser=None) -> argparse.ArgumentParser:
  """Define OpenWiFi-related arguments for the argparse parser.

  Args:
    parser (argparse.ArgumentParser, optional): Existing parser to add arguments to. Defaults to None.

  Returns:
    argparse.ArgumentParser: Argument parser with OpenWiFi-related arguments.
  """

  if parser is None:
    parser = argparse.ArgumentParser(
      prog='openwifi',
      description="Parameters for OpenWiFi configurations",
      formatter_class=CustomFormatter
    )

  #----------------------------------------------------------------------------
  # High-level settings
  #----------------------------------------------------------------------------
  parser.add_argument("--openwifi-enable", type=int, default=1, choices=[0,1], help="Enable OpenWiFi code.")
  parser.add_argument("--action", choices=["init", "setup", "inject", "side_ch", "run"], help="Experiment action.")
  parser.add_argument("--check-settings", type=int, default=0, choices=[0,1], help="Check settings before command.")
  parser.add_argument("--beep", type=int, default=0, choices=[0,1], help="Enable beep during data collection.")

  #----------------------------------------------------------------------------
  # Data file settings
  #----------------------------------------------------------------------------
  # Data save control
  parser.add_argument("--save-data", type=int, default=1, choices=[0,1], help="Enable data saving.")
  parser.add_argument("--save-raw", type=int, default=0, choices=[0,1], help="Enable raw data saving.")
  parser.add_argument("--save-log", type=int, default=1, choices=[0,1], help="Enable log data saving.")
  parser.add_argument("--exp-dir", type=str.lower, default="data/raw", help="Base directory to save data.")
  parser.add_argument("--exp-dataset", type=str.lower, help="Dataset name for data organization.")
  parser.add_argument("--exp-name", type=str.lower, help="Experiment name used in filenames.")
  parser.add_argument("--exp-fname-extra", type=str.lower, help="Additional text for filenames.")
  parser.add_argument("--exp-fname-param-list", type=str.lower, help="Space-separated list of filename parameters.")
  parser.add_argument("--exp-descr", type=str, help="Description for the experiment log (not filename).")

  #----------------------------------------------------------------------------
  # Capture mode and data handling
  #----------------------------------------------------------------------------
  parser.add_argument("--capture-mode", type=str.lower, default='udp', choices=['udp', 'file'], help="Data capture mode.")
  parser.add_argument("--capture-mode-file-manual", type=int, default=0, choices=[0, 1], help="Set to 1 for manual capture.")
  parser.add_argument("--capture-file", type=str.lower, help="Filename for data capture in file mode.")

  #----------------------------------------------------------------------------
  # Data set description settings
  #----------------------------------------------------------------------------
  parser.add_argument("--room", type=str, help="Room where the data is collected.")
  parser.add_argument("--location", type=str, help="Specific location within the room.")
  parser.add_argument("--label", type=str, help="Activity/pose/etc. descriptor.")

  #----------------------------------------------------------------------------
  # Experiment settings
  #----------------------------------------------------------------------------
  parser.add_argument("--sampling-time", type=int, help="Sampling time in seconds (-1 for infinite).")
  parser.add_argument("--sampling-delay", type=int, default=0, help="Delay before starting to sample.")

  #----------------------------------------------------------------------------
  # System configuration
  #----------------------------------------------------------------------------
  parser.add_argument("--board-name", type=str.lower, choices=['zed_fmcs2', 'zcu111'], help="Board name")

  # `system_mode`:
  #   - `monostatic`: TX and RX are on the same board
  #   - `bistatic`: TX and RX are on different boards
  #   - `jmb`: Joint mono-static and bi-static mode for both modes simultaneously.
  parser.add_argument("--system-mode", type=str.lower, choices=['monostatic', 'bistatic', 'jmb'], help="System mode.")

  # `data_type`:
  # We have many different data types based on collection needs.
  #   - `csi`: Capture frequency offset, CSI (real/imag), and equalizer (real/imag) data.
  #   - `rssi_rx_iq0`: Capture RSSI, AGC, and receive I/Q data from a selected antenna.
  #   - `rx_iq0_iq1`: Capture receive I/Q data from both RX antennas.
  #   - `tx_rx_iq0`: Capture transmitted and received I/Q data from a selected antenna.
  #   - `iq_all`: Capture transmitted and received I/Q data from both TX and RX antennas.
  parser.add_argument("--data-type", type=str.lower, choices=['csi', 'rssi_rx_iq0', 'rx_iq0_iq1', 'tx_rx_iq0', 'iq_all'], help="Data type.")

  # data_type_jmb: Options for joint mono-static/bi-static mode
  # - iq: Collects I/Q data for both transmitted and received packets.
  # - csi: Collects bistatic CSI and self-received I/Q data.
  parser.add_argument("--data-type-jmb", type=str, choices=['iq', 'csi'], help="Data type for jmb mode.")

  # `loop_type`:
  #   - `int`: Internal loopback.
  #   - `cabled`: Cabled loopback.
  #   - `air`: Over-the-air loopback.
  parser.add_argument("--loop-type", type=str.lower, choices=['int', 'cabled', 'air'], help="Loopback type.")

  parser.add_argument("--freq", type=int, help="Carrier frequency (MHz), or channel if <2000.")

  # Antenna settings
  parser.add_argument("--tx-ant", type=int, default=0, choices=[0,1], help="TX antenna.")
  parser.add_argument("--rx-ant", type=int, default=0, choices=[0,1], help="RX antenna.")
  parser.add_argument("--ant-arrangement", type=str, help="TX/RX antenna arrangement, with distances in cm.")

  # CDD (Cyclic Delay Diversity) and dual TX antenna options
  parser.add_argument("--cdd-en", type=int, default=0, choices=[0,1], help="Enable cyclic diversity on TX1.")
  parser.add_argument("--tx-ant-dual-en", type=int, default=0, choices=[0,1], help="Enable both TX antennas.")
  parser.add_argument("--spi-en", type=int, default=0, choices=[0,1], help="SPI status (must be 0 for TX LO).")

  #----------------------------------------------------------------------------
  # I/Q capture settings
  #----------------------------------------------------------------------------
  parser.add_argument("--trigger-src", type=int, default=3, help="Trigger source for I/Q capture.")
  parser.add_argument("--iq-len", type=int, default=4093, help="I/Q capture length. Max 4095 for Zedboard.")
  parser.add_argument("--pre-trigger-len", type=int, default=0, help="Pre-trigger length in samples.")
  parser.add_argument("--side-ch-interrupt-init", type=int, default=1, help="Initialize side channel interrupt.")

  #----------------------------------------------------------------------------
  # CSI capture settings
  #----------------------------------------------------------------------------
  parser.add_argument("--ch-smooth-en", type=int, default=0, choices=[0,1], help="Enable channel smoothing.")
  parser.add_argument("--fft-window-shift", type=int, default=1, help="FFT window shift (register bits3-0).")

  #----------------------------------------------------------------------------
  # Frame control (FC) matching
  #----------------------------------------------------------------------------
  parser.add_argument("--fc-match", type=int, default=0, help="Enable frame control matching.")
  parser.add_argument("--addr1-match", type=int, help="Target address to match (greater than 1).")
  parser.add_argument("--addr2-match", type=int, help="Source address to match (greater than 1).")

  #----------------------------------------------------------------------------
  # Joint mono-static and bi-static settings
  #----------------------------------------------------------------------------
  parser.add_argument("--tx-jmb-interrupt-init", type=int, default=0, help="Enable JMB TX interrupt.")
  parser.add_argument("--tx-jmb-interrupt-src", type=int, default=1, choices=[0,1,2,3,4], help="JMB TX interrupt source.")

  #----------------------------------------------------------------------------
  # Gain settings
  #----------------------------------------------------------------------------
  parser.add_argument("--rf-tx0-atten", type=float, default=-89.75, help="RF TX0 attenuation in 1/1000 dB.")
  parser.add_argument("--rf-tx1-atten", type=float, default=-89.75, help="RF TX1 attenuation in 1/1000 dB.")
  parser.add_argument("--rf-rx0-gain", type=int, help="RF RX0 gain (0-71 dB).")
  parser.add_argument("--rf-rx1-gain", type=int, help="RF RX1 gain (0-71 dB).")
  parser.add_argument("--bb-tx-gain", type=int, default=256, help="Baseband TX gain (scaled).")
  parser.add_argument("--bb-rx-gain", type=int, default=0, choices=[0,1,2,3], help="Baseband RX gain (scaled).")

  #----------------------------------------------------------------------------
  # Packet-related settings
  #----------------------------------------------------------------------------
  parser.add_argument("--bb-start-pkt", type=int, help="Index of baseband packet start.")
  parser.add_argument("--rx-start-pkt", type=int, help="Index of RX packet start.")
  parser.add_argument("--frame-len", type=int, help="Frame length from received I/Q data.")

  #----------------------------------------------------------------------------
  # Script settings
  #----------------------------------------------------------------------------
  parser.add_argument("--num-eq", type=int, default=0, help="Number of equalizer outputs (0-8).")

  #----------------------------------------------------------------------------
  # Miscellaneous settings
  #----------------------------------------------------------------------------
  parser.add_argument("--verbose", type=int, default=0, help="Enable verbose mode.")

  return parser
