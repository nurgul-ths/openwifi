#!/bin/bash

#==============================================================================
# This script initiates the transmission of arbitrary I/Q frames using the
# FIFO buffer in the FPGA. It assumes that `iqa_data_update.sh` has already
# been executed to populate the buffer with data.
#
# Usage:
#   ./iqa_data_send.sh [n_frames] [delay]
#
# Arguments:
#   n_frames : Number of frames to send. Default is 5.
#   delay    : Delay between frames in seconds. Default is 0.001 seconds.
#==============================================================================

# Save the initial directory to return to later
home_dir=$(pwd)

#==============================================================================
# Read script arguments or assign default values
n_frames=${1:-5}
delay=${2:-0.001}

# Determine if delay is needed
use_delay=false
if (( $(echo "$delay > 0.0" | bc -l) )); then
  use_delay=true
fi

#==============================================================================
# Navigate to the appropriate FPGA directory
if test -d "/sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr"; then
  cd /sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr
else
  cd /sys/devices/soc0/fpga-axi\@0/fpga-axi\@0\:sdr
fi

#==============================================================================
# Reset SRAM values to ensure the FIFO is ready
echo 0 > tx_arbitrary_iq_sram_en
echo 0 > tx_arbitrary_iq_sram_reset
echo 0 > tx_arbitrary_iq_sram_select
echo 0 > tx_arbitrary_iq_sram_inf_loop_en
echo 0 > tx_arbitrary_iq_sram_n_tx_cnt
echo 0 > tx_arbitrary_iq_sram_repeat_spacing_ms

#==============================================================================
# Main loop to send frames
for (( i=0; i<$n_frames; i++ ))
do
  echo 1 > tx_intf_iq_ctl
  if $use_delay; then
    sleep $delay
  fi
done

#==============================================================================
# Return to the original directory
cd "$home_dir"

echo "Frame transmission completed."
