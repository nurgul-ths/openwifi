#!/bin/bash

# Script for configuring openwifi for capturing CSI or I/Q data with different loopback setups.
wifi_ch=${1:-13}

set -x

cd /root/openwifi

#------------------------------------------------------------------------------
# Setup wgd and sdr0
#------------------------------------------------------------------------------
./wgd.sh
./fosdem.sh
