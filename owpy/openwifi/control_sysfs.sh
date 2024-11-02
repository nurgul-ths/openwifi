#!/bin/bash

# This script provides an interface to read and write sysfs variables of an AD9361 RF device.
#
# Detailed Description:
# The script enables users to interact with various hardware parameters of AD9361 devices
# through Linux's sysfs interface. It automatically locates the correct device directory
# and performs read/write operations on the specified variable.
#
# For comprehensive documentation of all AD9361 parameters, see:
# <https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9361>
#
# Available Variables (grouped by category):
# Calibration:
#   - calib_mode, calib_mode_available
#   - dcxo_tune_coarse, dcxo_tune_fine
#
# Operating Modes:
#   - ensm_mode, ensm_mode_available
#   - dev, power
#   - trx_rate_governor, trx_rate_governor_available
#
# RF Configuration:
#   - in_voltage_rf_bandwidth, out_voltage_rf_bandwidth
#   - in_voltage_sampling_frequency, out_voltage_sampling_frequency
#   - out_altvoltage0_RX_LO_frequency, out_altvoltage1_TX_LO_frequency
#
# Gain Control:
#   - in_voltage0_gain_control_mode, in_voltage1_gain_control_mode
#   - in_voltage0_hardwaregain, in_voltage1_hardwaregain
#   - out_voltage0_hardwaregain, out_voltage1_hardwaregain
#
# And many others... (see documentation link for complete list)

# Usage Examples:
# 1. Read TX1 gain:
#    ./control_sysfs.sh out_voltage1_hardwaregain read
#
# 2. Set TX1 gain to -6 dB:
#    ./control_sysfs.sh out_voltage1_hardwaregain write -6

function usage() {
  echo "Usage: $0 <variable_name> <action> [<value>]"
  echo ""
  echo "Arguments:"
  echo "  variable_name : Name of the sysfs variable to access"
  echo "  action       : 'read' or 'write'"
  echo "  value        : New value (required for write action)"
  echo ""
  echo "Examples:"
  echo "  $0 out_voltage1_hardwaregain read"
  echo "  $0 out_voltage1_hardwaregain write -6"
  exit 1
}

function sysfs_rd_wr() {
  local variable_name="$1"
  local action="$2"
  local value="$3"

  # Locate the correct IIO device directory (usually ad9361 is iio:device0)
  for i in {0..4}
  do
    if test -f "/sys/bus/iio/devices/iio:device${i}/in_voltage_rf_bandwidth"; then
      cd "/sys/bus/iio/devices/iio:device${i}/"
      break
    elif [ "$i" -eq 4 ]; then
      echo "Can not find in_voltage_rf_bandwidth!"
      echo "Check log to make sure ad9361 driver is loaded!"
      exit 1
    fi
  done

  if [ "$action" == "write" ]; then
    echo "$value" > "$variable_name"
  else
    echo "Invalid action specified. Use 'read' or 'write'."
    exit 1
  fi

  # Always read back the value
  echo "$variable_name"
  cat "$variable_name"
}

# Main script
if [ "$#" -lt 2 ]; then
  usage
fi

variable_name="$1"
action="$2"
value="$3"

sysfs_rd_wr "$variable_name" "$action" "$value"
