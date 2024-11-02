#!/bin/bash

# This script is used to send a single transmission of a specific IQ data file to a software-defined radio (SDR).
# The script checks for the correct directory path to the SDR and sends the transmission.
# This is the original script from the openwifi project.

home_dir=$(pwd)

set -x
if test -d "/sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr"; then
  cd /sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr
else
  cd /sys/devices/soc0/fpga-axi\@0/fpga-axi\@0\:sdr
fi

cat ~/openwifi/arbitrary_iq_gen/iq_single_carrier_1000000Hz_512.bin > tx_intf_iq_data
cat tx_intf_iq_data

cd $home_dir
