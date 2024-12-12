"""
SSH handler

Running individual commands with subprocess in python creates a new shell for each command. This is
very inefficient. Instead, we use paramiko to create a single ssh connection and run multiple
commands on the same shell.
"""

import os
import paramiko

class SSHClient:
  def __init__(self, host='192.168.10.122', username='root', password='openwifi'):
    """

    Args:
      host (str): The IP address of the OpenWiFi board.
      username (str): The username to use for the SSH connection.
      password (str): The password to use for the SSH connection.

    Examples:
      >>> ssh_client = SSHClient()
    """

    self.host     = host
    self.username = username
    self.password = password
    self.start()


  def start(self):
    """Start the SSH connection."""
    self.client = paramiko.SSHClient()
    self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    self.client.connect(self.host, username=self.username, password=self.password)
    self.sftp = self.client.open_sftp()


  def upload(self, local_path, remote_path):
   """Upload file to remote host."""
   try:
     if remote_path.endswith('/'):
       # If remote_path ends with '/', treat it as a directory and preserve the original filename
       # Example: If local_path is '/home/user/data.txt' and remote_path is '/remote/dir/'
       # Then filename becomes 'data.txt' and remote_path becomes '/remote/dir/data.txt'
       filename    = os.path.basename(local_path)
       remote_path = os.path.join(remote_path, filename)

     self.sftp.put(local_path, remote_path)
   except Exception as e:
     print(f"Failed to upload {local_path} to {remote_path}: {e}")


  def download(self, remote_path, local_path):
    """Download file from remote host."""
    try:
      self.sftp.get(remote_path, local_path)
    except Exception as e:
      print(f"Failed to download {remote_path} to {local_path}: {e}")


  def exec_command(self, cmd):
    """Execute command over SSH connection

    Args:
      cmd (str): The command to execute.

    Returns:
      tuple: stdin, stdout, stderr
    """
    stdin, stdout, stderr = self.client.exec_command(cmd)
    return stdin, stdout, stderr


  def close(self):
    """Close the socket."""
    if self.sftp:
      self.sftp.close()
    if self.client:
      self.client.close()


  def __del__(self):
    """Destructor to close the socket."""
    self.client.close()




