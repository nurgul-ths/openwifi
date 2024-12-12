"""Data parser functions for OpenWiFi side channel data

Compatible with OpenWiFi hardware commit:
27bb6b78c7349f582624b53db50641d35c85017e on the openwifi-hw ws-zedboard branch

Data is organized as 64-bit DMA symbols:

CSI Data Format:
----------------
DMA Symbol 0: Timestamp (64-bit)
DMA Symbol 1: 32-bit frequency offset, 29-bit LO frequency, 3 bits reserved
DMA Symbol 2-7: Additional timestamps (64-bit each)
DMA Symbol 8-63: CSI Data (56 DMA symbols)
DMA Symbol 64+: Equalizer Data ((56-4) DMA symbols * num_eq times)

IQ Data Format:
---------------
DMA Symbol 0: Timestamp (64-bit)
DMA Symbol 1: Meta data (IQ/CSI indicator, trigger source, antenna config, LO frequency)
DMA Symbol 2: Reserved
DMA Symbol 3+: IQ Data (format depends on antenna configuration)

Note: All values are 16-bit unless specified otherwise.
"""

import numpy as np
from owpy.files.files import *

#==============================================================================
# Bit conversion
#==============================================================================

def get_uint64(side_info, start_idx):
  """Reconstructs a 64-bit unsigned from 4 16-bit values (unsigned)"""

  side_info_subset = side_info[:,start_idx:start_idx+4]

  side_info_uint64 = \
                side_info_subset[:,0] \
    + pow(2,16)*side_info_subset[:,1] \
    + pow(2,32)*side_info_subset[:,2] \
    + pow(2,48)*side_info_subset[:,3]

  return side_info_uint64

def get_uint32(side_info, start_idx):
  """Reconstructs a 32-bit unsigned from 2 16-bit values (unsigned)"""

  side_info_subset = side_info[:,start_idx:start_idx+2]

  side_info_uint32 = \
                side_info_subset[:,0] \
    + pow(2,16)*side_info_subset[:,1]

  return side_info_uint32

#==============================================================================
# CSI
#==============================================================================

# align these with side_ch_control.v and all related user space, remote files
MAX_NUM_DMA_SYM   = 8192
LO_FREQ_BIT_WIDTH = 29

CSI_LEN_DMA_SYM       = 56     # length of single CSI
EQUALIZER_LEN_DMA_SYM = (56-4) # for non HT, four {32767,32767} will be padded to achieve 52 (non HT should have 48)
CSI_LEN_HALF_DMA_SYM  = round(CSI_LEN_DMA_SYM / 2)

CSI_HEADER_LEN_DMA_SYM = 8 # Header length in DMA symbols, CSI data is after the header

# Indices in 16-bit words
CSI_CAPTURE_TIMESTAMP_IDX  = 0*4
CSI_FREQ_OFFSET_EST_IDX    = 1*4
CSI_CAPTURE_LO_FREQ_IDX    = 1*4
CSI_CAPTURE_LO_FREQ_OFFSET = 32

TIMESTAMPS_EXTRA_IDX = 2*4 # After timestamp_pkt_header_valid_strobe and freq_offset we have additional timestamps for the CSI


def reshape_csi_side_info16(side_info_uint16, num_eq):
  """
  The side information is reshaped and segmented into a 2D array of 16-bit values with
  number of transmissions/frames as the first dimension and the number of 16-bit values per transmission as the second dimension.

  Args:
    side_info_uint16 (numpy.ndarray): The side information data.
    num_eq (int): Number of equalized symbols.
  """
  num_dma_symbol_per_trans = CSI_HEADER_LEN_DMA_SYM + CSI_LEN_DMA_SYM + num_eq*EQUALIZER_LEN_DMA_SYM
  num_int16_per_trans      = num_dma_symbol_per_trans * 4
  num_frames               = round(len(side_info_uint16) / num_int16_per_trans)

  side_info_reshaped = side_info_uint16.reshape([num_frames, num_int16_per_trans])

  return side_info_reshaped, num_frames, num_int16_per_trans


def parse_csi_side_info(side_info_uint16, num_eq, csi_timestamp_names):
  """
  Parse the signed side information for CSI

  Args:
    side_info_uint16 (numpy.ndarray): The side information data.
    num_eq (int): Number of equalized symbols.
    csi_timestamp_names (list): List of CSI timestamp names.
  """

  side_info_uint16_reshaped, num_frames, num_uint16_per_trans = reshape_csi_side_info16(side_info_uint16, num_eq)
  side_info_int16_reshaped = side_info_uint16_reshaped.astype('int16')

  # REVISIT: This is wrong, the frequency offset is 32-bits in hardware
  freq_offset = (20e6 * side_info_int16_reshaped[:, CSI_FREQ_OFFSET_EST_IDX] / 512) / (2 * np.pi)
  if num_eq > 0:
    equalizer = np.zeros((num_frames, num_eq * EQUALIZER_LEN_DMA_SYM), dtype='complex64')
  else:
    equalizer = np.zeros((0, 0), dtype='complex64')

  csi = np.zeros((num_frames, CSI_LEN_DMA_SYM), dtype='int16')
  csi = csi + 1j* csi

  for i in range(num_frames):
    tmp_vec_i = side_info_int16_reshaped[i, 4*CSI_HEADER_LEN_DMA_SYM     : (num_uint16_per_trans - 1) : 4]
    tmp_vec_q = side_info_int16_reshaped[i, 4*CSI_HEADER_LEN_DMA_SYM + 1 : (num_uint16_per_trans - 1) : 4]
    tmp_vec   = tmp_vec_i + 1j*tmp_vec_q

    # The first part is just the CSI
    csi[i, :CSI_LEN_HALF_DMA_SYM]  = tmp_vec[CSI_LEN_HALF_DMA_SYM : CSI_LEN_DMA_SYM]
    csi[i,  CSI_LEN_HALF_DMA_SYM:] = tmp_vec[0 : CSI_LEN_HALF_DMA_SYM]

    if num_eq > 0:
      equalizer[i, :] = tmp_vec[CSI_LEN_DMA_SYM : (CSI_LEN_DMA_SYM + num_eq * EQUALIZER_LEN_DMA_SYM)]

  data_dict = {'freq_offset': freq_offset, 'csi': csi}

  if num_eq > 0:
    data_dict['equalizer'] = equalizer

  timestamp_dict, lo_freq = parse_csi_side_info_header(side_info_uint16_reshaped, csi_timestamp_names)

  return data_dict, timestamp_dict, lo_freq, num_frames


def parse_csi_side_info_header(side_info_uint16_reshaped, csi_timestamp_names):
  """
  Parse the unsigned side information for CSI, the header information
  """
  timestamp      = get_uint64(side_info_uint16_reshaped, CSI_CAPTURE_TIMESTAMP_IDX)
  timestamp_dict = {csi_timestamp_names[0] : timestamp}

  # Process remaining timestamps after the first one (range starts from 1) and after the freq offset (+2)
  for i, name in csi_timestamp_names[1:]:
    dma_sym_idx   = i + (TIMESTAMPS_EXTRA_IDX // 4)
    timestamp     = get_uint64(side_info_uint16_reshaped, 4*dma_sym_idx)
    timestamp_key = name

    timestamp_dict[timestamp_key] = timestamp

  # Get the LO frequency (carrier frequency, not the carrier frequency offset)
  csi_header      = get_uint64(side_info_uint16_reshaped, CSI_FREQ_OFFSET_EST_IDX)
  lo_freq_deca_hz = (csi_header >> CSI_CAPTURE_LO_FREQ_OFFSET) & (2**LO_FREQ_BIT_WIDTH-1)
  lo_freq         = lo_freq_deca_hz * 10

  return timestamp_dict, lo_freq

#==============================================================================
# I/Q
#==============================================================================

# For 27bb6b78c7349f582624b53db50641d35c85017e commit on the openwifi-hw ws-zedboard branch
# For this, see the FSM using the iq_state signal in side_ch_control.v
#
# We have data as follows for 64-bit DMA symbols:
# - 0: Timestamp. We sample the signal tsf_val_lock_by_iq_trigger which is a 100 MHz clock signal sampled
#      by the IQ trigger signal.
# - 1: Meta data: Here, we have data as follows:
#   - 64: IQ/CSI indicator, in this case it should be 1 for IQ data
#   - 63: iq_trigger_source_multistatic
#   - 62: iq_capture_all_antenna
#   - 61-33 (29 bits): lo_frequency in deca Hz
#   - 32-0: Reserved
# - 2: Reserved
# - 3: I/Q data
#  - For each 64-bit DMA symbol, we have 4 16-bit values. This allows us to send data from
#    2 antennas at the same time. The I/Q data is stored as follows.
#  - Note that we may also send the TX data along with RX data, allowing us to capature 1 TX and 2 RX antenna
#    when this is done, we seprate the 2 by a hBADC0FFEE0DDF00D magic number
#    note that a byte enable is used to selectively write the TX data in 32-bit chunks at a time into 64-bit DMA symbols
#    so when we iq_capture_all_antenna on, we get 1 TX and 2 RX, when off, we get 2 RX
#
# Keeping some reserved bits in the meta data for future use so we don't have to puysh the I/Q data



IQ_HEADER_LEN_DMA_SYM = 3 # Header length in DMA symbols, IQ data is after the header

# Indices in 16-bit
# See side_ch_control.v for the order of the I/Q data (timestamp, freq, etc.)
IQ_CAPTURE_TIMESTAMP_IDX      = 0*4

IQ_CAPTURE_LO_FREQ_IDX        = 1*4
IQ_CAPTURE_LO_FREQ_OFFSET     = 32
IQ_CAPTURE_ALL_ANTENNA_IDX    = 1*4
IQ_CAPTURE_ALL_ANTENNA_OFFSET = 61
IQ_CAPTURE_TRIGGER_SRC_IDX    = 1*4
IQ_CAPTURE_TRIGGER_SRC_OFFSET = 62

IQ_CAPTURE_METADATA_IDX       = 2*4 # REVISIT : Not used yet

IQ_CAPTURE_IQ_IDX             = 3*4 # Index of the data in DMA symbols


def reshape_iq_side_info16(buffer, num_dma_symbol_per_trans):
  """
  Reshape and segment the I/Q data from the buffer into a 2D array of I/Q values,
  with in-phase values at lower bits and quadrature values at higher bits.
  The fist axis has the number of transactions and the second axis has the number of 16-bit values per transaction.

  Args:
    buffer (numpy.ndarray): The buffer containing the raw I/Q data.
    num_dma_symbol_per_trans (int): The number of DMA symbols per transaction.

  Returns:
    numpy array: The reshaped buffer.

  Examples:
    buffer_reshaped will have the first dimension as the number of transactions and
    the second dimension as the number of 16-bit values per transaction.

    This means that for the first transaction:
      - The first I/Q sample will have the in-phase value at the 4th position
        `buffer_reshaped[0,4]` and the quadrature value at the 5th position `buffer_reshaped[0,5]`.
      - The second I/Q sample will have the in-phase value at the 8th position
        `buffer_reshaped[0,8]` and the quadrature value at the 9th position `buffer_reshaped[0,9]`.
    This pattern continues for the rest of the I/Q samples.
  """
  num_int16_per_trans = num_dma_symbol_per_trans * 4
  num_frames          = round(len(buffer) / num_int16_per_trans)

  # Reshape to that we get a row for each frame (generally, should just be 1 transmission and we just have a long vector)
  try:
    buffer_reshaped = buffer.reshape([num_frames, num_int16_per_trans])
    return buffer_reshaped

  except ValueError as e:
    print(f"Error: {e}")
    print(f"num_frames: {num_frames}")
    return None


def parse_iq_side_info_header(buffer_uint16, num_dma_symbol_per_trans, iq_len, data_type):
  """Extract timestamp, trigger source etc. from the buffer

  Args:
    buffer_uint16 (numpy.ndarray): The buffer containing the raw I/Q data (parsed as unsigned).
    iq_len (int): The length of the I/Q data.
    iq_header_len (int): The length of the I/Q header.

  Returns:
    numpy array: The extracted timestamp.

  """
  buffer_uint16_reshaped = reshape_iq_side_info16(buffer_uint16, num_dma_symbol_per_trans)

  if buffer_uint16_reshaped is None:
    return None, None, None, None, None

  # Timestamp: Get the 64-bit timestamp at IQ_CAPTURE_TIMESTAMP_IDX
  # The timestamp is 100 MHz clock, print time in seconds
  timestamp = get_uint64(buffer_uint16_reshaped, IQ_CAPTURE_TIMESTAMP_IDX)

  # Frequency: Frequency is 29 bits, so we discard anything above to not catch things that are not part of the frequency and offset
  iq_header       = get_uint64(buffer_uint16_reshaped, IQ_CAPTURE_LO_FREQ_IDX)
  lo_freq_deca_hz = (iq_header >> IQ_CAPTURE_LO_FREQ_OFFSET) & (2**LO_FREQ_BIT_WIDTH-1)
  lo_freq         = lo_freq_deca_hz * 10

  # Capture all antenna on/off: Get capture all antenna (1-bit) at bit position IQ_CAPTURE_ALL_ANTENNA_OFFSET
  # Ahh, when we get multiple frames, remember that lo_freq, trigger_src etc. can be a list, so can capture_all_antenna
  capture_all_antenna = (iq_header >> IQ_CAPTURE_ALL_ANTENNA_OFFSET) & 1

  if data_type == 'iq_all' and np.any(capture_all_antenna == 0):
    print('Warning: capture_all_antenna is off in extracted data, but data_type set for experiment is iq_all.')

  # Trigger source: Get trigger (1-bit) at bit position IQ_CAPTURE_TRIGGER_SRC_OFFSET
  trigger_src = (iq_header >> IQ_CAPTURE_TRIGGER_SRC_OFFSET) & 1

  # Find index where the TX starts when we get both 2 RX and TX. Note there is 1 DMA symbol of all 1 (why we do + 1)
  # that we have to offset and then we have to start after that one (+1 again)
  tx_start_len = IQ_CAPTURE_IQ_IDX // 4 + iq_len + 1+1 # Count from 0

  return timestamp, lo_freq, trigger_src, capture_all_antenna, tx_start_len


def parse_rssi_rx_iq0(buffer_uint16, num_dma_symbol_per_trans, iq_len):
  """Parse I/Q data, AGC, and RSSI from buffer.

  Args:
    buffer_int16 (numpy.ndarray): The buffer containing the raw I/Q data.
    iq_len (int): The length of the I/Q data. This is counted in 64-bit words, so we need to multiply by 4 to get the 16-bit words.

  Returns:
    dict: A dictionary containing the parsed I/Q data, AGC gain, and RSSI in half dB.
  """
  buffer_reshaped = reshape_iq_side_info16(buffer_uint16, num_dma_symbol_per_trans)

  if buffer_reshaped is None:
    return None

  buffer_reshaped = buffer_reshaped.astype('int16')

  iq_capture   = buffer_reshaped[:, (IQ_CAPTURE_IQ_IDX+0)::4] + 1j * buffer_reshaped[:, (IQ_CAPTURE_IQ_IDX+1)::4]
  agc_gain     = buffer_reshaped[:, (IQ_CAPTURE_IQ_IDX+2)::4]
  rssi_half_db = buffer_reshaped[:, (IQ_CAPTURE_IQ_IDX+3)::4]

  iq_capture   = iq_capture.reshape([-1, iq_len])
  agc_gain     = agc_gain.reshape([-1, iq_len])
  rssi_half_db = rssi_half_db.reshape([-1, iq_len])

  data_dict = {
    "rx0"          : iq_capture,
    "agc_gain"     : agc_gain,
    "rssi_half_db" : rssi_half_db
  }

  return data_dict


# REVISIT: In the future, I think it would be easier to just have a setup where we do
#
# | Header | IQ0/IQ1 | SEP=BADC0FFEE0DDF00D | IQ2/IQ3 | ... |
#
# and we don't try to compact the streams, so, if there is only 3 streams, we do
#
# | Header | IQ0/IQ1 | SEP=BADC0FFEE0DDF00D | IQ2/0 | ... |
#
# See <https://en.wikipedia.org/wiki/Magic_number_(programming)#DEADBEEF> for debug values
# This magic number is unlikely to ever occur by chance
#
def parse_iq(data_type, buffer_uint16, num_dma_symbol_per_trans, iq_len, tx_start_len = None):
  """
  Parse I/Q data from buffer for two receive antennas.

  Args:
    data_type (str): The type of I/Q data to parse.
    buffer_uint16 (numpy.ndarray): The buffer containing the raw I/Q data.
    num_dma_symbol_per_trans (int): The number of DMA symbols per transaction. REVISIT: It would be nicer if we just used a header to separate packets... although we can use timestamps and frequencies to check we get it correct
    iq_len (int): The length of the I/Q data.
    tx_start_len: To find the index where the TX starts when we get both 2 RX and TX when capture_all_antenna is True.

  Returns:
    dict: A dictionary containing the parsed I/Q data for two receive antennas.

  Examples: When we only had the timestamp in the header, the first 4x16-bit words represent the 64-bit
  timestamp and then afterwards we have the IQ data. The data is then stitched together as follows
  where we see that when we collect I/Q data for a transmit and receive antenna the receive antenna
  data comes first and then the transmit antenna data:
    data_type = tx_rx_iq0:
      - iq0 = rx = iq[:,4::4] + iq[:,5::4]*1j
      - iq1 = tx = iq[:,6::4] + iq[:,7::4]*1j

    data_type = rx_iq0_iq1:
      - iq0 = rx0 = iq[:,4::4] + iq[:,5::4]*1j
      - iq1 = rx1 = iq[:,6::4] + iq[:,7::4]*1j


  # "rx_iq0_iq1", "tx_rx_iq0", "iq_all"
  # iq0 = data_dict["iq0_capture"] # iq0 = rx_iq0 (rx_iq0_iq1 and tx_rx_iq0)
  # iq1 = data_dict["iq1_capture"] # iq1 = rx_iq1 (rx_iq0_iq1) or tx_iq0 (tx_rx_iq0)
  """
  buffer_reshaped = reshape_iq_side_info16(buffer_uint16, num_dma_symbol_per_trans)

  if buffer_reshaped is None:
    return None

  buffer_reshaped = buffer_reshaped.astype('int16')

  # Processing of iq data, we just call it iq0 and iq1, until we based off data_type match it to the correct antenna
  iq0_capture = buffer_reshaped[:, (IQ_CAPTURE_IQ_IDX+0)::4] + 1j*buffer_reshaped[:, (IQ_CAPTURE_IQ_IDX+1)::4]
  iq1_capture = buffer_reshaped[:, (IQ_CAPTURE_IQ_IDX+2)::4] + 1j*buffer_reshaped[:, (IQ_CAPTURE_IQ_IDX+3)::4]

  # Trim the data if we are collecting all of the I/Q data, data comes in iq_len blocks (assuming iq_len is an even number, otherwise
  # the next block after the iq0 and iq1, will be in length iq_len//2 but the total number of I/Q is 2*(iq_len//2) since we just have one antenna at a time)
  if data_type == 'iq_all':
    iq0_capture = iq0_capture[:, :iq_len]
    iq1_capture = iq1_capture[:, :iq_len]

  # When collecting all of the I/Q data, the TX data is at the end of the buffer, so we need to find the index where the TX starts.
  # The TX data is just 1 stream, with each 32-bit, we just offset by 2 16-bit and not 4 16-bit as above
  # Note that there is a block of 0xBADC0FFEE0DDF00D that separates the TX and RX data (used to be all 1s, but we just offset so we don't really check this)
  # when checking in 16-bit words, 0xBADC0FFEE0DDF00D would be 0xF00D, 0xE0DD, 0xFFEE, 0xBADC in little endian
  if data_type == 'iq_all' and tx_start_len is None:
    print('Warning: When capture_all_antenna is True, tx_start_len must be provided to find the index where the TX starts')

  if data_type == 'iq_all' and tx_start_len is not None:
    iq_tx_capture = buffer_reshaped[:, 4*tx_start_len::2] + 1j*buffer_reshaped[:, 4*tx_start_len+1::2]

    if iq_tx_capture.shape[1] != 2*(iq_len//2)-2:
      print(f"Warning: iq_tx_capture.shape[1] does not match {2*(iq_len//2)-2}")
      print("iq_tx_capture.shape[1]:", iq_tx_capture.shape[1])

  data_dict = {}

  # We prefer bb compared to tx, as tx_data is easily confused with the rx_data when reading code
  # We create the keys
  # - rx0: I/Q data for the first receive antenna
  # - rx1: I/Q data for the second receive antenna
  # - bb0: I/Q data for the transmit antenna
  # - nrx: Number of receive antennas
  # - nbb: Number of transmit antennas
  if data_type == 'rx_iq0_iq1':
    data_dict['rx0'] = iq0_capture
    data_dict['rx1'] = iq1_capture
    data_dict['nrx'] = 2
    data_dict['nbb'] = 0
  elif data_type == 'tx_rx_iq0':
    data_dict['rx0'] = iq0_capture
    data_dict['bb0'] = iq1_capture
    data_dict['nrx'] = 1
    data_dict['nbb'] = 1
  elif data_type == 'iq_all':
    data_dict['rx0'] = iq0_capture
    data_dict['rx1'] = iq1_capture
    data_dict['bb0'] = iq_tx_capture
    data_dict['nrx'] = 2
    data_dict['nbb'] = 1

  return data_dict


#==============================================================================
# HIGHER LEVEL FUNCTIONS
#==============================================================================

# See side_ch_control.v for the values of these types
DATA_TYPE_LIST = {'csi' : 0, 'iq' : 1}
DATA_BIT_DMA_SYMBOL_IDX = 1
DATA_BIT_BYTE_IDX       = 7

def process_and_save_iq(data, fd_dict, iq_num_dma_symbol_per_trans, params, logger=None):
  """Function for processing and saving the received IQ data.

  Args:
    data (bytes): Data received from the openwifi board.
    fd_dict (dict): Dictionary of file descriptors.
    iq_num_dma_symbol_per_trans (int): Number of DMA symbols per transaction.
    params (argparse.ArgumentParser): An ArgumentParser object that has been configured with command-line arguments.
    logger (logging.Logger): A logger object.

  Returns:
    int: Frame index.
    dict: Dictionary of processed data.
  """

  buffer_uint16 = np.frombuffer(data, dtype='uint16')

  if params.save_data and params.save_raw:
    np.savetxt(fd_dict[f"{RAW}_fd"], buffer_uint16.reshape(1, -1), fmt='%f')

  timestamp, lo_freq, trigger_src, capture_all_antenna, tx_start_len  = parse_iq_side_info_header(buffer_uint16, iq_num_dma_symbol_per_trans, params.iq_len, params.data_type)

  if timestamp is None:
    return 0, None

  n_frames = len(timestamp)

  if logger is not None:
    logger.debug("n_frames: %s", n_frames)

  if params.data_type in ["rx_iq0_iq1", "tx_rx_iq0", "iq_all"]:
    data_dict = parse_iq(params.data_type, buffer_uint16, iq_num_dma_symbol_per_trans, params.iq_len, tx_start_len)
  elif params.data_type == "rssi_rx_iq0":
    data_dict = parse_rssi_rx_iq0(buffer_uint16, iq_num_dma_symbol_per_trans, params.iq_len)
  else:
    raise ValueError(f"Unknown data type: {params.data_type}")

  if data_dict is None:
    return 0, None

  if params.save_data:
    for trans in range(n_frames):
      save_data(fd_dict[f"{TIMESTAMPS_IQ}_fd"], np.array(timestamp[trans]))

      if params.data_type == "rssi_rx_iq0":
        save_data(fd_dict[f"{FREQ}_fd"], np.array(lo_freq[trans]))
        save_complex_data(fd_dict[f"{RX_IQ0_REAL}_fd"], fd_dict[f"{RX_IQ0_IMAG}_fd"], data_dict["rx0"][trans, :])
        save_data(fd_dict[f"{AGC}_fd"], data_dict["agc_gain"][trans, :])
        save_data(fd_dict[f"{RSSI}_fd"], data_dict["rssi_half_db"][trans, :])

      elif params.data_type == "rx_iq0_iq1":
        save_data(fd_dict[f"{FREQ}_fd"], np.array(lo_freq[trans]))
        save_complex_data(fd_dict[f"{RX_IQ0_REAL}_fd"], fd_dict[f"{RX_IQ0_IMAG}_fd"], data_dict["rx0"][trans, :])
        save_complex_data(fd_dict[f"{RX_IQ1_REAL}_fd"], fd_dict[f"{RX_IQ1_IMAG}_fd"], data_dict["rx1"][trans, :])

      elif params.data_type == "tx_rx_iq0":
        save_data(fd_dict[f"{FREQ}_fd"], np.array(lo_freq[trans]))
        save_complex_data(fd_dict[f"{RX_IQ0_REAL}_fd"], fd_dict[f"{RX_IQ0_IMAG}_fd"], data_dict["rx0"][trans, :])
        save_complex_data(fd_dict[f"{TX_IQ0_REAL}_fd"], fd_dict[f"{TX_IQ0_IMAG}_fd"], data_dict["bb0"][trans, :])

      elif params.data_type == "iq_all":
        save_data(fd_dict[f"{FREQ}_fd"], np.array(lo_freq[trans]))
        save_complex_data(fd_dict[f"{RX_IQ0_REAL}_fd"], fd_dict[f"{RX_IQ0_IMAG}_fd"], data_dict["rx0"][trans, :])
        save_complex_data(fd_dict[f"{RX_IQ1_REAL}_fd"], fd_dict[f"{RX_IQ1_IMAG}_fd"], data_dict["rx1"][trans, :])
        save_complex_data(fd_dict[f"{TX_IQ0_REAL}_fd"], fd_dict[f"{TX_IQ0_IMAG}_fd"], data_dict["bb0"][trans, :])

      if params.system_mode == 'jmb':
        save_data(fd_dict[f"{TRIGGER}_fd"], np.array(trigger_src[trans]))

  return n_frames, data_dict


def process_and_save_csi(data, fd_dict, params, logger=None):

  buffer_uint16 = np.frombuffer(data, dtype='uint16')

  if params.save_data and params.save_raw:
    np.savetxt(fd_dict[f"{RAW}_fd"], buffer_uint16.reshape(1, -1), fmt='%f')

  data_dict, timestamp_dict, lo_freq, n_frames = parse_csi_side_info(buffer_uint16, params.num_eq, CSI_TIMESTAMP_NAMES)

  if logger is not None:
    logger.debug("n_frames: %s", n_frames)

  # REVISIT: Can we use the estimated frequency offset to correct the CSI
  for trans in range(0, n_frames):
    timestamp_list = [timestamp_dict[name][trans] for name in CSI_TIMESTAMP_NAMES]
    save_data(fd_dict[f"{FREQ}_fd"], np.array(lo_freq[trans]))
    save_data(fd_dict[f"{TIMESTAMPS_CSI}_fd"], np.array(timestamp_list))
    save_data(fd_dict[f"{FREQ_OFFSET}_fd"], data_dict['freq_offset'][trans])
    save_complex_data(fd_dict[f"{CSI_REAL}_fd"], fd_dict[f"{CSI_IMAG}_fd"], data_dict["csi"][trans, :])

    if params.num_eq > 0:
      save_complex_data(fd_dict[f"{EQUALIZER_REAL}_fd"], fd_dict[f"{EQUALIZER_IMAG}_fd"], data_dict["equalizer"][trans, :])

  return n_frames, data_dict


#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

def get_data_type(data):
  """
  Get the data type index. The second DMA symbol has the data type in the highest bit of the 8th byte for both CSI and IQ data.

  Args:
    data_type (str): Data type.

  Returns:
    int: Data type index.
  """

  data_type_bit = data[DATA_BIT_DMA_SYMBOL_IDX*8+DATA_BIT_BYTE_IDX]
  data_type_bit = data_type_bit >> (8-1)
  return data_type_bit


def get_num_dma_symbol_per_trans(params):
  """
  Get the number of DMA symbols per transaction for IQ and CSI data.

  Args:
    params (argparse.ArgumentParser): An ArgumentParser object that has been configured with command-line arguments.
  """

  if params.data_type == 'iq_all':
    iq_num_dma_symbol_per_trans = IQ_HEADER_LEN_DMA_SYM + params.iq_len + (params.iq_len // 2) + 1 # +1 for state in between, REVISIT: Last + 1 is an error
  else:
    iq_num_dma_symbol_per_trans = IQ_HEADER_LEN_DMA_SYM + params.iq_len

  csi_num_dma_symbol_per_trans = CSI_HEADER_LEN_DMA_SYM + CSI_LEN_DMA_SYM + params.num_eq * EQUALIZER_LEN_DMA_SYM

  if iq_num_dma_symbol_per_trans > 8187 or csi_num_dma_symbol_per_trans > 8187:
    raise ValueError('Limit params.iq_len or  to 8187! (Max UDP 65507 bytes; (65507/8)-1 = 8187)')

  return iq_num_dma_symbol_per_trans, csi_num_dma_symbol_per_trans


def is_abnormal_length(queue_data, data_type_idx, iq_bytes_per_trans, csi_bytes_per_trans, logger=None):
  """
  Check if the data length is abnormal based on the data type.

  Args:
    queue_data (bytes): The data received in the queue.
    data_type_idx (int): Index of the data type (e.g., CSI or IQ).
    iq_bytes_per_trans (int): Expected number of bytes per transaction for IQ data.
    csi_bytes_per_trans (int): Expected number of bytes per transaction for CSI data.

  Returns:
    bool: True if the data length is abnormal, False otherwise.
  """
  if data_type_idx == DATA_TYPE_LIST['iq']:
    if len(queue_data) % iq_bytes_per_trans != 0:
      msg = f"Abnormal IQ data length: {len(queue_data)} expected: {iq_bytes_per_trans}"
      print(msg)
      if logger is not None:
        logger.error(msg)
      return True

  elif data_type_idx == DATA_TYPE_LIST['csi']:
    if len(queue_data) % csi_bytes_per_trans != 0:
      msg = f"Abnormal CSI data length: {len(queue_data)} expected: {csi_bytes_per_trans}"
      print(msg)
      if logger is not None:
        logger.error(msg)
      return True

  return False















































