#!/bin/bash

# Script for configuring openwifi side_ch for capturing CSI or I/Q data

# Inputs
system_mode=${1:-"monostatic"}
data_type=${2:-"tx_rx_iq0"}
data_type_jmb=${3:-"iq"}
num_eq=${4:-8}
side_ch_interrupt_init=${5:-0}
iq_len=${6:-4093}

# The I/Q header length and CSI header lengths are fixed in hardware
CSI_HEADER_LEN=8
IQ_HEADER_LEN=3

cd /root/openwifi
set -x

#------------------------------------------------------------------------------
# side_ch driver
#------------------------------------------------------------------------------

# REVISIT: Do we want a calculation here for the side_ch length? or assumed to be done somewhere else?

# For joint monostatic and bistatic, just load the driver, we don't need to configure it further as the interrupt mode handles sizes itself
# The interrupt mode is required for joint monostatic and bistatic capture
if lsmod | grep -q "^side_ch "; then
  echo 'side_ch is already loaded'

elif [[ "$system_mode" == 'jmb' ]]; then
  echo 'Configuring board for joint monostatic and bistatic capture'

  insmod_params="iq_len_init=$iq_len"
  insmod_params+=" interrupt_init=$side_ch_interrupt_init"

  insmod side_ch.ko $insmod_params

elif [[ "$data_type" == 'csi' ]]; then
  echo 'Configuring board for collecting CSI'

  # Load and configure side_ch. The default hardware and kernel drivers have a header_len of 2.
  echo 'Loading side_ch for CSI capture'
  insmod_params="num_eq_init=$num_eq"
  insmod_params+=" header_len_init=$CSI_HEADER_LEN"
  [[ $side_ch_interrupt_init == 1 ]] && insmod_params+=" interrupt_init=$side_ch_interrupt_init"

  insmod side_ch.ko $insmod_params

else

  echo 'Loading side_ch for IQ capture'
  insmod_params="iq_len_init=$iq_len"
  [[ $side_ch_interrupt_init == 1 ]] && insmod_params+=" interrupt_init=$side_ch_interrupt_init"

  insmod side_ch.ko $insmod_params
fi

set +x
