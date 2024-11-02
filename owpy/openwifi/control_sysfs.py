"""
Functions to interact with OpenWiFi board parameters through sysfs interface.

This module provides functions to read and write RF parameters (gain, attenuation, modes)
on OpenWiFi boards using the sysfs interface. It handles both TX and RX parameters
and provides proper validation of inputs.

For AD9361 parameter details, see:
<https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9361>
"""

import logging
logger = logging.getLogger('processing_app')

from owpy.openwifi.ssh import SSHClient
from owpy.openwifi.misc import is_openwifi_board, get_openwifi_device_dir
from owpy.params.checker_openwifi import (
  validate_openwifi_tx_ant,
  validate_openwifi_rf_atten_tx,
  validate_openwifi_rx_ant,
  validate_openwifi_rf_rx_gain
)

#==============================================================================
# RF Transmitter (TX) Functions
#==============================================================================
def sysfs_rf_tx_gain_increase(gain_increase_db, tx_ant=0, ssh_client=None):
  """
  Increase TX RF gain by reducing TX attenuation.

  Note: Since attenuation is specified from -89.75 dB to 0 dB, increasing gain
  means reducing attenuation. A positive gain_increase_db value will make the
  signal stronger.

  Args:
    gain_increase_db (float): Amount to increase gain by in dB
    tx_ant (int, optional): TX antenna index (0 or 1). Defaults to 0.
    ssh_client (SSHClient, optional): Existing SSH connection. Defaults to None.

  Returns:
    float: New attenuation value in dB
  """
  gain_increase_db = float(gain_increase_db)
  tx_ant = int(tx_ant)

  current_atten_db = sysfs_get_rf_tx_atten(tx_ant, ssh_client=ssh_client)
  new_atten_db = current_atten_db + gain_increase_db
  sysfs_set_rf_tx_atten(new_atten_db, tx_ant=tx_ant, ssh_client=ssh_client)

  return new_atten_db


def sysfs_set_rf_tx_atten(value, tx_ant, ssh_client=None):
  """
  Set TX attenuation for specified antenna.

  Args:
    value (float): TX attenuation in dB. Range: 0 to -89.75 dB in 0.25 dB steps.
    tx_ant (int): TX antenna index (0 or 1)
    ssh_client (SSHClient, optional): Existing SSH connection. Defaults to None.
  """
  validate_openwifi_tx_ant(tx_ant)
  validate_openwifi_rf_atten_tx(value)

  # Round to nearest 0.25 dB step
  value = int(value * 4) / 4
  logger.debug("Setting TX attenuation to: %s dB", value)
  control_sysfs(f"out_voltage{tx_ant}_hardwaregain", "write", value, ssh_client)


def sysfs_get_rf_tx_atten(tx_ant, ssh_client=None):
  """
  Get current TX attenuation for specified antenna.

  Args:
    tx_ant (int): TX antenna index (0 or 1)
    ssh_client (SSHClient, optional): Existing SSH connection. Defaults to None.

  Returns:
    float: Current TX attenuation in dB
  """
  validate_openwifi_tx_ant(tx_ant)
  value = control_sysfs(f"out_voltage{tx_ant}_hardwaregain", "read", ssh_client=ssh_client)
  logger.debug("Read TX attenuation: %s", value)

  # Remove ' dB\n' suffix and convert to float
  value = float(value.replace(' dB\n', ''))
  return value

#==============================================================================
# RF Receiver (RX) Functions
#==============================================================================
def sysfs_set_rf_rx_gain(value, rx_ant, ssh_client=None):
  """
  Set RX gain for specified antenna.

  Valid range is -3 dB to 71 dB in 1 dB steps for the 1300-4000 MHz range.
  See RX Gain Control section in:
  <https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9361>

  Args:
    value (float): RX gain in dB. Will be clamped to valid range [-3, 71].
    rx_ant (int): RX antenna index (0 or 1)
    ssh_client (SSHClient, optional): Existing SSH connection. Defaults to None.
  """
  validate_openwifi_rx_ant(rx_ant)
  # validate_openwifi_rf_rx_gain(value) # Currently disabled

  # Check range and notify if out of bounds
  if value < -3 or value > 71:
    print(f"Value {value} is out of range. Must be between -3 and 71 dB.")
    value = max(-3, min(71, value))

  value = int(value)  # Round to nearest dB
  logger.debug("Setting RX gain to: %s dB", value)

  # Must set manual mode before setting gain
  control_sysfs(f"in_voltage{rx_ant}_gain_control_mode", "write", "manual", ssh_client)
  control_sysfs(f"in_voltage{rx_ant}_hardwaregain", "write", value, ssh_client)


def sysfs_get_rx_gain(rx_ant, ssh_client=None):
  """
  Get current RX gain for specified antenna.

  Args:
    rx_ant (int): RX antenna index (0 or 1)
    ssh_client (SSHClient, optional): Existing SSH connection. Defaults to None.

  Returns:
    float: Current RX gain in dB
  """
  validate_openwifi_rx_ant(rx_ant)
  value = control_sysfs(f"in_voltage{rx_ant}_hardwaregain", "read", ssh_client=ssh_client)
  logger.debug("Read RX gain: %s", value)

  # Remove ' dB\n' suffix and convert to float
  value = float(value.replace(' dB\n', ''))
  return value


def sysfs_set_rf_gain_control_mode(mode, rx_ant, ssh_client):
  """
  Set RX gain control mode for specified antenna.

  Args:
    mode (str): Gain control mode: 'manual', 'slow_attack', or 'fast_attack'
    rx_ant (int): RX antenna index (0 or 1)
    ssh_client (SSHClient): SSH connection

  Raises:
    ValueError: If mode is not one of the valid options
  """
  valid_modes = ["manual", "slow_attack", "fast_attack"]
  if mode not in valid_modes:
    raise ValueError(f"Invalid mode: {mode}. Must be one of {valid_modes}")

  control_sysfs(f"in_voltage{rx_ant}_gain_control_mode", "write", mode, ssh_client)
  logger.info("Set RX%d gain control mode to %s", rx_ant, mode)

#==============================================================================
# Core sysfs Interface
#==============================================================================
def control_sysfs(var_name, action, value=None, ssh_client=None, device_num=None):
  """
  Read or write a sysfs variable on the OpenWiFi board.

  Args:
    var_name (str): sysfs variable name (e.g., 'in_voltage0_hardwaregain')
    action (str): Either 'read' or 'write'
    value (int/float/str, optional): Value to write (required if action='write')
    ssh_client (SSHClient, optional): Existing SSH connection. If None, creates new connection.
    device_num (int, optional): IIO device number if known

  Returns:
    str: Command output (for reads) or empty string (for writes)

  Raises:
    ValueError: If action is not 'read' or 'write'
  """
  if action not in ["read", "write"]:
    raise ValueError(f"Invalid action: {action}. Must be 'read' or 'write'.")

  # Create new SSH connection if none provided
  if ssh_client is None:
    ssh_client = SSHClient()
    ssh_close = True
  else:
    ssh_close = False

  # Get sysfs device directory
  device_dir = get_openwifi_device_dir(ssh_client, device_num, logger)

  # Execute command
  if action == "write":
    ssh_cmd = f"echo {value} > {device_dir}/{var_name}"
  else:  # read
    ssh_cmd = f"cat {device_dir}/{var_name}"

  stdin, stdout, stderr = ssh_client.exec_command(ssh_cmd)

  # Get output and clean up
  stdout_content = stdout.read().decode('utf-8')
  if ssh_close:
    ssh_client.close()

  return stdout_content
