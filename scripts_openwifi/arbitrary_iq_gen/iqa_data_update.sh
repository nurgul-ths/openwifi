#!/bin/bash

#==============================================================================
# This script updates the IQ data on an FPGA by loading data from a specified
# binary file into the FPGA's FIFO through a sysfs interface. This setup
# ensures the data buffer is prepared for transmission.
#
# Usage:
#   ./iqa_data_update.sh [iq_arbitrary_fname]
#
# Arguments:
#   iq_arbitrary_fname : The name of the file containing the IQ data.
#                        If not provided, defaults to "htPreamble_720_15p5.bin".
#
# Note:
# - Ensure that the data file exists in the specified directory before running the script.
#==============================================================================

home_dir=$(pwd)

# Read script arguments or use default values
iq_arbitrary_fname=${1:-"htPreamble_720_15p5.bin"}

#==============================================================================
if test -d "/sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr"; then
  cd /sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr
else
  cd /sys/devices/soc0/fpga-axi\@0/fpga-axi\@0\:sdr
fi

#==============================================================================
# Reset all the values for the SRAM to ensure we are using the FIFO
echo 0 > tx_arbitrary_iq_sram_en
echo 0 > tx_arbitrary_iq_sram_reset
echo 0 > tx_arbitrary_iq_sram_select
echo 0 > tx_arbitrary_iq_sram_inf_loop_en
echo 0 > tx_arbitrary_iq_sram_n_tx_cnt
echo 0 > tx_arbitrary_iq_sram_repeat_spacing_ms

#==============================================================================
# Deliver data through sysfs with tx_intf_iq_data
cat /root/openwifi/arbitrary_iq_gen/$iq_arbitrary_fname > tx_intf_iq_data

cd "$home_dir"
