"""
This file contains the board command executioner. You just give input arguments and it executes commands on the boards.
For example, if you want to change the carrier frequencie etc. you can use this file, and it's all done in one file that
has a nice overview of all the commands that can be executed on the boards.

This is also a great way of documenting the commands that can be executed on the boards.

The final execution of the commands is done from

For exaple

python board_cmd_exec.py --cmd set_carrier_frequency --args 2412

or with multiple arguments

python board_cmd_exec.py --cmd set_dac_intf_filter_mode --args sample_noise
"""

import argparse
from owpy.openwifi.ssh import SSHClient

from owpy.openwifi.control_registers import write_register, read_register
from owpy.openwifi.control_sysfs import sysfs_get_rx_gain, sysfs_set_rf_rx_gain, sysfs_get_rf_tx_atten, sysfs_set_rf_tx_atten, sysfs_set_rf_gain_control_mode

from owpy.misc import frequency_to_channel, channel_to_frequency

#==============================================================================
# Commands for frequency
#==============================================================================

def set_carrier_frequency(val, ssh_client=None):
  """
  Set the carrier frequency.

  Examples
  >>> python board_cmd_exec.py --cmd=set_carrier_frequency --args=2377
  """
  # Determine if the input is a channel or frequency by the value (less than 1000 is a channel)
  if int(val) < 1000:
    freq_mhz = channel_to_frequency(int(val))
  else:
    freq_mhz = int(val)

  freq_deca_hz = int(freq_mhz * 100000)

  write_register('rf', 1, freq_mhz, ssh_client=ssh_client)
  write_register('rf', 5, freq_mhz, ssh_client=ssh_client)
  write_register('xpu', 14, freq_deca_hz, ssh_client=ssh_client) # Ensure that the frequency is set in the XPU
  print(f'board_cmd_exec: Set carrier frequency to {freq_mhz} MHz.')

# REVISIT: Change to
# root@analog:/sys/bus/iio/devices/iio:device2# cat out_altvoltage1_TX_LO_frequency
# 2484000000

def get_carrier_frequency(ssh_client=None):
  """
  Get the carrier frequency.
  """
  freq_mhz = read_register('rf', 1, ssh_client=ssh_client)
  print(f'board_cmd_exec: Carrier frequency is {freq_mhz} MHz.')
  return freq_mhz

#==============================================================================
# Commands for gains
#==============================================================================

def rx_rf_gain_increase(gain_increase_db, rx_ant=0, ssh_client=None):
  """
  Increase the RX RF gain.

  Call as follows for increasing the gain by 5 dB on RX antenna 1:
  >>> python board_cmd_exec.py --cmd=rx_rf_gain_increase --args="5 1"
  """
  gain_increase_db = float(gain_increase_db)
  rx_ant           = int(rx_ant)

  current_gain_db = sysfs_get_rx_gain(rx_ant, ssh_client = ssh_client)
  new_gain_db     = current_gain_db + float(gain_increase_db)
  sysfs_set_rf_rx_gain(new_gain_db, rx_ant=rx_ant, ssh_client=ssh_client)

  print(f'board_cmd_exec: Increased RX RF gain from {current_gain_db} dB to {new_gain_db} dB.')

def set_rx_rf_gain(gain_db, rx_ant=0, ssh_client=None):
  """
  The range is larger than -3dB to less than or equal to 71 dB in 1 dB steps.

  Example
  >>> python board_cmd_exec.py --cmd=set_rx_rf_gain --args="10 0"
  """
  gain_db = float(gain_db)
  rx_ant  = int(rx_ant)
  sysfs_set_rf_rx_gain(gain_db, rx_ant, ssh_client=ssh_client)
  print(f'board_cmd_exec: Set RX RF gain to {gain_db} dB.')

def get_rx_rf_gain(rx_ant=0, ssh_client=None):
  """
  Get the RX RF gain.

  Example usage for getting the gain on RX antenna 1:
  >>> python board_cmd_exec.py --cmd=get_rx_rf_gain --args="1"
  """
  rx_ant = int(rx_ant)
  gain_db = sysfs_get_rx_gain(rx_ant, ssh_client=ssh_client)
  print(f'board_cmd_exec: RX RF gain is {gain_db} dB.')
  return gain_db

def set_rf_gain_control_mode(mode, rx_ant=0, ssh_client=None):
  """
  Set the RF gain control mode.

  Example
  >>> python board_cmd_exec.py --cmd=set_rf_gain_control_mode --args="manual 0"
  """
  sysfs_set_rf_gain_control_mode(mode, rx_ant, ssh_client)
  print(f'board_cmd_exec: Set RF gain control mode to {mode} for RX antenna {rx_ant}.')


#==============================================================================
# Commands for attenuation
#==============================================================================

def set_tx_rf_gain_increase(gain_increase_db, tx_ant=0, ssh_client=None):
  """
  Decrease the TX RF attenuation by increasing gain

  Example usage for decreasing the attenuation by 5 dB on TX antenna 1 by increasing gain:
  >>> python board_cmd_exec.py --cmd=gain_increase_db --args="5 1"
  """
  gain_increase_db = float(gain_increase_db)
  tx_ant           = int(tx_ant)

  current_atten_db = sysfs_get_rf_tx_atten(tx_ant, ssh_client=ssh_client)
  new_atten_db     = current_atten_db + float(gain_increase_db)
  sysfs_set_rf_tx_atten(new_atten_db, tx_ant=tx_ant, ssh_client=ssh_client)

  return new_atten_db

def set_tx_rf_atten(atten_db, tx_ant=0, ssh_client=None):
  """
  Set the The range is from 0 to -89.75 dB in 0.25dB steps.

  Call as follows for setting the attenuation to 5 dB on TX antenna 1:
  >>> python board_cmd_exec.py --cmd=set_tx_rf_atten --args="-5 1"
  """
  atten_db = float(atten_db)
  tx_ant   = int(tx_ant)
  sysfs_set_rf_tx_atten(atten_db, tx_ant, ssh_client=ssh_client)
  print(f'board_cmd_exec: Set TX RF attenuation to {atten_db} dB.')


def get_tx_rf_atten(tx_ant=0, ssh_client=None):
  """
  Get the TX RF attenuation.

  Example usage for getting the attenuation on TX antenna 1:
  >>> python board_cmd_exec.py --cmd=get_tx_rf_atten --args="1"
  """
  tx_ant = int(tx_ant)
  atten_db = sysfs_get_rf_tx_atten(tx_ant, ssh_client=ssh_client)
  print(f'board_cmd_exec: TX RF attenuation is {atten_db} dB.')
  return atten_db



#==============================================================================
# Main
#==============================================================================

def interactive_mode(ssh_client):
  """
  Interactive mode to accept commands and arguments in a loop.
  """
  while True:
    # Prompt user for input
    user_input = input("Enter command and arguments, or 'exit' to quit: ")
    if user_input.lower() == 'exit':
      break
    try:
      cmd, *args = user_input.split()
      main(cmd, ' '.join(args), ssh_client)
    except ValueError as e:
      print(f"Error: {e}")
    except Exception as e:
      print(f"Unexpected error: {e}")


def main(cmd, args, ssh_client):
  """
  Main function for executing commands on the board.
  """
  # Dictionary of commands and functions
  commands = {
    'set_dac_intf_filter_mode': set_dac_intf_filter_mode,

    'set_carrier_frequency': set_carrier_frequency,
    'get_carrier_frequency': get_carrier_frequency,

    'rx_rf_gain_increase': rx_rf_gain_increase,
    'set_rx_rf_gain': set_rx_rf_gain,
    'get_rx_rf_gain': get_rx_rf_gain,
    'set_rf_gain_control_mode': set_rf_gain_control_mode,

    'set_tx_rf_gain_increase': set_tx_rf_gain_increase,  # 'set_tx_rf_gain_increase' is not implemented yet
    'set_tx_rf_atten': set_tx_rf_atten,
    'get_tx_rf_atten': get_tx_rf_atten,

    'set_filter': set_filter,
    'get_filter': get_filter,
  }

  if cmd in commands:
    if args:
      args_list = args.split()  # Split arguments on spaces
      commands[cmd](*args_list, ssh_client=ssh_client)
    else:
      commands[cmd](ssh_client=ssh_client)
  else:
    raise ValueError(f"Command '{cmd}' not found.")


if __name__ == '__main__':
  ssh_client = SSHClient()

  parser = argparse.ArgumentParser(description="Parameters for experiments")
  parser.add_argument('--cmd', type=str, help='Command to execute on the board.')
  parser.add_argument('--args', type=str, help='Arguments for the command.')

  args = parser.parse_args()

  if args.cmd:  # Non-interactive mode (command-line arguments exist)
    main(args.cmd, args.args, ssh_client)
  else:  # Interactive mode if no args given
    interactive_mode(ssh_client)

  ssh_client.close()
