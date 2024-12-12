"""Main function for running an experiment for collecting CSI or I/Q samples
"""

import time
import shutil

from owpy.apps.capture_iq_app_udp import iq_capture_app_udp
from owpy.apps.misc import print_sampling_time
from owpy.files.files import gen_fnames, gen_data_dir
from owpy.openwifi.control_setup import init_openwifi, setup_openwifi, inject_openwifi, side_ch_openwifi
from owpy.files.files import *
from owpy.openwifi.control_sysfs import sysfs_get_rx_gain, sysfs_get_rf_tx_atten


def run_capture(params):
  """Runs the capture functions for CSI, I/Q, Neulog, and control of CNC machines

  Args:
    params (argparse.ArgumentParser): Object with parameters
  """

  if not params.openwifi_enable:
    raise ValueError("OpenWiFi is not enabled, cannot run capture")

  if params.sampling_delay > 0:
    print(f"\nWaiting {params.sampling_delay} seconds to start\n")
    time.sleep(params.sampling_delay)

  print_sampling_time(params.sampling_time)

  iq_capture_app_udp(params)

  print("\nData collection finished\n")

  if params.save_data:
    print(f"\nExperiment data have been saved to {params.fname_base}")


def run(params):
  """
  Main run function for collecting CSI or I/Q samples

  Args:
    params (argparse.ArgumentParser): Object with parameters
  """

  print(f"Runing capture with action {params.action}")

  #=============================================================================
  # Check settings
  #=============================================================================

  if params.check_settings:
    user_input = input("Continue with these settings [y/n]? ")
    if user_input.lower() not in ['y', 'yes']:
      return

    user_input = input("Reconfigure openwifi board with these settings (if not in setup mode)? [y/n]? ")
    if user_input.lower() in ['y', 'yes']:
      setup_openwifi(params)

  if params.action is None:
    params.action = input("Which action? Normally do order [init, setup, side_ch, inject, run]? ")

  #=============================================================================
  # Run the action
  #=============================================================================
  if params.action == "init":
    init_openwifi(params)
  elif params.action == "setup":
    setup_openwifi(params)
  elif params.action == "inject":
    inject_openwifi(params)
  elif params.action == "side_ch":
    side_ch_openwifi()
  else:

    #=============================================================================
    # Check that we have the correct gain settings saved
    #================================================================

    # Ensure that the gain is set to the correct value, this might change due to other processes
    # This has to happen after setup otherwise it's not possible to read this
    params.rf_rx0_gain  = sysfs_get_rx_gain(0)
    params.rf_rx1_gain  = sysfs_get_rx_gain(1)
    params.rf_tx0_atten = sysfs_get_rf_tx_atten(0)
    params.rf_tx1_atten = sysfs_get_rf_tx_atten(1)
    gen_fnames(params)
    gen_data_dir(params)

    #===========================================================================
    # Copy over the TX data file if we get 2 RX
    #===========================================================================
    if params.data_type == "rx_iq0_iq1" and params.save_data:

      # Define the source and destination paths for the TX data file
      tx_file_source    = os.path.join("scripts_openwifi/arbitrary_iq_gen/data_gen/output", params.iqa_fname)
      tx_file_real_dest = f"{params.fname_base}_{TX_IQ0_REAL}.csv"
      tx_file_imag_dest = f"{params.fname_base}_{TX_IQ0_IMAG}.csv"

      tx_file_source_real = f"{tx_file_source}_{TX_IQ0_REAL}.csv"
      tx_file_source_imag = f"{tx_file_source}_{TX_IQ0_IMAG}.csv"

      # Copy the TX file to the destination paths
      try:
        shutil.copyfile(tx_file_source_real, tx_file_real_dest)
        shutil.copyfile(tx_file_source_imag, tx_file_imag_dest)
        print(f"Copied TX data file to {tx_file_real_dest} and {tx_file_imag_dest}")
      except FileNotFoundError:
        print(f"TX data file {tx_file_source} not found")
      except Exception as e:
        print(f"Error copying TX data file: {e}")

    #===========================================================================
    # Run the capture
    #===========================================================================

    run_capture(params)
