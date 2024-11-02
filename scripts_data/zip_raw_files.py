"""
zip_raw_files.py

This script traverses the 'data' directory in the 'openwifi_boards' repository.
It finds all files containing '_raw' in their names, zips them, and if successful,
deletes the original raw files to conserve space. Files that are already zipped are skipped.
"""

import os
import zipfile
import argparse

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

def zip_and_remove_raw_files(path_data, dry_run=False):
  """
  Traverses the specified directory, finds all files containing '_raw' in their names,
  zips them, and deletes the original files after verifying that the zip file was created
  successfully. Skips files that are already zipped.

  Args:
    path_data (str): The root directory to start the zipping process.
    dry_run (bool): If True, only print what would be done without actually zipping or deleting files.

  Returns:
    None
  """
  for dirpath, dirnames, filenames in os.walk(path_data):
    for filename in filenames:
      # Look for files containing '_raw' but skip already zipped files
      if "_raw" in filename and not filename.endswith('.zip'):
        print(f"{'[DRY RUN] ' if dry_run else ''}Processing file: {filename}")

        raw_file_path = os.path.join(dirpath, filename)

        # Skip empty files
        if os.path.getsize(raw_file_path) == 0:
          print(f"{'[DRY RUN] ' if dry_run else ''}Skipping empty file: {filename}")
          continue

        zip_file_path = os.path.splitext(raw_file_path)[0] + ".zip"

        if not dry_run:
          try:
            with zipfile.ZipFile(zip_file_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
              zipf.write(raw_file_path, arcname=os.path.basename(raw_file_path))

            # Perform verification checks
            if os.path.isfile(zip_file_path) and os.path.getsize(zip_file_path) > 0:
              with zipfile.ZipFile(zip_file_path, 'r') as zipf:

                # Check 1: CRC verification
                if zipf.testzip() is not None:
                  raise Exception("CRC check failed")

                # Check 2: File count (should be exactly 1 file in the zip)
                if len(zipf.namelist()) != 1:
                  raise Exception("Unexpected number of files in zip")

              print(f'Zipping succeeded, deleting the original file: {filename}')
              os.remove(raw_file_path)
            else:
              raise Exception("Zip file is empty or failed to create properly")

          except Exception as e:
            print(f'Error processing {filename}: {str(e)}')

            # Remove the incomplete zip file in case of failure
            if os.path.exists(zip_file_path):
              os.remove(zip_file_path)

        else:
          print(f"[DRY RUN] Would zip file: {raw_file_path}")
          print(f"[DRY RUN] Would create zip file: {zip_file_path}")
          print(f"[DRY RUN] Would delete original file after successful zipping")

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description="Zip raw files and optionally delete originals.")
  parser.add_argument("--dry-run", action="store_true", help="Perform a dry run without actually zipping or deleting files")
  args = parser.parse_args()

  zip_and_remove_raw_files(PATH_DATA, dry_run=args.dry_run)
