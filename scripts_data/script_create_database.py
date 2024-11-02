#!/usr/bin/env python

"""
script_create_database.py

This script creates an overview of datasets for each subset of the data (air, cabled, int).
It processes log files, extracts relevant fields, and creates a JSON database file.

Usage:
1. Set the PATH_DATA variable to point to the directory containing the datasets.
2. Run the script: python script_create_database.py

The script will create 'database.json' files in each relevant subdirectory and report any errors encountered.
"""

import os
import json
import traceback

#===============================================================================
# Constants
#===============================================================================

PATH_REPO = '../../openwifi_boards'
PATH_DATA = os.path.join(PATH_REPO, 'data')

FIELD_NAMES = [
  "fname_base", "date", "exp_descr", "bb_rx_gain", "bb_tx_gain", "rf_tx0_atten", "rf_tx1_atten", "rf_rx_gain", "freq", "board_name", "sampling_time",
  "cdd_en", "tx_ant_dual_en",
  "cnc1_enable", "cnc1_dist_mm", "cnc1_freq_cycles_minute", "cnc1_duration_minutes", "cnc1_usbN",
  "cnc2_enable", "cnc2_dist_mm", "cnc2_freq_cycles_minute", "cnc2_duration_minutes", "cnc2_usbN",
  "room", "location", "ref_file_name", 'label',
  'filter_length', 'filter_shift', 'filter_reset', 'filter_n_int', 'filter_bitwidth', 'filter_bias_enable', 'filter_bias_n_int', 'filter_bias_bitwidth', 'filter_enabled',
  'ant_arrangement',
  'local_machine_first_sample_unix', 'local_machine_last_sample_unix',
  'external_machine_first_sample_unix', 'capture_file', 'filename_of_fpart0_file'
]

#===============================================================================
# Functions
#===============================================================================

def list_subdirectories(path):
  """Get all subdirectories of a given path that contain an openwifi_log.txt file."""
  subdirs = set()
  for root, dirs, files in os.walk(path):
    for file in files:
      if file.endswith('openwifi_log.txt'):
        subdirs.add(os.path.dirname(root))  # Use dirname to get the parent directory
  return sorted(subdirs)

def find_log_files(path):
  """Get all logfiles in a given path."""
  return [os.path.join(root, file) for root, _, files in os.walk(path)
      for file in files if file.endswith('openwifi_log.txt')]

def extract_fields(log_file):
  """Extract the fields from a given log file."""
  with open(log_file, "r") as file:
    content = json.load(file)
    fields = {"fname_base": content.get("fname_base", "").replace(PATH_REPO + '/', '')}
    fields.update({field: content.get(field) for field in FIELD_NAMES[1:]})
  return fields

def process_exp_descr(exp_descr):
  """Process the experiment description for proper formatting."""
  exp_descr = exp_descr.strip()
  if not exp_descr.endswith('\n'):
    exp_descr += '\n'
  return '\n\t'.join(exp_descr.splitlines())

def create_database(path_data_subset, verbose=False):
  """Create a database for a given data subset."""
  log_files = find_log_files(path_data_subset)
  unsorted_database = {}
  errors = []

  for log_file in log_files:
    try:
      unsorted_database[log_file] = extract_fields(log_file)
    except Exception as e:
      errors.append((log_file, str(e)))
      if verbose:
        print(f"Error processing {log_file}: {e}")

  sorted_log_files = sorted(unsorted_database.items(), key=lambda item: item[1].get("date", ""))

  database = {}
  for dataset_number, (_, entry) in enumerate(sorted_log_files, start=1):
    if verbose:
      print(f"{dataset_number} {entry['fname_base']}")
      print(f"\t{entry.get('date', 'N/A')}")
      print(f"\t{process_exp_descr(entry.get('exp_descr', 'N/A'))}")

    database[dataset_number] = entry

  return database, errors

def save_database(database, path_data_subset):
  """Save the database to a JSON file."""
  fname = os.path.join(path_data_subset, 'database.json')
  os.makedirs(os.path.dirname(fname), exist_ok=True)
  with open(fname, 'w') as outfile:
    json.dump(database, outfile, indent=2, sort_keys=True)

def update_json_numbering(raw_json_path, interim_json_path, verbose=False):
  """Update the numbering in the interim JSON file based on the raw JSON file."""
  with open(raw_json_path, 'r') as f:
    raw_data = json.load(f)
  with open(interim_json_path, 'r') as f:
    interim_data = json.load(f)

  if verbose:
    print(f"Raw data: {raw_json_path}")
    print(f"Interim data: {interim_json_path}")

  fname_base_to_raw_number = {entry['fname_base']: number for number, entry in raw_data.items()}
  updated_interim_data = {}

  for number, entry in interim_data.items():
    raw_number = fname_base_to_raw_number.get(entry['fname_base'].replace('interim', 'raw'))
    if raw_number:
      updated_interim_data[raw_number] = entry
    else:
      print(f"Discrepancy found: {entry['fname_base']} in interim data does not match any in raw data.")

  updated_interim_data = dict(sorted(updated_interim_data.items(), key=lambda item: item[1].get("date", "")))

  with open(interim_json_path, 'w') as f:
    json.dump(updated_interim_data, f, indent=2, sort_keys=True)

def process_interim_data(paths_list, verbose=False):
  """Process and update interim data."""

  for path_data_subset in paths_list:
    if 'interim' in path_data_subset:
      raw_json_path     = os.path.join(path_data_subset.replace('interim', 'raw'), 'database.json')
      interim_json_path = os.path.join(path_data_subset, 'database.json')

      if verbose:
        print(f"Checking for raw and interim data: {raw_json_path} and {interim_json_path}")

      if os.path.exists(raw_json_path) and os.path.exists(interim_json_path):
        update_json_numbering(raw_json_path, interim_json_path, verbose)

#===============================================================================
# Main
#===============================================================================

def main(verbose=False):
  paths_list = list_subdirectories(PATH_DATA)
  all_errors = []

  for path_data_subset in paths_list:
    if verbose:
      print("\n--------------------------------------------------")
      print(f"Processing data: {path_data_subset}")

    try:
      database, errors = create_database(path_data_subset, verbose)
      save_database(database, path_data_subset)
      all_errors.extend([(path_data_subset, *error) for error in errors])
    except Exception as e:
      all_errors.append((path_data_subset, "General error", str(e)))
      if verbose:
        print(f"Error processing {path_data_subset}: {e}")
        print(traceback.format_exc())

  process_interim_data(paths_list, verbose)

  if all_errors:
    print("\n\nErrors encountered during processing:")
    for error in all_errors:
      print(f"Path: {error[0]}, File: {error[1]}, Error: {error[2]}")

if __name__ == '__main__':
  main(verbose=False)
