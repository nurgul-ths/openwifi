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
  parser        = argparser_openwifi()
  openwifi_args = [action.dest for action in parser._actions]

  # Return all arguments if openwifi is not enabled
  if not hasattr(params, 'openwifi_enable') or not params.openwifi_enable:
    return openwifi_args

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


def print_gain_params(params):
  """
  Note that in tx_iq_intf.v the data is divided by 2^7 after gain is applied
  Signal is attenuated by params.rf_atten_tx so -3 dB would mean half signal strength
  """
  print("\nGain Settings")
  print(f"\tRF TX0 Gain (attenuation):\t-{params.rf_tx0_atten/1000} dB")
  print(f"\tRF TX1 Gain (attenuation):\t-{params.rf_tx1_atten/1000} dB")
  print(f"\tRF RX0 Gain:\t{params.rf_rx0_gain} dB")
  print(f"\tRF RX1 Gain:\t{params.rf_rx1_gain} dB")
  print(f"\tDigital TX Gain:\t{params.bb_tx_gain / 2**7}")
  print(f"\tDigital RX Gain:\t{2**(params.bb_rx_gain)}")


def process_params_openwifi(params):
  """Process the parameters to generate additional parameters"""
  pass

  # REVISIT: Checks on a board to board basis based on the size
  # For 4095, we get 4093 data because 2 is used for a header.
  # if params.iq_len < 1:
  #   raise ValueError(f"Argument 'iq_len' must be greater than 0.")


#==============================================================================
# Parameters
#==============================================================================

def argparser_openwifi(parser = None):

  if parser is None:
    parser = argparse.ArgumentParser(
      prog            = 'openwifi',
      description     = "Parameters for openwifi",
      formatter_class = CustomFormatter
    )

  #----------------------------------------------------------------------------
  # High-level settings settings
  #----------------------------------------------------------------------------
  parser.add_argument("--openwifi-enable", type=int, default=1, choices=[0,1], help="Enable openwifi code.")
  parser.add_argument("--action", choices=["init", "setup", "inject", "side_ch", "run"], help="Action for experiment.")
  parser.add_argument("--check-settings", type=int, default=0, choices=[0,1], help="Check settings before command.")
  parser.add_argument("--beep", type=int, default=0, choices=[0,1], help="Beep during data collection.")

  #----------------------------------------------------------------------------
  # Data file settings
  #----------------------------------------------------------------------------
  # Data save control
  parser.add_argument("--save-data", type=int, default=1, choices=[0,1], help="Save data.")
  parser.add_argument("--save-raw", type=int, default=0, choices=[0,1], help="Save raw data.")
  parser.add_argument("--save-log", type=int, default=1, choices=[0,1], help="Save log data.")
  # Data folders
  parser.add_argument("--exp-dir", type=str.lower, default="data/raw", help="Directory to save data.")
  parser.add_argument("--exp-dataset", type=str.lower, help="Name of a dataset. This helps separate data into different folders instead of mixing things.")
  parser.add_argument("--exp-name", type=str.lower, help="Name of experiment used as prefix for file names.")
  # Data file name
  parser.add_argument("--exp-fname-extra", type=str.lower, help="Extra text in file name after exp_name.")
  parser.add_argument("--exp-fname-param-list", type=str.lower, help="Parameters for experiment file name separated by spaces, e.g. 'rf_tx0_atten rf_rx_gain'")
  # Data text description
  parser.add_argument("--exp-descr", type=str, help="Descriptor for experiment in logfile (no effect on filename).")

  # Capture mode
  parser.add_argument("--capture-mode", type=str.lower, default='udp', choices=['udp', 'file'], help="Capture mode (udp | file).")
  parser.add_argument("--capture-mode-file-manual", type=int, default=0, choices=[0, 1], help="If 1, you have to copy the file yourself, for when the files are very large")
  parser.add_argument("--capture-file", type=str.lower, help="Capture file name when using --capture-mode=file. The file name is extracted from the board. This is used when we need to capture large amounts of data where simply running with UDP is not sufficient. The data is then post-processed to extract the relevant data. See script_process_side_ch_files.py")

  #----------------------------------------------------------------------------
  # Data set description settings
  #----------------------------------------------------------------------------
  parser.add_argument("--room", type=str, help="Room where the data is collected")
  parser.add_argument("--location", type=str, help="Location where the data is collected. Usually an indicator like pos 1")
  parser.add_argument("--label", type=str, help="Activity/pose/etc. descriptor")

  #----------------------------------------------------------------------------
  # Experiment settings
  #----------------------------------------------------------------------------
  parser.add_argument("--sampling-time", type=int, help="Sampling time in seconds (-1 for infinite).")
  parser.add_argument("--sampling-delay", type=int, default=0, help="Delay before starting to sample.")

  #----------------------------------------------------------------------------
  # Openwifi settings
  #
  # These get passed to the setup_openwifi function and thus need to be set
  #----------------------------------------------------------------------------

  parser.add_argument("--board-name", type=str.lower, choices=['zed_fmcs2', 'zcu111'], help="Board name")

  # system_mode:
  # - monostatic: TX and RX are on the same board
  # - bistatic: TX and RX are on different boards
  # - jmb: Joint monostatic and bistatic mode. This is a special mode where we can collect both mono-static and bi-static data at the same time.
  parser.add_argument("--system-mode", type=str.lower, choices=['monostatic', 'bistatic', 'jmb'], help="System mode.")
  # data_type:
  # We have many different data-types depending on what we are doing.
  # - csi: Capture freq_offset, CSI (real/imag), and equalizer (real/imag) data
  # - rssi_rx_iq0: Capture RSSI, AGC and receive I/Q (real/imag) data from selected antenna
  # - rx_iq0_iq1: Capture receive I/Q (real/imag) data from both RX antennas
  # - tx_rx_iq0: Capture transmitted and received I/Q (real/imag) data from selected antenna
  # - iq_all: Capture transmitted and received I/Q (real/imag) data from both TX and RX antennas. Note that here we will have a limit on the iq_len, we have to halve it. To make the space
  parser.add_argument("--data-type", type=str.lower, choices=['csi', 'rssi_rx_iq0', 'rx_iq0_iq1', 'tx_rx_iq0', 'iq_all'], help="Data type (csi | rssi_rx_iq0 | rx_iq0_iq1 | tx_rx_iq0).")
  parser.add_argument("--data-type-jmb", type=str, choices=['iq', 'csi'], help="If iq, will sample I/Q data based on params.data_type for both self-transmitted and received data. If csi, will collect transmitted (self-received) I/Q data and bistatic CSI instead of I/Q.")

  parser.add_argument("--loop-type", type=str.lower, choices=['int', 'cabled', 'air'], help="Loopback type (int | cabled | air).")
  parser.add_argument("--freq", type=int, help="Carrier frequency (MHz) or channel if < 2000. If number is less than 2000 then it is interpreted as a channel number.")

  parser.add_argument("--tx-ant", type=int, default=0, choices=[0,1], help="TX antenna.")
  parser.add_argument("--rx-ant", type=int, default=0, choices=[0,1], help="RX antenna.")

  parser.add_argument("--ant-arrangement", type=str, help="TX and RX antenna arrangement with distances in centimeter. Example: 'tx0:0 rx0:9' which indicates that we have an axis where tx0 is at 0cm and rx0 is 9cm apart. Could also do 'tx0:0 rx0:9 rx1:12'. We count from perspective which direction we want to send in.")
  # REVISIT: Add back the header len, for the moment it is not used but needed for calling stuff (when side_ch interrupt is not used)

  parser.add_argument("--cdd-en", type=int, default=0, choices=[0,1], help="Enable cyclic diversity on TX1.")
  parser.add_argument("--tx-ant-dual-en", type=int, default=0, choices=[0,1], help="Enable both TX antennas. This just ensures that the TX power is enabled for both antennas.")
  parser.add_argument("--spi-en", type=int, default=0, choices=[0,1], help="SPI status. Must be 0 for TX LO to be enabled.")

  #----------------------------------------------------------------------------
  # I/Q capture settings
  #----------------------------------------------------------------------------
  # REVISIT: iq_len + iq header length must be 4096 or less
  parser.add_argument("--trigger-src", type=int, default=3, help="Trigger source (0-31). Only used for I/Q data collection.") # See <https://github.com/open-sdr/openwifi/blob/master/doc/app_notes/iq.md>
  # REVISIT: Add check that iq-len + iq header length is not longer than max num DMA symbols which is 4096, that is why max is 4095 and not 4096 since they accounted for the 1
  parser.add_argument("--iq-len", type=int, default=4093, help="I/Q capture length. Max 4095 for Zedboard, 8187 for larger boards. Note that the max is 4095, so we need to subtract from this if we have more, say a header of 3")
  parser.add_argument("--pre-trigger-len", type=int, default=0, help="Pre-trigger length. At 0 capture TX packet directly with no leading 0s.")
  parser.add_argument("--side-ch-interrupt-init", type=int, default=1, help="If 1, load the side_ch block with interrupt enable. This will make the side_ch kernel use the HW trigger to read out the data. This is required for advanced modes (multistatic etc.)")

  #----------------------------------------------------------------------------
  # CSI capture settings
  #----------------------------------------------------------------------------
  parser.add_argument("--ch-smooth-en", type=int, default=0, choices=[0,1], help="Channel smoothing enable.")
  parser.add_argument("--fft-window-shift", type=int, default=1, help="FFT window shift. See bits3-0 of slave register 5 in openofdm_rx block.")

  # For FC match, for example, FC0208 means type data, subtype data, to DS 0, from DS 1 (a packet from AP to client)
  # https://github.com/open-sdr/openwifi/blob/master/doc/README.md
  # https://en.wikipedia.org/wiki/802.11_frame_types
  parser.add_argument("--fc-match", type=int, default=0, help="If 1, turns on FC match.")
  # When in monitor mode, if we only want to capture say our own packets, we use addr2_match=0x44332202
  # If talking to another device, My laptop MAC is 30:03:c8:cb:a8:d3, so set the source (as we already see target from data_type_jmb)
  # REVISIT: Add address matching here (can get this from wgd script as a test)
  # or maybe if this script is running locally on the board we can grab it ourselves actually?
  # REVISIT: That might be the smartest
  # (Turn on addr2 source address only match)
  # REVISIT: Add mode here for like monitor or self.
  # https://github.com/open-sdr/openwifi/blob/master/doc/app_notes/csi.md
  #
  # mac_address=$(ip link show sdr0 | awk '/ether/ {print $2}')
  # ./side_ch_ctl wh7h$(echo $mac_address | tr -d ':')
  #
  parser.add_argument("--addr1-match", type=int, default=0, help="If greater than 1, this indicates the target address to match.")
  parser.add_argument("--addr2-match", type=int, default=0, help="If greater than 1, this indicates the source address to match.")

  # REVISIT: Add some address control (later)

  #----------------------------------------------------------------------------
  # Joint mono-static and bi-static settings
  #----------------------------------------------------------------------------

  # We need to set the interrupts for the tx and side_ch block, for the tx, we need to set the source
  # Note that the interrupts for this won't be used unless we enable from registers RF_MONOSTATIC_IDX_GAIN and RF_BISTATIC_IDX_GAIN
  # The kernel driver will trigger, but not do anything if they have not been enabled.
  # REVISIT: Maybe just always enable? You anyway don't use it if you don't enable it in the driver
  parser.add_argument("--tx-jmb-interrupt-init", type=int, default=0, help="If 1, enable in hardware the TX interrupt for the joint monostatic and bistatic mode")
  parser.add_argument("--tx-jmb-interrupt-src", type=int, default=1, choices=[0,1,2,3,4], help="0=s00_axis_tlast, 1=phy_tx_start, 2=tx_start_from_acc, 3=tx_end_from_acc, 4=tx_try_complete")

  #----------------------------------------------------------------------------
  # Openwifi gain settings
  #----------------------------------------------------------------------------
  parser.add_argument("--rf-tx0-atten", type=float, default=-89.75, help="RF TX0 attenuation in 1/1000 dB.")
  parser.add_argument("--rf-tx1-atten", type=float, default=-89.75, help="RF TX1 attenuation in 1/1000 dB.")
  parser.add_argument("--rf-rx0-gain", type=int, help="RF RX0 gain dB (range 0-71).")
  parser.add_argument("--rf-rx1-gain", type=int, help="RF RX1 gain dB (range 0-71).")
  parser.add_argument("--bb-tx-gain", type=int, default=256, help="Digital TX gain (scaled bb_tx_gain / 128 in HW).")
  parser.add_argument("--bb-rx-gain", type=int, default=0, choices=[0,1,2,3], help="Digital RX gain (scaled data*2^bb_rx_gain).")

  #----------------------------------------------------------------------------
  # Packet misc settings
  #----------------------------------------------------------------------------
  parser.add_argument("--bb-start-pkt", type=int, help="Index of BB packet start (usually). Useful for aligning BB and RX data or segmenting data for power analysis etc.")
  parser.add_argument("--rx-start-pkt", type=int, help="Index of rx packet start (rx1 or tx0). Useful for aligning BB and RX data or segmenting data for power analysis etc.")
  parser.add_argument("--frame-len", type=int, help="Size of frame from received I/Q data. Used with bb_start_pkt and rx_start_pkt to extract frame subset")

  #----------------------------------------------------------------------------
  # Script settings
  #----------------------------------------------------------------------------
  parser.add_argument("--num-eq", type=int, default=0, help="Number of equalizer outputs (0-8).")

  #----------------------------------------------------------------------------
  # misc settings
  #----------------------------------------------------------------------------
  parser.add_argument("--verbose", type=int, default=0, help="Verbose mode.")

  return parser
