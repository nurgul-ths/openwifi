#!/bin/bash

# Script for configuring openwifi for capturing CSI or I/Q data with different loopback setups (how the
# data gets routed for side ch capture and capture on the board).
#
# Note the difference between configuring rx_intf, tx_intf, rx, tx, and xpu (hardware) versus side_ch which just samples
# You can configure side_ch to collect IQ data from openwifi_tx while the rx_intf block reads the real ADC data, so they are different!

board_name=${1:-"zed_fmcs2"}
system_mode=${2:-"monostatic"}
loop_type=${3:-"air"}
tx_ant=${4:-0}
rx_ant=${5:-0}
cdd_en=${6:-0}
spi_en=${7:-0}

cd /root/openwifi
set -x

#------------------------------------------------------------------------------
# Configure common settings for loopbacks
#------------------------------------------------------------------------------

if [[ "$system_mode" == "monostatic" ]]; then
  echo 'Configuring board for monostatic capture'
  # Turn off CCA by setting a very high threshold so channel is always seen as idle and we can always transmit
  ./sdrctl dev sdr0 set reg xpu 8 1000

  # Unmute the baseband self-receiving to receive openwifi own TX signal/packet
  ./sdrctl dev sdr0 set reg xpu 1 1

  # REVISIT: Maybe we do want this for monitor, see <https://github.com/open-sdr/openwifi/issues/59>
  # REVISIT: This is not actually needed for IQ capture, and probably not for CSI capture either.
  # Depends on whether we are in monitor or not, if not in monitor, we need to have this turned ON, not OFF.
  # Disable auto ack tx/reply in FPGA
  ./sdrctl dev sdr0 set reg xpu 11 16
fi

#------------------------------------------------------------------------------
# Configure loop type (gains and how data is routed)
#------------------------------------------------------------------------------

# Loop types:
# - loop_type == "int": internal loopback. Configure rx_intf to get data from tx_intf.
# - loop_type == "cabled or "air":
#   - Configure rx_intf to get data from ADC.
#   - Configure antenna pair to use. Note that if you read from 2 RX antenna, the antenna setting
#     just controls what is iq0 and iq1. The selected antenna is iq0.

if [[ "$loop_type" == 'int' ]]; then
  echo 'Configuring board for internal loopback'

  # Ensure rx_intf gets data from tx_intf
  ./sdrctl dev sdr0 set reg rx_intf 3 256

elif [[ "$loop_type" == 'cabled' || "$loop_type" == 'air' ]]; then
  echo 'Configuring board for external loopback'

  # Configure antenna pair. Note we use drv_tx and drv_rx to set the antenna pair and not rx_intf and tx_intf
  # REVIIST: For some reason, when this is called, I get WARNING ad9361_set_tx_atten ant0 -25 FAIL!
  ./sdrctl dev sdr0 set reg drv_tx 4 $tx_ant
  ./sdrctl dev sdr0 set reg drv_rx 4 $rx_ant

  # Set the CDD flag to enable the second antenna with a 50 ns delay (write to this after writing by drv_tx as otherwise overwritten)
  if [[ $cdd_en == 1 ]]; then
    ./sdrctl dev sdr0 set reg tx_intf 16 $((16 + $tx_ant))
  fi

  # Ensure rx_intf gets data from ADC
  ./sdrctl dev sdr0 set reg rx_intf 3 0

  # Disable SPI control so TX LO is always on ($spi_en = 0) or enable SPI control so TX LO is controlled by SPI ($spi_en = 1)
  if [[ "$board_name" == 'zed_fmcs2' ]]; then
    if [[ $spi_en == 0 ]]; then
      echo 'Disable SPI control'
      ./sdrctl dev sdr0 set reg xpu 13 1
    else
      ./sdrctl dev sdr0 set reg xpu 13 0
    fi
  fi

else
  echo "Invalid loop type $loop_type"
fi

set +x
