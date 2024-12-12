"""
File management functions

REVISIT:
- Clean up here, some functions are not used anymore, check if they are not used elsewhere, also
  I don't even use the data loader functions anymore, I should check in a basic script that I can load the
  data and add a reference or put this script here in the repo next to files.py
- REVISIT: Rename fname_base to fname_template as we modify it, and base refers to when you just have the filename without the path.
- REVISIT: Maybe allow exp_fname_param_list to also take stuff from other dictionaries
- REVISIT: Make the files more compressed, quite large for now when saving in .csv, I need a file format that allows me to continuously write so
- if an experiment fails I don't lose the data. Maybe I can use h5py for that or .mat files, but I need to check if it allows me to write continuously.
"""

import json
import os
import numpy as np

from datetime import datetime
TODAY      = datetime.now().strftime("%Y-%m-%d")
TODAY_TIME = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

#==============================================================================
# File naming
#==============================================================================

# Constants used for file naming
TIMESTAMPS_CSI = "timestamps_csi"
TIMESTAMPS_IQ  = "timestamps_iq"
RAW            = "raw"

# data_type = "csi"
FREQ_OFFSET    = "freq_offset"
CSI_REAL       = "csi_real"
CSI_IMAG       = "csi_imag"
EQUALIZER_REAL = "equalizer_real"
EQUALIZER_IMAG = "equalizer_imag"

# data_type = "rssi_rx_iq0" or "rx_iq0_iq1"
FREQ        = "freq"
RX_IQ0_REAL = "rx_iq0_real"
RX_IQ0_IMAG = "rx_iq0_imag"
RX_IQ1_REAL = "rx_iq1_real"
RX_IQ1_IMAG = "rx_iq1_imag"
AGC         = "agc"
RSSI        = "rssi"

# data_type = "tx_rx_iq0" (also uses FREQ, RX_IQ0_REAL, and RX_IQ0_IMAG files from above)
TX_IQ0_REAL = "tx_iq0_real"
TX_IQ0_IMAG = "tx_iq0_imag"

# multi-static
TRIGGER = "trigger"

OPENWIFI_LOG = "openwifi_log"

# For naming timestamps etc., note that after the first timestmpa, there is 1 DMA symbol of metadata, then the rest of the timestamps
CSI_TIMESTAMP_NAMES = [
  "timestamp_phy_tx_start", "timestamp_phy_tx_started", "timestamp_tx_intf_iq0_sample0",
  "timestamp_short_preamble_detected", "timestamp_long_preamble_detected", "timestamp_csi_valid",
  "timestamp_pkt_header_valid_strobe"
]

IQ_TIMESTAMP_NAMES = [
  "timestamp"
]


def gen_fnames(params):
  """
  The base filename is built as
  1) f"{params.exp_fname_extra}_"
  2) Then, using params.exp_fname_param_list, we add each parameter mentioned there and its value to the filename

  Note that params.exp_dir is assumed to be located relative to this repository's root directory

  REVISIT: Be consistent in documenting params
  Args:
    params (argparse.ArgumentParser): ArgumentParser object with parameters
  """

  exp_name_extended = ""

  if params.exp_fname_extra is not None:
    exp_name_extended += f"{params.exp_fname_extra}_"
  else:
    exp_name_extended += ""

  if params.exp_fname_param_list:
    for attr in params.exp_fname_param_list.split():
      if getattr(params, attr) is not None:
        exp_name_extended += f"{attr}-{getattr(params, attr)}_"

  # Use os.join to also work on windows
  dataset_dir = params.exp_dir if params.exp_dataset is None else os.path.join(params.exp_dir, params.exp_dataset)

  params.date = TODAY_TIME

  try:
    params.exp_dir    = os.path.join(dataset_dir, params.board_name, params.data_type, params.loop_type, params.exp_name, TODAY)
    params.fname_base = os.path.join(params.exp_dir, f"{exp_name_extended}{params.date}")
  except AttributeError as e:
    raise ValueError("Missing required parameter for file path creation") from e

  print("\ngen_fnames()")
  print(f"\texp_fname_param_list: {params.exp_fname_param_list}")
  print(f"\tfname_base: {params.fname_base}")


def gen_data_fname_dict(params):
  """Generates the filenames for all the data files depending on the data_type we are collecting

  Args:
    params (argparse.ArgumentParser): The Params object containing all the parameters for the experiment

  Returns:
    dict: Dictionary containing the filenames for all the data files
  """

  data_fname_dict = {
    RAW + '_fname' : f"{params.fname_base}_{RAW}.csv"
  }

  if params.data_type == 'csi' or (params.system_mode == 'jmb' and params.data_type_jmb == 'csi'):
    data_fname_dict[FREQ_OFFSET    + '_fname'] = f"{params.fname_base}_{FREQ_OFFSET}.csv"
    data_fname_dict[CSI_REAL       + '_fname'] = f"{params.fname_base}_{CSI_REAL}.csv"
    data_fname_dict[CSI_IMAG       + '_fname'] = f"{params.fname_base}_{CSI_IMAG}.csv"
    data_fname_dict[EQUALIZER_REAL + '_fname'] = f"{params.fname_base}_{EQUALIZER_REAL}.csv"
    data_fname_dict[EQUALIZER_IMAG + '_fname'] = f"{params.fname_base}_{EQUALIZER_IMAG}.csv"
    data_fname_dict[FREQ           + '_fname'] = f"{params.fname_base}_{FREQ}.csv"
    data_fname_dict[TIMESTAMPS_CSI + '_fname'] = f"{params.fname_base}_{TIMESTAMPS_CSI}.csv"

  if params.data_type == "rssi_rx_iq0":
    data_fname_dict[FREQ          + '_fname'] = f"{params.fname_base}_{FREQ}.csv"
    data_fname_dict[RX_IQ0_REAL   + '_fname'] = f"{params.fname_base}_{RX_IQ0_REAL}.csv"
    data_fname_dict[RX_IQ0_IMAG   + '_fname'] = f"{params.fname_base}_{RX_IQ0_IMAG}.csv"
    data_fname_dict[AGC           + '_fname'] = f"{params.fname_base}_{AGC}.csv"
    data_fname_dict[RSSI          + '_fname'] = f"{params.fname_base}_{RSSI}.csv"
    data_fname_dict[TIMESTAMPS_IQ + '_fname'] = f"{params.fname_base}_{TIMESTAMPS_IQ}.csv"

  if params.data_type == "rx_iq0_iq1":
    data_fname_dict[FREQ          + '_fname'] = f"{params.fname_base}_{FREQ}.csv"
    data_fname_dict[RX_IQ0_REAL   + '_fname'] = f"{params.fname_base}_{RX_IQ0_REAL}.csv"
    data_fname_dict[RX_IQ0_IMAG   + '_fname'] = f"{params.fname_base}_{RX_IQ0_IMAG}.csv"
    data_fname_dict[RX_IQ1_REAL   + '_fname'] = f"{params.fname_base}_{RX_IQ1_REAL}.csv"
    data_fname_dict[RX_IQ1_IMAG   + '_fname'] = f"{params.fname_base}_{RX_IQ1_IMAG}.csv"
    data_fname_dict[TIMESTAMPS_IQ + '_fname'] = f"{params.fname_base}_{TIMESTAMPS_IQ}.csv"

  if params.data_type == "tx_rx_iq0":
    data_fname_dict[FREQ          + '_fname'] = f"{params.fname_base}_{FREQ}.csv"
    data_fname_dict[TX_IQ0_REAL   + '_fname'] = f"{params.fname_base}_{TX_IQ0_REAL}.csv"
    data_fname_dict[TX_IQ0_IMAG   + '_fname'] = f"{params.fname_base}_{TX_IQ0_IMAG}.csv"
    data_fname_dict[RX_IQ0_REAL   + '_fname'] = f"{params.fname_base}_{RX_IQ0_REAL}.csv"
    data_fname_dict[RX_IQ0_IMAG   + '_fname'] = f"{params.fname_base}_{RX_IQ0_IMAG}.csv"
    data_fname_dict[TIMESTAMPS_IQ + '_fname'] = f"{params.fname_base}_{TIMESTAMPS_IQ}.csv"

  if params.data_type == 'iq_all':
    data_fname_dict[FREQ          + '_fname'] = f"{params.fname_base}_{FREQ}.csv"
    data_fname_dict[TX_IQ0_REAL   + '_fname'] = f"{params.fname_base}_{TX_IQ0_REAL}.csv"
    data_fname_dict[TX_IQ0_IMAG   + '_fname'] = f"{params.fname_base}_{TX_IQ0_IMAG}.csv"
    data_fname_dict[RX_IQ0_REAL   + '_fname'] = f"{params.fname_base}_{RX_IQ0_REAL}.csv"
    data_fname_dict[RX_IQ0_IMAG   + '_fname'] = f"{params.fname_base}_{RX_IQ0_IMAG}.csv"
    data_fname_dict[RX_IQ1_REAL   + '_fname'] = f"{params.fname_base}_{RX_IQ1_REAL}.csv"
    data_fname_dict[RX_IQ1_IMAG   + '_fname'] = f"{params.fname_base}_{RX_IQ1_IMAG}.csv"
    data_fname_dict[TIMESTAMPS_IQ + '_fname'] = f"{params.fname_base}_{TIMESTAMPS_IQ}.csv"

  # With I/Q, we need to have separate trigger signals to know if our own or the other side is transmitting
  if params.system_mode == "jmb":
    data_fname_dict[TRIGGER + '_fname'] = f"{params.fname_base}_{TRIGGER}.csv"

  return data_fname_dict

#==============================================================================
# File creation
#==============================================================================
def gen_data_dir(params):
  """Creates the data directories if they do not exist"""
  os.makedirs(params.exp_dir, exist_ok=True)


def gen_files(params):
  """
  Generates the data files and returns a dictionary of filehandles to these
  Note that this function must be called after gen_fnames() and gen_data_dir() to generate the names and directory.

  For the sake of sharing parameters (params), call these 2 before multiprocessing starts
  but gen_files has to be called after multiprocessing starts in the process that writes to properly handle file management

  Note that when in the joint monostatic and bistatic mode, if we use I/Q data for both monosatic and bistatic data, they share
  the timestamp file since they anyway share the same data files, it's just the strigger file that distinguishes them.

  For joint mode where they are not the same, we make a separate timestamp file for each mode, but the data files are shared.

  If they don't

  Args:
    params (argparse.ArgumentParser): The Params object containing all the parameters for the experiment

  Returns:
    dict: Dictionary containing the filehandles for all the data files
  """

  data_fname_dict = gen_data_fname_dict(params)

  fd_dict = {
    f"{RAW}_fd" : open(data_fname_dict[f"{RAW}_fname"], "a")
  }

  # REVISIT: We can't just create a file for every rx antenna etc, so we add a file like trigger to later filter the RX_IQ0 etc. files
  if params.data_type == 'csi' or (params.system_mode == 'jmb' and params.data_type_jmb == 'csi'):
    fd_dict[f"{FREQ_OFFSET}_fd"]    = open(data_fname_dict[f"{FREQ_OFFSET}_fname"], "a")
    fd_dict[f"{CSI_REAL}_fd"]       = open(data_fname_dict[f"{CSI_REAL}_fname"], "a")
    fd_dict[f"{CSI_IMAG}_fd"]       = open(data_fname_dict[f"{CSI_IMAG}_fname"], "a")
    fd_dict[f"{EQUALIZER_REAL}_fd"] = open(data_fname_dict[f"{EQUALIZER_REAL}_fname"], "a")
    fd_dict[f"{EQUALIZER_IMAG}_fd"] = open(data_fname_dict[f"{EQUALIZER_IMAG}_fname"], "a")
    fd_dict[f"{FREQ}_fd"]           = open(data_fname_dict[f"{FREQ}_fname"], "a")
    fd_dict[f"{TIMESTAMPS_CSI}_fd"] = open(data_fname_dict[f"{TIMESTAMPS_CSI}_fname"], "a")

  if params.data_type == "rssi_rx_iq0":
    fd_dict[f"{FREQ}_fd"]          = open(data_fname_dict[f"{FREQ}_fname"], "a")
    fd_dict[f"{RX_IQ0_REAL}_fd"]   = open(data_fname_dict[f"{RX_IQ0_REAL}_fname"], "a")
    fd_dict[f"{RX_IQ0_IMAG}_fd"]   = open(data_fname_dict[f"{RX_IQ0_IMAG}_fname"], "a")
    fd_dict[f"{AGC}_fd"]           = open(data_fname_dict[f"{AGC}_fname"], "a")
    fd_dict[f"{RSSI}_fd"]          = open(data_fname_dict[f"{RSSI}_fname"], "a")
    fd_dict[f"{TIMESTAMPS_IQ}_fd"] = open(data_fname_dict[f"{TIMESTAMPS_IQ}_fname"], "a")

  if params.data_type == "rx_iq0_iq1":
    fd_dict[f"{FREQ}_fd"]          = open(data_fname_dict[f"{FREQ}_fname"], "a")
    fd_dict[f"{RX_IQ0_REAL}_fd"]   = open(data_fname_dict[f"{RX_IQ0_REAL}_fname"], "a")
    fd_dict[f"{RX_IQ0_IMAG}_fd"]   = open(data_fname_dict[f"{RX_IQ0_IMAG}_fname"], "a")
    fd_dict[f"{RX_IQ1_REAL}_fd"]   = open(data_fname_dict[f"{RX_IQ1_REAL}_fname"], "a")
    fd_dict[f"{RX_IQ1_IMAG}_fd"]   = open(data_fname_dict[f"{RX_IQ1_IMAG}_fname"], "a")
    fd_dict[f"{TIMESTAMPS_IQ}_fd"] = open(data_fname_dict[f"{TIMESTAMPS_IQ}_fname"], "a")

  if params.data_type == "tx_rx_iq0":
    fd_dict[f"{FREQ}_fd"]          = open(data_fname_dict[f"{FREQ}_fname"], "a")
    fd_dict[f"{TX_IQ0_REAL}_fd"]   = open(data_fname_dict[f"{TX_IQ0_REAL}_fname"], "a")
    fd_dict[f"{TX_IQ0_IMAG}_fd"]   = open(data_fname_dict[f"{TX_IQ0_IMAG}_fname"], "a")
    fd_dict[f"{RX_IQ0_REAL}_fd"]   = open(data_fname_dict[f"{RX_IQ0_REAL}_fname"], "a")
    fd_dict[f"{RX_IQ0_IMAG}_fd"]   = open(data_fname_dict[f"{RX_IQ0_IMAG}_fname"], "a")
    fd_dict[f"{TIMESTAMPS_IQ}_fd"] = open(data_fname_dict[f"{TIMESTAMPS_IQ}_fname"], "a")

  if params.data_type == "iq_all":
    fd_dict[f"{FREQ}_fd"]          = open(data_fname_dict[f"{FREQ}_fname"], "a")
    fd_dict[f"{TX_IQ0_REAL}_fd"]   = open(data_fname_dict[f"{TX_IQ0_REAL}_fname"], "a")
    fd_dict[f"{TX_IQ0_IMAG}_fd"]   = open(data_fname_dict[f"{TX_IQ0_IMAG}_fname"], "a")
    fd_dict[f"{RX_IQ0_REAL}_fd"]   = open(data_fname_dict[f"{RX_IQ0_REAL}_fname"], "a")
    fd_dict[f"{RX_IQ0_IMAG}_fd"]   = open(data_fname_dict[f"{RX_IQ0_IMAG}_fname"], "a")
    fd_dict[f"{RX_IQ1_REAL}_fd"]   = open(data_fname_dict[f"{RX_IQ1_REAL}_fname"], "a")
    fd_dict[f"{RX_IQ1_IMAG}_fd"]   = open(data_fname_dict[f"{RX_IQ1_IMAG}_fname"], "a")
    fd_dict[f"{TIMESTAMPS_IQ}_fd"] = open(data_fname_dict[f"{TIMESTAMPS_IQ}_fname"], "a")

  if params.system_mode == "jmb":
    fd_dict[f"{TRIGGER}_fd"] = open(data_fname_dict[f"{TRIGGER}_fname"], "a")

  # Write header of timestamps into CSV file (based on which of the timestamp files we have)
  # you can just check for iq or csi timestamp in the data_fname_dict
  if f"{TIMESTAMPS_IQ}_fname" in data_fname_dict:
    np.savetxt(fd_dict[f"{TIMESTAMPS_IQ}_fd"], IQ_TIMESTAMP_NAMES, delimiter=" ", fmt="%s")

  if f"{TIMESTAMPS_CSI}_fname" in data_fname_dict:
    np.savetxt(fd_dict[f"{TIMESTAMPS_CSI}_fd"], CSI_TIMESTAMP_NAMES, delimiter=" ", fmt="%s")

  return fd_dict


def close_files(fd_dict):
  """Closes all the file handles for data files"""
  for fd in fd_dict.values():
    fd.close()


def gen_log_file(params):
  """Generates the log fname, the file, and dumps the parameters into it"""

  if not params.save_log:
    return

  params.log_fname = f"{params.fname_base}_{OPENWIFI_LOG}.txt"

  log_fname_base = os.path.basename(params.log_fname)
  log_path       = os.path.dirname(params.log_fname)

  # check their lengths
  print("\ngen_log_file()")
  print("\tLength of the log file name: ", len(log_fname_base))
  print("\tLength of the path for log file: ", len(log_path))

  with open(params.log_fname, 'w') as f:
    json.dump(params.__dict__, f, indent=2, sort_keys=True)

  print(f"\tLogfile {params.log_fname} created")

  params.notes_fname = f"{params.fname_base}_notes.txt"
  open(params.notes_fname, 'a').close()
  print(f"\tNote {params.notes_fname} created")


def update_log_file(params, new_data):
  """Appends new data to the log file while maintaining JSON structure."""
  try:
    with open(params.log_fname, 'r') as f:
      data = json.load(f)
  except FileNotFoundError:
    data = {}
  except json.JSONDecodeError:
    print("Warning: Invalid JSON format. Starting with an empty dictionary.")
    data = {}

  data.update(new_data)

  with open(params.log_fname, 'w') as f:
    json.dump(data, f, indent=2, sort_keys=True)


#==============================================================================
# File saving
#==============================================================================
def save_data(fname, data, row_format=True, fmt='%f'):
  """
  Save the data to a file with the specified format.

  Args:
    fname (str): File name or path to save the data.
    data (numpy.ndarray): Data array to be saved.
    row_format (bool, optional): If True, data is saved in a row-wise format. If False, data is saved in a column-wise format. Defaults to True.
    fmt (str, optional): Format string for each element in data. Defaults to '%f'.

  """
  if row_format:
    data = data.reshape(1, -1) # Ensure data is saved one row at a time
  else:
    data = data.reshape(-1, 1) # Ensure data is saved one column at a time

  np.savetxt(fname, data, fmt=fmt)


def save_complex_data(fname_real, fname_imag, data, row_format=True, fmt='%f'):
  """Save the real and imaginary parts of complex data to separate files.
  """
  save_data(fname_real, np.real(data), row_format, fmt)
  save_data(fname_imag, np.imag(data), row_format, fmt)

