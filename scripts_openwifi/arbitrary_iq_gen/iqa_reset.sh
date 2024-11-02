#!/bin/bash

#==============================================================================
# This script resets all arbitrary I/Q settings on the FPGA.
#
# Note:
# - This reset is typically needed when switching from arbitrary I/Q mode to
#   other modes (e.g., packet injection) or to stop the infinite loop in
#   arbitrary I/Q mode.
#==============================================================================

# Save the initial directory to return to later
home_dir=$(pwd)

#==============================================================================
# Navigate to the appropriate FPGA directory
if test -d "/sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr"; then
  cd /sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr
else
  cd /sys/devices/soc0/fpga-axi\@0/fpga-axi\@0\:sdr
fi

#==============================================================================
# Reset all settings for SRAM to default values
echo 0 > tx_intf_iq_sram_ctl
echo 0 > tx_arbitrary_iq_sram_en
echo 0 > tx_arbitrary_iq_sram_select

# Toggle the reset to ensure SRAM is cleared
echo 1 > tx_arbitrary_iq_sram_reset
echo 0 > tx_arbitrary_iq_sram_reset

# Set and clear `sram_select` as needed for proper reset
echo 1 > tx_arbitrary_iq_sram_select
echo 1 > tx_arbitrary_iq_sram_reset
echo 0 > tx_arbitrary_iq_sram_reset
echo 0 > tx_arbitrary_iq_sram_select

# Disable infinite loop and reset counters
echo 0 > tx_arbitrary_iq_sram_inf_loop_en
echo 0 > tx_arbitrary_iq_sram_n_tx_cnt
echo 0 > tx_arbitrary_iq_sram_repeat_spacing_ms

#==============================================================================
# Reset FIFO settings to default values
echo 0 > tx_intf_iq_ctl

# Return to the original directory
cd "$home_dir"

echo "I/Q settings reset completed."
