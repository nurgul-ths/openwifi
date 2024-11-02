#!/bin/bash

#==============================================================================
# This script sends arbitrary I/Q frames using the SRAM on the board.
# Prerequisite: Run `iqa_sram_data_update.sh` to fill the buffer before using this script.
#
# Usage:
#   ./iqa_sram_data_send_hw_control.sh [n_frames] [repeat_spacing_ms] [inf_loop_enable]
#
# Arguments:
#   n_frames          : Number of frames to send. Default is 5.
#   repeat_spacing_ms : Delay between frames in 2^x ms. Default is 8 (256 ms).
#   inf_loop_enable   : Enable infinite loop (1 for yes, 0 for no). Default is 0.
#
# Examples:
#   - To send frames in an infinite loop:
#       ./iqa_reset.sh
#       ./iqa_sram_data_update.sh wlanFrameFull_3920_15p5.bin 0
#       ./iqa_sram_data_send_hw_control.sh 0 0 1
#     (Stop with `./iqa_reset.sh`)
#
#   - To send a single frame:
#       ./iqa_sram_data_send_hw_control.sh 1 0 0
#==============================================================================

home_dir=$(pwd)

# Read script arguments or use default values
n_frames=${1:-5}
repeat_spacing_ms=${2:-8}
inf_loop_enable=${3:-0}

#==============================================================================
# Navigate to the FPGA directory
if test -d "/sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr"; then
  cd /sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr
else
  cd /sys/devices/soc0/fpga-axi\@0/fpga-axi\@0\:sdr
fi

#==============================================================================
# Configure SRAM settings and start transmission
echo $n_frames > tx_arbitrary_iq_sram_n_tx_cnt
echo $inf_loop_enable > tx_arbitrary_iq_sram_inf_loop_en
echo $repeat_spacing_ms > tx_arbitrary_iq_sram_repeat_spacing_ms
echo 1 > tx_intf_iq_sram_ctl

# Return to the original directory
cd "$home_dir"
