#!/bin/bash

# REVISIT: Move this one

# This script allows the user to interact with specific variables of a device.
# The user can either read the current value of a variable or write a new value to it.
# The variables that can be interacted with are:
#   calib_mode, calib_mode_available, dcxo_tune_coarse, dcxo_tune_fine, dev, ensm_mode,
#   ensm_mode_available, filter_fir_config, in_out_voltage_filter_fir_en, in_temp0_input,
#   in_voltage0_gain_control_mode, in_voltage0_hardwaregain, in_voltage0_rf_port_select,
#   in_voltage0_rssi, in_voltage1_gain_control_mode, in_voltage1_hardwaregain,
#   in_voltage1_rf_port_select, in_voltage1_rssi, in_voltage2_offset, in_voltage2_raw,
#   in_voltage2_scale, in_voltage_bb_dc_offset_tracking_en, in_voltage_filter_fir_en,
#   in_voltage_gain_control_mode_available, in_voltage_quadrature_tracking_en,
#   in_voltage_rf_bandwidth, in_voltage_rf_dc_offset_tracking_en,
#   in_voltage_rf_port_select_available, in_voltage_sampling_frequency, name,
#   out_altvoltage0_RX_LO_fastlock_load, out_altvoltage0_RX_LO_fastlock_save,
#   out_altvoltage0_RX_LO_fastlock_store, out_altvoltage0_RX_LO_frequency,
#   out_altvoltage1_TX_LO_fastlock_load, out_altvoltage1_TX_LO_fastlock_save,
#   out_altvoltage1_TX_LO_fastlock_store, out_altvoltage1_TX_LO_frequency,
#   out_voltage0_hardwaregain, out_voltage0_rf_port_select, out_voltage0_rssi,
#   out_voltage1_hardwaregain, out_voltage1_rf_port_select, out_voltage1_rssi,
#   out_voltage2_raw, out_voltage2_scale, out_voltage3_raw, out_voltage3_scale,
#   out_voltage_filter_fir_en, out_voltage_rf_bandwidth, out_voltage_rf_port_select_available,
#   out_voltage_sampling_frequency, power, rx_path_rates, trx_rate_governor,
#   trx_rate_governor_available, tx_path_rates, uevent
#
# See <https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9361>
#

# Usage
# ./control_sysfs.sh <variable_name> <action> [<value>]
#   variable_name: The name of the variable to interact with.
#   action: Either 'read' or 'write'.
#   value: The value to write to the variable. This parameter is required if the action is 'write'.

function usage() {
  echo "Usage: <variable_name> <action> [<value>]"
  echo "Example to read a value: ./control_sysfs.sh out_voltage1_hardwaregain read"
  echo "Example to write a value: ./control_sysfs.sh out_voltage1_hardwaregain write -6"
  exit 1
}

function sysfs_rd_wr() {
  local variable_name="$1"
  local action="$2"
  local value="$3"

  # Check which device directory to use
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
