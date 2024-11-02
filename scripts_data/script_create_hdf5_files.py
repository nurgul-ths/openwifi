"""
script_create_hdf5_files.py

This script converts CSV files (both `.csv` and `.csv.zip`) to HDF5 format for more efficient storage and access.
It processes all CSV files in the specified directory and its subdirectories, excluding files with '_raw' in their names.
It does not delete any original files after the conversion process. HDF5 files are created with gzip compression.
Extracted CSV files from zip archives are removed after processing.

Additionally, the script allows specifying the number of CPU cores to use for multiprocessing.
- `--num-cores 1`: Disables multiprocessing and runs serially (useful for debugging).
- `--num-cores -1`: Uses all available CPU cores (default behavior).
- `--num-cores N`: Uses `N` CPU cores, where `N` is a positive integer greater than 1.

Usage:
1. Set the PATH_DATA variable to point to the directory containing CSV files.
2. Run the script: python script_create_hdf5_files.py

The script will create corresponding `.hdf5` files for each CSV file it processes.
"""

import os
import zipfile
import numpy as np
import pandas as pd
import h5py
import argparse
from multiprocessing import Pool, cpu_count

#===============================================================================
# Constants
#===============================================================================

PATH_REPO = '../../openwifi_boards'
# Uncomment the desired PATH_DATA or set your own
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_fixed_cnc')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_hopping_cnc')
PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air')

# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_fixed_walking_a2')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_hopping_walking_a2')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_fixed_walking_a1')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_hopping_walking_a1')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_fixed_walking_a2')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_fixed_calibration_a2')

# Compression level setting (0 for no compression, 9 for max compression)
# Actually, for h5py, the default is 4 https://docs.h5py.org/en/stable/high/dataset.html
# 6 seems to take a very long time to read
COMPRESSION_LEVEL = 6  # Adjust this between 0 (no compression) to 9 (max compression), 6 is the default. We do not seem to benefit from 9. 6 is a good compromise in speed and compression ratio.

#===============================================================================
# Functions
#===============================================================================

def unzip_file(zip_file_path, output_dir):
  """
  Unzips a zip file into the specified output directory.

  Args:
    zip_file_path (str): The path to the zip file.
    output_dir (str): The directory to extract the files to.

  Returns:
    list: List of extracted file names.
  """
  with zipfile.ZipFile(zip_file_path, 'r') as zip_ref:
    zip_ref.extractall(output_dir)
    return zip_ref.namelist()


def save_df_to_hdf5(df, file_name, compression_level=COMPRESSION_LEVEL):
  """
  Saves a pandas DataFrame to an HDF5 file with compression.

  Args:
    df (pandas.DataFrame): The DataFrame to save.
    file_name (str): The name of the output HDF5 file.
    compression_level (int): The compression level to use for the HDF5 file.
  """
  with h5py.File(file_name, 'w') as hdf:
    for column in df.columns:
      hdf.create_dataset(column, data=np.array(df[column]), compression='gzip', compression_opts=compression_level)


def save_np_to_hdf5(data, file_name, compression_level=COMPRESSION_LEVEL, dtype=None):
  """
  Saves a numpy array to an HDF5 file with compression.

  Args:
    data (numpy.ndarray): The numpy array to save.
    file_name (str): The name of the output HDF5 file.
    compression_level (int): The compression level to use for the HDF5 file.
    dtype (numpy.dtype, optional): The data type for the HDF5 dataset.
  """
  with h5py.File(file_name, 'w') as hdf:
    hdf.create_dataset('data', data=data, compression='gzip', compression_opts=compression_level, dtype=dtype)


def process_file(filename, dirpath, dry_run=False, compression_level=COMPRESSION_LEVEL):
  """
  Processes a single file, converting it from CSV to HDF5 format.

  Args:
    filename (str): The name of the file to process.
    dirpath (str): The directory path where the file is located.
    dry_run (bool): If True, only simulate the actions without making changes.
    compression_level (int): The compression level to use for the HDF5 file.

  Returns:
    None
  """

  # Handle zip and CSV file paths properly
  if filename.endswith('.csv.zip'):
    base_filename = os.path.splitext(os.path.splitext(filename)[0])[0]  # Remove both '.csv' and '.zip'
  else:
    base_filename = os.path.splitext(filename)[0]  # Remove '.csv'

  # Construct the output HDF5 file path
  hdf5_file_path = os.path.join(dirpath, base_filename + ".hdf5")

  # Skip if HDF5 file already exists
  if os.path.exists(hdf5_file_path):
    print(f"Skipping {filename}: HDF5 file already exists")
    return

  csv_file_path = os.path.join(dirpath, filename)
  print(f"{'[DRY RUN] ' if dry_run else ''}Processing file: {filename}")

  extracted_csv = None
  if filename.endswith('.csv.zip'):
    if not dry_run:
      extracted_files = unzip_file(csv_file_path, dirpath)
      csv_file_name   = [f for f in extracted_files if f.endswith('.csv')][0]
      extracted_csv   = os.path.join(dirpath, csv_file_name)
      csv_file_path   = extracted_csv
    else:
      print(f"[DRY RUN] Would unzip: {filename}")
      return

  if not dry_run:
    try:
      # Convert the file to HDF5
      try:
        data = np.loadtxt(csv_file_path)
        save_np_to_hdf5(data, hdf5_file_path, compression_level=compression_level)
        print(f"Successfully converted {filename} to HDF5 using numpy")

      except Exception as e:
        print(f"Failed to load {filename} as numpy, trying pandas: {e}")
        try:
          data = pd.read_csv(csv_file_path, sep=" ")
          save_df_to_hdf5(data, hdf5_file_path, compression_level=compression_level)
          print(f"Successfully converted {filename} to HDF5 using pandas")

        except Exception as e:
          print(f"Error processing file {filename}: {e}")
          print(f"Failed to convert {filename} to HDF5")

    # Remove the extracted CSV file if it exists
    finally:
      if extracted_csv and os.path.exists(extracted_csv):
        os.remove(extracted_csv)
        print(f"Removed extracted file: {extracted_csv}")

  else:
    print(f"[DRY RUN] Would convert {filename} to HDF5: {hdf5_file_path}")
    if extracted_csv:
      print(f"[DRY RUN] Would remove extracted file: {extracted_csv}")


def process_csv_to_hdf5(path_data, dry_run=False, compression_level=COMPRESSION_LEVEL, num_cores=-1):
  """
  Processes all CSV and CSV.zip files, converts them to HDF5 format,
  and applies gzip compression. Removes extracted CSV files after processing.

  Args:
    path_data (str): The directory where the CSV files are located.
    dry_run (bool): If True, only print what would be done without actually converting files.
    compression_level (int): The compression level to use for the HDF5 files.
    num_cores (int): Number of CPU cores to use.
                     -1: Use all available cores.
                      1: Disable multiprocessing (run serially).
                      N: Use N CPU cores.

  Returns:
    None
  """
  tasks = []

  for dirpath, _, filenames in os.walk(path_data):
    for filename in filenames:
      if (filename.endswith('.csv') or filename.endswith('.csv.zip')) and '_raw' not in filename:
        tasks.append((filename, dirpath, dry_run, compression_level))

  total_files = len(tasks)

  if total_files == 0:
    print("No CSV or CSV.zip files found to process.")
    return

  print(f"Found {total_files} CSV/CSV.zip files to process.")

  if num_cores == 1:
    # Disable multiprocessing and run serially
    print("Multiprocessing disabled. Running in serial mode.")
    for task in tasks:
      process_file(*task)
  else:
    # Determine the number of processes
    if num_cores == -1:
      num_processes = cpu_count()
    elif num_cores > 1:
      num_processes = min(num_cores, cpu_count())
    else:
      raise ValueError("Invalid value for num_cores. Use -1 for all cores or a positive integer.")

    print(f"Using {num_processes} CPU core(s) for multiprocessing.")

    with Pool(processes=num_processes) as pool:
      pool.starmap(process_file, tasks)

  print("Processing completed.")


#===============================================================================
# Main
#===============================================================================

def main():
  """
  Main function to initiate the conversion of CSV files to HDF5 format.

  This function parses command-line arguments to determine whether to perform a dry run
  and how many CPU cores to use for multiprocessing. It then proceeds to find and
  process the relevant CSV files accordingly.

  Usage:
    python script_create_hdf5_files.py [--dry-run] [--num-cores N]

  Options:
    --dry-run        Perform a dry run without actually converting files.
    --num-cores N    Number of CPU cores to use.
                     -1: Use all available cores (default).
                      1: Disable multiprocessing (useful for debugging).
                      N: Use N CPU cores, where N is a positive integer greater than 1.
  """
  parser = argparse.ArgumentParser(description="Convert CSV files to HDF5 format with optional multiprocessing.")
  parser.add_argument("--dry-run", action="store_true", help="Perform a dry run without actually converting files")
  parser.add_argument("--num-cores", type=int, default=-1, help="Number of CPU cores to use. Use -1 for all available cores, 1 to disable multiprocessing (useful for debugging), or specify a positive integer for N cores.")
  parser.add_argument("--compression-level", type=int, default=COMPRESSION_LEVEL, help="Set the compression level for the HDF5 files")
  args = parser.parse_args()

  try:
    process_csv_to_hdf5(PATH_DATA, dry_run=args.dry_run, compression_level=args.compression_level, num_cores=args.num_cores)
  except ValueError as ve:
    print(f"Argument Error: {ve}")


if __name__ == "__main__":
  main()










# def process_csv_to_hdf5(path_data, dry_run=False, compression_level=COMPRESSION_LEVEL):
#   """
#   Processes all CSV and CSV.zip files, converts them to HDF5 format,
#   and applies gzip compression. Removes extracted CSV files after processing.

#   Args:
#     path_data (str): The directory where the CSV files are located.
#     dry_run (bool): If True, only print what would be done without actually converting files.

#   Returns:
#     None
#   """
#   for dirpath, _, filenames in os.walk(path_data):
#     for filename in filenames:
#       # Skip files that are not CSV or zipped CSV
#       if not (filename.endswith('.csv') or filename.endswith('.csv.zip')):
#         continue

#       # Skip files with '_raw' in their names
#       if '_raw' in filename:
#         continue
