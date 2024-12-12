"""
UDP handler

Data coming from the openwifi board is sent through a UDP socket. This class handles the UDP socket and keeps the connection alive.

REVISIT: This timeout seems to be necessary for the processing part
"""

import socket
from datetime import datetime


# REVISIT: Add data type here since this will change num_dma_symbol_per_trans to be based on csi vs I/Q. See also side_ch_control.v
class UDPHandler:
  def __init__(self, UDP_IP="192.168.10.1", UDP_PORT=4000, MAX_NUM_DMA_SYMBOL=8192, receive_buffer_size_bytes=2**23):
    """Initialize the UDPHandler class which handles the UDP socket to the openwifi board.

    Debugging:
    If we have an error, get the PID of the process using the socket
    sudo lsof -i:4000

    Then kill the process, example PID is 14430
    kill -9 14430

    Args:
      UDP_IP: Local IP to listen to.
      UDP_PORT: Local port to listen to.
      MAX_NUM_DMA_SYMBOL: Maximum number of DMA symbols.
      receive_buffer_size_bytes: Socket receive buffer size in bytes.

    Raises:
      socket.error: If socket creation or binding fails.
    """
    print("IMPORTANT! If the UDP module hangs, consider if you have firewall settings blocking it.")

    self.UDP_IP   = UDP_IP
    self.UDP_PORT = UDP_PORT
    self.MAX_NUM_DMA_SYMBOL = MAX_NUM_DMA_SYMBOL
    self.first_transaction  = False

    try:
      self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
      self.sock.bind((self.UDP_IP, self.UDP_PORT))
      self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, receive_buffer_size_bytes)
    except socket.error as e:
      raise socket.error(f"Failed to create or bind socket: {e}")


  def receive_data(self, max_wait_time=None):
    """Receive data from the socket.

    Args:
      max_wait_time: Optional timeout in seconds.

    Returns:
      bytes: Received data, or None if the length of the data received is abnormal.
      str: Error message if error occurred ("timeout", "keyboard_interrupt", or "exception").
    """

    buffer_size = self.MAX_NUM_DMA_SYMBOL*8

    if max_wait_time is not None:
      self.sock.settimeout(max_wait_time)

    try:
      data, addr = self.sock.recvfrom(buffer_size)
    except socket.timeout:
      print("UDPHandler: Socket timeout")
      return "timeout"
    except KeyboardInterrupt:
      print("UDPHandler: Keyboard interrupt")
      return "keyboard_interrupt"
    except Exception as e:
      print(f"UDPHandler: Exception {e}")
      return "exception"

    # Reset timeout to default behavior (blocking)
    if max_wait_time is not None:
      self.sock.settimeout(None)

    if not self.first_transaction:
      print("UDPHandler: First transaction received (silent until end)")
      print(datetime.now().strftime("%Y-%m-%d_%H-%M-%S"))
      self.first_transaction = True

    return data


  def close(self):
    """Close the socket."""
    self.sock.close()


  def __del__(self):
    """Destructor to close the socket."""
    self.sock.close()
