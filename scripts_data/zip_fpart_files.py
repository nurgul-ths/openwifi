"""
zip_fpart_files.py

This script traverses the 'data' directory in the 'openwifi_boards' repository.
It finds all files with the pattern "fpart" in their names (e.g., `shared_prefix_fpart0.txt`,
`shared_prefix_fpart1.txt`, etc.), groups them by shared prefix, zips them together,
and if successful, deletes the original files to conserve space. Already zipped files are skipped.

We only zip if there is a .processed file with the same prefix, and we only delete the original files.
Additionally, the script allows specifying the number of CPU cores to use for multiprocessing.
- `--num-cores 1`: Disables multiprocessing and runs serially (useful for debugging).
- `--num-cores -1`: Uses all available CPU cores (default behavior).
- `--num-cores N`: Uses `N` CPU cores, where `N` is a positive integer greater than 1.

Usage:
1. Set the PATH_DATA variable to point to the directory containing the files.
2. Run the script: python zip_fpart_files.py

The script will zip relevant fpart*.txt files with corresponding .processed files in the specified directory and its subdirectories.
"""

import os
import zipfile
from collections import defaultdict
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

def extract_prefix(filename):
  """
  Extracts the prefix from a filename, accounting for the extra underscore before 'fpart'.

  Args:
    filename (str): The name of the file.

  Returns:
    str: The extracted prefix.
  """
  parts = filename.split('_fpart')
  if len(parts) > 1:
    return parts[0]
  return filename.rsplit('.', 1)[0]  # fallback for .processed files

def zip_group(prefix, file_list, dry_run=False):
  """
  Zips a group of files sharing the same prefix into a single zip file and deletes the originals if successful.

  Args:
    prefix (str): The shared prefix of the files to be zipped.
    file_list (list): List of file paths to zip.
    dry_run (bool): If True, only simulate the actions without making changes.

  Returns:
    None
  """
  if len(file_list) <= 1:
    print(f"Skipping prefix '{prefix}': Not enough files to zip.")
    return

  zip_file_path = os.path.join(os.path.dirname(file_list[0]), f"{prefix}.zip")

  print()
  print(f"{'[DRY RUN] ' if dry_run else ''}Zipping files with prefix '{prefix}' into {zip_file_path}")

  if not dry_run:
    try:
      with zipfile.ZipFile(zip_file_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for file_path in file_list:
          zipf.write(file_path, arcname=os.path.basename(file_path))

      # Perform verification checks after zipping
      if os.path.isfile(zip_file_path) and os.path.getsize(zip_file_path) > 0:
        with zipfile.ZipFile(zip_file_path, 'r') as zipf:
          if zipf.testzip() is not None:
            raise Exception("CRC check failed")

          if len(zipf.namelist()) != len(file_list):
            raise Exception("Unexpected number of files in the zip")

        print(f"Zipping succeeded, deleting the original files for prefix '{prefix}'")
        for file_path in file_list:
          os.remove(file_path)
      else:
        raise Exception("Zip file is empty or failed to create properly")

    except Exception as e:
      print(f"Error processing files with prefix '{prefix}': {str(e)}")
      if os.path.exists(zip_file_path):
        os.remove(zip_file_path)
  else:
    print(f"[DRY RUN] Would zip these files: {', '.join(file_list)}")
    print(f"[DRY RUN] Would delete original files after successful zipping")

def zip_fpart_files(path_data, dry_run=False, num_cores=-1):
  """
  Zips files that share the same prefix (before '_fpart') into a single zip file,
  but only if a corresponding .processed file exists. Deletes the original files after
  verifying that the zip file was created successfully.

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
  # Dictionary to hold files grouped by their shared prefix
  file_groups     = defaultdict(list)
  processed_files = set()

  # First pass: identify all .processed files and fpart*.txt files
  for dirpath, dirnames, filenames in os.walk(path_data):
    for filename in filenames:
      if filename.endswith('.processed'):
        prefix = extract_prefix(filename)
        processed_files.add(prefix)
      elif "_fpart" in filename and filename.endswith('.txt'):
        prefix = extract_prefix(filename)
        file_groups[prefix].append(os.path.join(dirpath, filename))

  # Prepare list of groups to process
  groups_to_process = []
  for prefix, file_list in file_groups.items():
    if prefix in processed_files and len(file_list) > 1:
      groups_to_process.append((prefix, file_list))
    elif prefix not in processed_files:
      print(f"Skipping files with prefix '{prefix}': No corresponding .processed file found")

  total_groups = len(groups_to_process)
  if total_groups == 0:
    print("No file groups found to process.")
    return

  print(f"\nFound {total_groups} file group(s) to process.")

  if num_cores == 1:
    # Disable multiprocessing and run serially
    print("Multiprocessing disabled. Running in serial mode.")
    for group in groups_to_process:
      zip_group(*group, dry_run=dry_run)
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
    args = [(prefix, file_list, dry_run) for prefix, file_list in groups_to_process]

    with Pool(processes=num_processes) as pool:
      pool.starmap(zip_group, args)

  print("\nZipping process completed.")

#===============================================================================
# Main
#===============================================================================

def main():
  """
  Main function to initiate the zipping of fpart files.

  This function parses command-line arguments to determine whether to perform a dry run
  and how many CPU cores to use for multiprocessing. It then proceeds to find and
  process the relevant file groups accordingly.

  Usage:
    python zip_fpart_files.py [--dry-run] [--num-cores N]

  Options:
    --dry-run        Perform a dry run without actually zipping or deleting files.
    --num-cores N    Number of CPU cores to use.
                     -1: Use all available cores (default).
                      1: Disable multiprocessing (useful for debugging).
                      N: Use N CPU cores, where N is a positive integer greater than 1.
  """
  parser = argparse.ArgumentParser(description="Zip fpart*.txt files (with corresponding .processed files) and optionally delete originals.")
  parser.add_argument("--dry-run", action="store_true", help="Perform a dry run without actually zipping or deleting files")
  parser.add_argument("--num-cores", type=int, default=-1, help="Number of CPU cores to use. Use -1 for all available cores, 1 to disable multiprocessing (useful for debugging), or specify a positive integer for N cores.")
  args = parser.parse_args()

  try:
    zip_fpart_files(PATH_DATA, dry_run=args.dry_run, num_cores=args.num_cores)
  except ValueError as ve:
    print(f"Argument Error: {ve}")

if __name__ == '__main__':
  main()
