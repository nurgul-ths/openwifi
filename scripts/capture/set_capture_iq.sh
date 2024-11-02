#!/bin/bash

# Script for configuring openwifi for I/Q capture

system_mode=${1:-"monostatic"}
data_type=${2:-"tx_rx_iq0"}
data_type_jmb=${3:-"iq"}
loop_type=${4:-"air"}
trigger_src=${5:-3}
iq_len=${6:-4093}
pre_trigger_len=${7:-0}
tx_jmb_interrupt_init=${8:-0}
tx_jmb_interrupt_src=${9:-0}

cd /root/openwifi
set -x

#------------------------------------------------------------------------------
# Capture IQ
#------------------------------------------------------------------------------
if [[ "$data_type" != "csi" || "$system_mode" == 'jmb' ]]; then

  # Note that this setup requires the customized side_ch_control.v hardware, see the Verilog file.
  # - iq_capture(slv_reg3[0]): 0 = disable, 1 = enable I/Q capture
  # - iq_capture_cfg(slv_reg3[5:4]): 0 = RSSI, AGC, I/Q. 1 = I/Q from both RX antennas, 2 = I/Q from TX and RX antenna
  # Indices are
  # .iq_capture(slv_reg3[0]),
  # .iq_capture_all_antenna(slv_reg3[3]), // #WS: Enables capturing all antenna, RX and TX
  # .iq_capture_cfg(slv_reg3[5:4]), // #WS: In a mode where we only capture a subset of the antenna, this selects what
  # .iq_capture_multistatic_with_csi_enable(slv_reg3[6]), // #WS: Enables capturing the CSI data (bistatic) with the IQ data (monostatic)
  # .iq_capture_multistatic_with_iq_enable(slv_reg3[7]), // #WS: Enables capturing the IQ data (bistatic) with the IQ data (monostatic)
  # .iq_trigger_select(slv_reg8[4:0]), //
  # .iq_trigger_free_run_flag(slv_reg5[0]),
  # .iq_source_select(slv_reg5[2:1]),

  iq_capture=1
  iq_capture_cfg=0
  iq_capture_data_type_jmb_enable=0
  iq_capture_with_csi_capture_enable=0
  iq_capture_all_antenna=0

  if [[ "$data_type" == 'rssi_rx_iq0' ]]; then
    echo 'Configuring board for collecting RSSI, ACG and I/Q'
    iq_capture_cfg=0
  elif [[ "$data_type" == 'rx_iq0_iq1' ]]; then
    echo 'Configuring board for collecting I/Q from both RX antennas'
    iq_capture_cfg=1
  elif [[ "$data_type" == 'tx_rx_iq0' ]]; then
    echo 'Configuring board for collecting I/Q for TX and RX at the same time'
    iq_capture_cfg=2
  elif [[ "$data_type" == 'iq_all' ]]; then
    echo 'Configuring board for collecting I/Q for all antennas'
    iq_capture_all_antenna=1
  fi

  if [[ "$data_type_jmb" == 'iq' ]]; then
    echo 'Configuring board for data_type_jmb capture with bistatic and monostatic I/Q at the same time'
    iq_capture_data_type_jmb_enable=1
  elif [[ "$data_type_jmb" == 'csi' ]]; then
    echo 'Configuring board for data_type_jmb capture with CSI and I/Q at the same time'
    iq_capture_with_csi_capture_enable=1
  fi

  iq_capture_slv_reg3=$((iq_capture_data_type_jmb_enable << 7 | iq_capture_with_csi_capture_enable << 6 | iq_capture_cfg << 4 | iq_capture_all_antenna << 3 | iq_capture))
  ./side_ch_ctl wh3d$iq_capture_slv_reg3

  if [[ "$loop_type" == 'int' ]]; then
    # Ensure tx_intf_iq0 data is collected by side_ch and use trigger signal for trigger
    ./side_ch_ctl wh5h4
  else
    # Ensure ADC data is collected by side_ch and use trigger signal for trigger
    ./side_ch_ctl wh5h0
  fi

  # Set trigger condition signal from openofdm tx core (default one, wh8d3)
  ./side_ch_ctl wh8d$trigger_src

  # Set the pre_trigger_len (setting to 0 would capture most of the data)
  ./side_ch_ctl wh11d$pre_trigger_len

  # Set the iq_len_target to 4095 for Zedboard or 8187 for larger FPGA. Note you need to subtract the header length that's in the hardware
  ./side_ch_ctl wh12d$iq_len

  # Set the tx_jmb_interrupt_init to 1 to enable the interrupt
  # This will allow us to know exactly when a trnasmission happens. This is useful for joint monostatic and bistatic capture
  # The side_ch interrupt is then used to know when data has been received.
  if [[ $tx_jmb_interrupt_init == 1 ]]; then
    tx_intf_slv_reg31=$((1 << 31 | tx_jmb_interrupt_src))
    ./sdrctl dev sdr0 set reg tx_intf 31 $tx_intf_slv_reg31
  fi
fi

echo 'Board has been configured successfully!'

set +x
