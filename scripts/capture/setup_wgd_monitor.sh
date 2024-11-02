#!/bin/bash

# Script for configuring openwifi for capturing CSI or I/Q data with different loopback setups.
wifi_ch=${1:-14}

set -x

cd /root/openwifi

#------------------------------------------------------------------------------
# Setup wgd and sdr0
#------------------------------------------------------------------------------
./wgd.sh
./monitor_ch.sh sdr0 $wifi_ch
