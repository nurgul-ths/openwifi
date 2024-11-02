"""Functions for setting up the board
"""

import subprocess
from owpy.openwifi.ssh import SSHClient
from owpy.misc import frequency_to_channel, channel_to_frequency
from owpy.openwifi.misc import is_openwifi_board
from owpy.openwifi.control_registers import write_register


def init_openwifi(params):
  """Setup the OpenWiFi board with experiment parameters"""

  try:
    wifi_ch = frequency_to_channel(params.freq) if params.freq > 2000 else params.freq
    manual_ch = False

  except ValueError as e:
    print(e)
    # We need to use a manual one
    wifi_ch   = 1 # Just use a default channel
    manual_ch = True

  if params.system_mode == 'monostatic':
    ssh_cmd = f"ssh root@192.168.10.122 'bash -s' < scripts/capture/setup_wgd_monitor.sh {wifi_ch}"
  else: # bistatic and jmb
    ssh_cmd = f"ssh root@192.168.10.122 'bash -s' < scripts/capture/setup_wgd_ap.sh {wifi_ch}"

  print(ssh_cmd)
  subprocess.run(ssh_cmd, shell=True, check=False)

  # Now, sewt manual if need be
  if manual_ch:
    val = params.freq
    if int(val) < 1000:
      freq_mhz = channel_to_frequency(int(val))
    else:
      freq_mhz = int(val)

    write_register('rf', 1, freq_mhz)
    write_register('rf', 5, freq_mhz)


def setup_openwifi(params, verbose=1):
  """
  Setup the OpenWiFi board with experiment parameters.
  Please consider rebooting the board before running this.
  """

  # Map out the parameters
  scripts_with_params = {
    "set_misc.sh"        : f"{params.fft_window_shift}",
    "set_loopback.sh"    : f"{params.board_name} {params.system_mode} {params.loop_type} {params.tx_ant} {params.rx_ant} {params.cdd_en} {params.spi_en}",
    "set_gains.sh"       : f"{params.board_name} {params.system_mode} {params.data_type} {params.loop_type} {params.rx_ant} {params.cdd_en} {params.tx_ant_dual_en} {params.rf_tx0_atten} {params.rf_tx1_atten} {params.rf_rx0_gain} {params.rf_rx1_gain} {params.bb_tx_gain} {params.bb_rx_gain}",
    "set_side_ch.sh"     : f"{params.system_mode} {params.data_type} {params.data_type_jmb} {params.num_eq} {params.side_ch_interrupt_init} {params.iq_len}",
    "set_capture_iq.sh"  : f"{params.system_mode} {params.data_type} {params.data_type_jmb} {params.loop_type} {params.trigger_src} {params.iq_len} {params.pre_trigger_len} {params.tx_jmb_interrupt_init} {params.tx_jmb_interrupt_src}",
    "set_capture_csi.sh" : f"{params.system_mode} {params.data_type} {params.data_type_jmb} {params.ch_smooth_en} {params.fc_match} {params.addr1_match} {params.addr2_match}"
  }

  # SSH command prefix (path to where the scripts are located)
  ssh_prefix = "ssh root@192.168.10.122 'bash -s' < scripts/capture/"

  # Commands to call individual scripts with the necessary parameters
  # The scripts should be called in the order of the list
  # 1. set_misc.sh
  # 2. set_loopback.sh
  # 3. set_gains.sh
  # 4. set_side_ch.sh (if not called before set_capture_*.sh, we can't actually write to the registers)
  # 5. set_capture_*.sh
  scripts_to_run = ["set_gains.sh", "set_misc.sh", "set_loopback.sh", "set_side_ch.sh"]

  # Depending on the data type, call the appropriate capture setup script
  if params.data_type == 'csi' or (params.system_mode == 'jmb' and params.data_type_jmb == 'csi'):
    scripts_to_run.append("set_capture_csi.sh")

  if params.data_type != 'csi' or params.system_mode == 'jmb':
    scripts_to_run.append("set_capture_iq.sh")

  # Execute scripts_to_run
  for script_name in scripts_to_run:
    args = scripts_with_params[script_name]
    ssh_cmd = f"{ssh_prefix}{script_name} {args}"
    print(ssh_cmd)
    subprocess.run(ssh_cmd, shell=True, check=False)


def inject_openwifi(params, verbose = 1):
  """Run the packet injection on the OpenWiFi board"""

  ssh_cmd = f"ssh root@192.168.10.122 \'cd openwifi && ./inject_80211/inject_80211 -m n -r {params.pinj_r} -n {params.pinj_n} -s {params.pinj_s} -p {params.pinj_p} -d {params.pinj_d} sdr0\'"

  if verbose:
    print(ssh_cmd)
    print("Press Ctrl+C to exit (if you change packet injection parameters)")

  subprocess.run(ssh_cmd, shell=True, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def inject_openwifi_single(params, verbose = 0):
  """Run the packet injection on the OpenWiFi board but just 1 packet"""

  ssh_cmd = f"ssh root@192.168.10.122 \'cd openwifi && ./inject_80211/inject_80211 -m n -r {params.pinj_r} -n {1} -s {params.pinj_s} -p {params.pinj_p} -d {params.pinj_d} sdr0\'"

  if verbose:
    print(ssh_cmd)

  subprocess.run(ssh_cmd, shell=True, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def side_ch_openwifi(verbose = 1):
  """Run the side channel capture on the OpenWiFi board"""

  ssh_cmd = "ssh root@192.168.10.122 'cd openwifi && ./side_ch_ctl g0'"

  if verbose:
    print(ssh_cmd)
    print("Press Ctrl+C to exit (if done collecting samples)")

  subprocess.run(ssh_cmd, shell=True, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
