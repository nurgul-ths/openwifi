#!/bin/bash

# Script for configuring openwifi for capturing CSI capture
# See <https://github.com/open-sdr/openwifi/blob/master/doc/app_notes/csi.md>

# Simplified inputs
system_mode=${1:-"monostatic"}
data_type=${2:-"tx_rx_iq0"}
data_type_jmb=${3:-"iq"}
ch_smooth_en=${4:-0}
fc_match=${5:-0}
addr1_match=${6:-0}
addr2_match=${7:-0}

cd /root/openwifi
set -x

#------------------------------------------------------------------------------
# Capture CSI (monitor mode)
#------------------------------------------------------------------------------

# If we capture CSI or if we are in data_type_jmb mode with CSI, we set CSI.
# Note that the CSI enable will later be overwritten for multi-static mode
if [[ "$data_type" == 'csi' || ( "$system_mode" == 'jmb' && "$data_type_jmb" == 'csi' ) ]]; then
  echo 'Configuring board for collecting CSI'

  fc_match_en=0
  addr1_match_en=0
  addr2_match_en=0

  # FC matching
  # REVISIT: Add support for specific FC, not just
  if [[ "$fc_match" != 0 ]]; then
    echo 'Setting fc_match'
    fc_match_en=1
  fi

  # Target address matching (only match to packets that target the device that matches the address)
  # Note that for an address 56:5b:01:ec:e2:8f we only need to match to 01:ec:e2:8f part
  if [[ "$addr1_match" != 0 ]]; then
    echo 'Setting addr1_match'
    ./side_ch_ctl wh6h${addr1_match}
    addr1_match_en=1
  fi

  # Source address matching
  if [[ "$addr2_match" != 0 ]]; then
    echo 'Setting addr2_match'
    ./side_ch_ctl wh7h${addr2_match}
    addr2_match_en=1
  fi

  # A 1 at the end turns on conditional capture, if 0, it's unconditional.
  # Note that the bit0=1 is also done by default in the side_ch kernel driver
  side_ch_slv_reg1=$((addr2_match_en << 14 | addr1_match_en << 13 | fc_match_en << 12 | 1))
  ./side_ch_ctl wh1d$side_ch_slv_reg1

  # Enable CSI capture by disabling I/Q capture (only when not in joint mode as in joint mode we have to capture both)
  if [[ "$system_mode" != 'jmb' ]]; then
    ./side_ch_ctl wh3h0
  fi

  # Channel smoothing
  if [[ $ch_smooth_en == 0 ]]; then
    echo 'Disable channel smoothing'
    ./sdrctl dev sdr0 set reg rx 1 16
  else
    echo 'Force channel smoothing to always happen'
    ./sdrctl dev sdr0 set reg rx 1 1
  fi
fi

set +x
