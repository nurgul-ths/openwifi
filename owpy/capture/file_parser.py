
import struct

#==============================================================================
# File reading functions
#==============================================================================

# We use a unique header to identify the start of each data chunk in the file
# since the file may contain many different chunks of I/Q data (each is from one Wi-Fi frame)
# we separate them with a header and the size of the data chunk
HEADER = 0xDEADBEEF
HEADER_SIZE = 4
SIZE_SIZE = 8

# The data is structured as follows
# [HEADER = 32 bits][SIZE = 64 bits][DATA = ? bits][HEADER = 32 bits][SIZE = 64 bits][DATA = ? bits]...

def read_data_from_file(file_path):
  """Reads data from a file as an alternative to getting data over UDP.

  Args:
    file_path (str): Path to the file.
  """
  data_list = [] # List for each data chunk (i.e., Wi-Fi frame)

  with open(file_path, 'rb') as file:
    while True:

      # 1) Get the 32-bit header and if it is not found, break
      header_bytes = file.read(HEADER_SIZE)
      if not header_bytes:
        break

      header = struct.unpack('I', header_bytes)[0]
      if header != HEADER: # See side_ch_ctl.c in the openwifi repo
        continue

      # 2) Read the 64-bit size of the next data chunk and if it is not found, break
      size_bytes = file.read(SIZE_SIZE)
      if not size_bytes:
        break

      data_size = struct.unpack('Q', size_bytes)[0]  # 'Q' for 64-bit unsigned

      # 3) Read the data chunk and skip if the size does not match
      data = file.read(data_size)
      if len(data) != data_size:
        print(f"Warning: Incomplete data chunk encountered. Expected {data_size} bytes, got {len(data)} bytes.")
        continue

      data_list.append(data)

  return data_list
