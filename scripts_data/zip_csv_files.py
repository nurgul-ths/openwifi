"""
zip_csv_files.py

This script traverses the 'data' directory in the 'openwifi_boards' repository.
It finds all `.csv` files, zips them into `.csv.zip` format, and if successful,
deletes the original `.csv` files to conserve space. Files that are already zipped are skipped.

Additionally, the script allows specifying the number of CPU cores to use for multiprocessing.
- `--num-cores 1`: Disables multiprocessing and runs serially (useful for debugging).
- `--num-cores -1`: Uses all available CPU cores.
- `--num-cores N`: Uses `N` CPU cores, where `N` is a positive integer greater than 1.
"""

import os
import zipfile
import argparse
from multiprocessing import Pool, cpu_count

#===============================================================================
# Constants
#===============================================================================

# Define the path to the directory containing the files
PATH_REPO = '../../openwifi_boards'
PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air')
# PATH_DATA = os.path.join(PATH_REPO, 'data', 'raw', 'channel_hopping_movement', 'zed_fmcs2', 'rx_iq0_iq1', 'air', 'channel_fixed_calibration_a2')

#===============================================================================
# Functions
#===============================================================================

def process_file(file_path, dry_run):
  """
  Process a single CSV file: zip it and delete the original if successful.

  Args:
    file_path (str): The path to the CSV file to process.
    dry_run (bool): If True, only simulate the actions without making changes.

  Returns:
    bool: True if file was processed successfully, False otherwise.
  """
  filename = os.path.basename(file_path)
  print(f"{'[DRY RUN] ' if dry_run else ''}Processing file: {filename}")

  # Skip empty files
  if os.path.getsize(file_path) == 0:
    print(f"{'[DRY RUN] ' if dry_run else ''}Skipping empty file: {filename}")
    return False

  zip_file_path = os.path.splitext(file_path)[0] + ".csv.zip"

  if not dry_run:
    try:
      with zipfile.ZipFile(zip_file_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipf.write(file_path, arcname=os.path.basename(file_path))

      # Perform verification checks
      if os.path.isfile(zip_file_path) and os.path.getsize(zip_file_path) > 0:
        with zipfile.ZipFile(zip_file_path, 'r') as zipf:
          # Check 1: CRC verification
          if zipf.testzip() is not None:
            raise Exception("CRC check failed")

          # Check 2: File count
          if len(zipf.namelist()) != 1:
            raise Exception("Unexpected number of files in zip")

        print(f'Zipping succeeded, deleting the original file: {filename}')
        os.remove(file_path)
        return True
      else:
        raise Exception("Zip file is empty or failed to create properly")

    except Exception as e:
      print(f'Error processing {filename}: {str(e)}')
      # Remove the incomplete zip file in case of failure
      if os.path.exists(zip_file_path):
        os.remove(zip_file_path)
      return False
  else:
    print(f"[DRY RUN] Would zip file: {file_path}")
    print(f"[DRY RUN] Would create zip file: {zip_file_path}")
    print(f"[DRY RUN] Would delete original file after successful zipping")
    return True

def zip_csv_files(path_data, dry_run=False, num_cores=-1):
  """
  Zips all .csv files in the directory and deletes the original files
  after verifying that the zip file was created successfully.

  Args:
    path_data (str): The root directory to start the zipping process.
    dry_run (bool): If True, only print what would be done without actually zipping or deleting files.
    num_cores (int): Number of CPU cores to use.
                     -1: Use all available cores.
                      1: Disable multiprocessing (run serially).
                      N: Use N CPU cores.

  Returns:
    None
  """
  csv_files = []
  for dirpath, _, filenames in os.walk(path_data):
    for filename in filenames:
      if filename.endswith('.csv') and not filename.endswith('.csv.zip'):
        csv_files.append(os.path.join(dirpath, filename))

  total_files = len(csv_files)
  if total_files == 0:
    print("No CSV files found to process.")
    return

  print(f"Found {total_files} CSV files to process.")

  if num_cores == 1:
    # Disable multiprocessing and run serially
    print("Multiprocessing disabled. Running in serial mode.")
    results = []
    for f in csv_files:
      result = process_file(f, dry_run)
      results.append(result)
  else:
    # Determine the number of processes
    if num_cores == -1:
      num_processes = cpu_count()
    elif num_cores > 1:
      num_processes = min(num_cores, cpu_count())
    else:
      raise ValueError("Invalid value for num_cores. Use -1 for all cores or a positive integer.")

    print(f"Using {num_processes} CPU core(s) for multiprocessing.")

    # Prepare arguments for starmap
    args = [(f, dry_run) for f in csv_files]

    with Pool(processes=num_processes) as pool:
      results = pool.starmap(process_file, args)

  processed = sum(results)
  skipped_or_failed = total_files - processed
  print(f"Total files processed successfully: {processed}")
  print(f"Total files skipped or failed: {skipped_or_failed}")

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description="Zip CSV files and optionally delete originals.")
  parser.add_argument("--dry-run", action="store_true", help="Perform a dry run without actually zipping or deleting files")
  parser.add_argument("--num-cores", type=int, default=-1, help="Number of CPU cores to use. Use -1 for all available cores, 1 to disable multiprocessing (useful for debugging), or specify a positive integer for N cores.")
  args = parser.parse_args()

  try:
    zip_csv_files(PATH_DATA, dry_run=args.dry_run, num_cores=args.num_cores)
  except ValueError as ve:
    print(f"Argument Error: {ve}")
