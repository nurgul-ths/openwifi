#!/bin/bash

#==============================================================================
# This script copies all `.bin` and `.txt` files from a specified local directory
# to a remote OpenWiFi board using SCP (secure copy protocol). It can be useful
# for transferring generated binary or text data files from a local development
# environment to the board for further processing or testing.
#
# Usage:
#   ./copy_to_openwifi.sh
#
# Notes:
# - Ensure that you have SSH access to the remote host without requiring a password,
#   or be prepared to enter the SSH password for each file transfer.
#
#==============================================================================

# Remote host and directory information
REMOTE_USER="root"                        # Username for remote host
REMOTE_HOST="192.168.10.122"              # IP address or hostname of the remote OpenWiFi board
REMOTE_DIR="/root/openwifi/arbitrary_iq_gen"  # Destination directory on the remote host

# Local directory containing the files to be copied
SOURCE_DIR="output"                       # Directory where .bin and .txt files are stored locally

#==============================================================================
# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Directory $SOURCE_DIR does not exist. Exiting."
  exit 1
fi

# Change to the source directory
cd "$SOURCE_DIR"

#==============================================================================
# Loop over .bin and .txt files in the source directory and copy each to the remote host
for file in *.bin *.txt; do
  # Check if the file exists (in case there are no matching files)
  if [ -f "$file" ]; then
    echo "Copying $file to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}..."
    scp "$file" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"

    # Check if scp was successful
    if [ $? -ne 0 ]; then
      echo "Warning: Failed to copy $file"
    fi
  else
    echo "No .bin or .txt files found in $SOURCE_DIR."
    break
  fi
done

# Return to the original directory
cd ..

# Final message
echo "All files have been copied."
