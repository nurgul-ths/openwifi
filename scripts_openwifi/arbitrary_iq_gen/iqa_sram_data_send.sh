#!/bin/bash

#==============================================================================
# This script sends arbitrary I/Q frames from the FPGA's SRAM buffer. Ensure
# that the buffer has been populated using `iqa_sram_data_update.sh` before
# running this script.
#
# Usage:
#   ./iqa_sram_data_send.sh [n_frames] [delay] [duration]
#
# Arguments:
#   n_frames : Number of frames to send (default: 5).
#   delay    : Delay between frames in seconds (default: 0.001 sec).
#   duration : Duration in seconds to continue sending frames. Overrides
#              n_frames if set to a value greater than 0 (default: 0).
#==============================================================================

# Save the initial directory to return to later
home_dir=$(pwd)

#==============================================================================
# Read script arguments or assign default values
n_frames=${1:-5}
delay=${2:-0.001}
duration=${3:-0}

#==============================================================================
# Navigate to the appropriate FPGA directory
if test -d "/sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr"; then
  cd /sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr
else
  cd /sys/devices/soc0/fpga-axi\@0/fpga-axi\@0\:sdr
fi

#==============================================================================
# Reset unused SRAM settings
echo 0 > tx_arbitrary_iq_sram_inf_loop_en
echo 0 > tx_arbitrary_iq_sram_n_tx_cnt
echo 0 > tx_arbitrary_iq_sram_repeat_spacing_ms

#==============================================================================
# Determine delay and duration settings
use_delay=false
if (( $(echo "$delay > 0.0" | bc -l) )); then
  use_delay=true
fi

use_duration=false
if (( $(echo "$duration > 0" | bc -l) )); then
  end_time=$(($(date +%s) + duration))
  use_duration=true
fi

#==============================================================================
# Run loop based on duration or frame count
if $use_duration; then
  while [[ $(date +%s) -lt $end_time ]]; do
    echo 1 > tx_intf_iq_sram_ctl
    if $use_delay; then
      sleep $delay
    fi
  done
else
  for (( i=0; i<$n_frames; i++ )); do
    echo 1 > tx_intf_iq_sram_ctl
    if $use_delay; then
      sleep $delay
    fi
  done
fi

#==============================================================================
# Return to the original directory
cd "$home_dir"
