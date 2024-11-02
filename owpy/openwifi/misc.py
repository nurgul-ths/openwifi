"""OpenWiFi helper functions.

This module contains utility functions for OpenWiFi board operations:
- Board detection
- Device directory discovery and validation
- AD9361 RF board file system navigation

The functions handle SSH-based interactions with the OpenWiFi board's device tree,
particularly focusing on IIO device management and RF bandwidth file detection.
"""

import os
import getpass
from owpy.openwifi.ssh import SSHClient

DEVICE_BASE = "/sys/bus/iio/devices/iio:device"
RF_BANDWIDTH_FILE = "in_voltage_rf_bandwidth"
MAX_DEVICES = 5


def is_openwifi_board():
  """Check if we are on the openwifi board"""
  return os.path.exists('/root/openwifi') and getpass.getuser() == 'root'


def test_openwifi_device_dir(ssh_client, device_num, logger=None):
  """Test if the device directory for a given device number exists.

  Args:
    ssh_client: An SSH client connected to the board.
    device_num: The device number.
    logger: Optional logger to use for logging.

  Returns:
    bool: True if the device directory exists, False otherwise.
  """
  if ssh_client is None:
    ssh_client = SSHClient()

  stdin, stdout, stderr = ssh_client.exec_command(
      f"test -f {DEVICE_BASE}{device_num}/{RF_BANDWIDTH_FILE} && echo true || echo false"
  )
  stdout_content = stdout.read().decode('utf-8').strip()

  if logger is not None:
    logger.debug("STDOUT: %s", stdout_content)

  return "true" in stdout_content


def get_openwifi_device_dir(ssh_client=None, device_num=None, logger=None):
  """Get the device directory on the openwifi board for the AD9361 RF board.

  Args:
    ssh_client: Optional SSH client connected to the board. If None, creates new connection.
    device_num: Optional specific device number to check. If None, scans all devices.
    logger: Optional logger for debugging.

  Returns:
    str: The device directory.

  Raises:
    FileNotFoundError: If the in_voltage_rf_bandwidth file can not be found.
  """
  if ssh_client is None:
    ssh_client = SSHClient()

  device_dir = None

  if device_num is not None:
    if test_openwifi_device_dir(ssh_client, device_num, logger):
      device_dir = f"{DEVICE_BASE}{device_num}"
  else:
    for i in range(MAX_DEVICES):
      if test_openwifi_device_dir(ssh_client, i, logger):
        device_dir = f"{DEVICE_BASE}{i}"
        break

  if device_dir is None:
    raise FileNotFoundError("Can not find in_voltage_rf_bandwidth! Check log to make sure ad9361 driver is loaded!")

  if logger is not None:
    logger.info("Found device directory: %s", device_dir)

  return device_dir
