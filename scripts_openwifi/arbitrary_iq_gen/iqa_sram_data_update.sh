#!/bin/bash

#==============================================================================
# This script updates the IQ data on an FPGA by loading data from a specified
# binary file into a selected SRAM block. Ensure `iq_arbitrary_fname` points
# to the correct data file.
#
# Usage:
#   ./iqa_sram_data_update.sh [iq_arbitrary_fname] [iq_sram_sel]
#
# Arguments:
#   iq_arbitrary_fname : Name of the file containing the IQ data.
#                        Default is "htPreamble_720_15p5.bin".
#   iq_sram_sel        : SRAM block to write to (0 or 1). Default is 0.
#==============================================================================

# Save the initial directory to return to later
home_dir=$(pwd)

# Read script arguments or use default values
iq_arbitrary_fname=${1:-"htPreamble_720_15p5.bin"}
iq_sram_sel=${2:-0}

#==============================================================================
# Navigate to the appropriate FPGA directory
if test -d "/sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr"; then
  cd /sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr
else
  cd /sys/devices/soc0/fpga-axi\@0/fpga-axi\@0\:sdr
fi

#==============================================================================
# Reset non-selected SRAM settings
echo 0 > tx_arbitrary_iq_sram_inf_loop_en
echo 0 > tx_arbitrary_iq_sram_n_tx_cnt
echo 0 > tx_arbitrary_iq_sram_repeat_spacing_ms

#==============================================================================
# Select the SRAM block and write data to it
echo $iq_sram_sel > tx_arbitrary_iq_sram_select
cat /root/openwifi/arbitrary_iq_gen/$iq_arbitrary_fname > tx_intf_iq_data_sram

# Return to the original directory
cd "$home_dir"
