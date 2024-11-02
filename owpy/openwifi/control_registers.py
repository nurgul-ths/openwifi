"""
Functions to update various registers on the openwifi board.

We can do 3 things:
1. Run a script on the board itself
2. Run a script on the host and use SSH to run code on the board
3. Run a script on the host and use a pre-existing SSH connection to run code on the board (see owpy/openwifi/ssh.py)
"""

import logging
logger = logging.getLogger('processing_app')

import time
import os
from owpy.openwifi.misc import is_openwifi_board
from owpy.openwifi.ssh import SSHClient

def write_register(component, reg, value, ssh_client=None):
  """
  Update the register.

  Args:
    component (str): The component of the register.
    reg (str): The register to be updated.
    value (str): The value to set the register to.
    ssh_client (SSHClient, optional): An SSH client connected to the board. Defaults to None, in which case a new connection is created.

  Examples:
    >>> write_register('tx_intf', 3, 1)
  """

  cmd = f'cd openwifi && ./sdrctl dev sdr0 set reg {component} {reg} {value}'
  logger.debug('Running command: %s', cmd)

  if is_openwifi_board():
    os.system(cmd)
  else:
    if ssh_client is None:
      ssh_client = SSHClient()
      stdin, stdout, stderr = ssh_client.exec_command(cmd)
      stdout.read()  # Wait for the command to complete
      stderr.read()  # Read stderr to capture any errors
      ssh_client.close()

    else:
      stdin, stdout, stderr = ssh_client.exec_command(cmd)
      stdout.read()
      stderr.read()


def read_register(component, reg, ssh_client=None):
  """
  Update the register.

  Args:
    component (str): The component of the register.
    reg (str): The register to be updated.
    ssh_client (SSHClient, optional): An SSH client connected to the board. Defaults to None, in which case a new connection is created.

  Examples:
    >>> write_register('tx_intf', 3, 1)
  """

  cmd = f'cd openwifi && ./sdrctl dev sdr0 get reg {component} {reg}'
  logger.debug('Running command: %s', cmd)

  print('Running command: %s', cmd)

  if is_openwifi_board():
    os.system(cmd)
  else:
    if ssh_client is None:
      ssh_client = SSHClient()
      stdin, stdout, stderr = ssh_client.exec_command(cmd)
      stdout.read()  # Wait for the command to complete
      stderr.read()  # Read stderr to capture any errors
      ssh_client.close()

    else:
      stdin, stdout, stderr = ssh_client.exec_command(cmd)
      stdout.read()
      stderr.read()

  print('Output: %s', stdout.read().decode('utf-8'))

  output = print(stdout.read().decode('utf-8'))
  return output
