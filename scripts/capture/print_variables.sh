#!/bin/bash

# Script for configuring openwifi for capturing CSI or I/Q data with different loopback setups.
# A loopback just means we are not running in AP mode or anything similar, we just loop on our own data.
#
# Note the difference between configuring rx_intf, tx_intf, rx, tx, and xpu (hardware) versus side_ch which just samples
# You can configure side_ch to collect IQ data from openwifi_tx while the rx_intf block reads the real ADC data, so they are different!

board_name=${1:-zed_fmcs2}
# data_type: (csi = 0 | rssi_rx_iq0 = 1 | rx_iq0_iq1 = 2 | tx_rx_iq0 = 3)
data_type=${2:-0}
# loop_type: (int = 0 | cabled = 1 | air = 2)
loop_type=${3:-2}
tx_ant=${4:-0}
rx_ant=${5:-0}
cdd_en=${6:-0}
tx_ant_dual_en=${7:-0}
spi_en=${8:-0}
ch_smooth_en=${9:-0}
fft_window_shift=${10:-0}
num_eq=${11:-8}
iq_len=${12:-4095}
interrupt_init=${13:-0}
pre_trigger_len=${14:-2}
header_len=${15:-2}
trigger_src=${16:-3}

# Gains:
rf_atten_tx0=${17:-0}
rf_atten_tx1=${18:-0}
rf_gain_rx=${19:-32}
gain_tx=${20:-250}
gain_rx=${21:-4}

set -x

cd /root/openwifi

#------------------------------------------------------------------------------
# Helper functions for AD9361 (main code is further down)
#------------------------------------------------------------------------------

function print_variables() {
  echo "calib_mode"
  cat calib_mode

  echo "calib_mode_available"
  cat calib_mode_available

  echo "dcxo_tune_coarse"
  cat dcxo_tune_coarse

  echo "dcxo_tune_fine"
  cat dcxo_tune_fine

  echo "dev"
  cat dev

  echo "ensm_mode"
  cat ensm_mode

  echo "ensm_mode_available"
  cat ensm_mode_available

  echo "filter_fir_config"
  cat filter_fir_config

  echo "in_out_voltage_filter_fir_en"
  cat in_out_voltage_filter_fir_en

  echo "in_temp0_input"
  cat in_temp0_input

  echo "in_voltage0_gain_control_mode"
  cat in_voltage0_gain_control_mode

  echo "in_voltage0_hardwaregain"
  cat in_voltage0_hardwaregain

  echo "in_voltage0_rf_port_select"
  cat in_voltage0_rf_port_select

  echo "in_voltage0_rssi"
  cat in_voltage0_rssi

  echo "in_voltage1_gain_control_mode"
  cat in_voltage1_gain_control_mode

  echo "in_voltage1_hardwaregain"
  cat in_voltage1_hardwaregain

  echo "in_voltage1_rf_port_select"
  cat in_voltage1_rf_port_select

  echo "in_voltage1_rssi"
  cat in_voltage1_rssi

  echo "in_voltage2_offset"
  cat in_voltage2_offset

  echo "in_voltage2_raw"
  cat in_voltage2_raw

  echo "in_voltage2_scale"
  cat in_voltage2_scale

  echo "in_voltage_bb_dc_offset_tracking_en"
  cat in_voltage_bb_dc_offset_tracking_en

  echo "in_voltage_filter_fir_en"
  cat in_voltage_filter_fir_en

  echo "in_voltage_gain_control_mode_available"
  cat in_voltage_gain_control_mode_available

  echo "in_voltage_quadrature_tracking_en"
  cat in_voltage_quadrature_tracking_en

  echo "in_voltage_rf_bandwidth"
  cat in_voltage_rf_bandwidth

  echo "in_voltage_rf_dc_offset_tracking_en"
  cat in_voltage_rf_dc_offset_tracking_en

  echo "in_voltage_rf_port_select_available"
  cat in_voltage_rf_port_select_available

  echo "in_voltage_sampling_frequency"
  cat in_voltage_sampling_frequency

  echo "name"
  cat name

  echo "out_altvoltage0_RX_LO_fastlock_load"
  cat out_altvoltage0_RX_LO_fastlock_load

  echo "out_altvoltage0_RX_LO_fastlock_save"
  cat out_altvoltage0_RX_LO_fastlock_save

  echo "out_altvoltage0_RX_LO_fastlock_store"
  cat out_altvoltage0_RX_LO_fastlock_store

  echo "out_altvoltage0_RX_LO_frequency"
  cat out_altvoltage0_RX_LO_frequency

  echo "out_altvoltage1_TX_LO_fastlock_load"
  cat out_altvoltage1_TX_LO_fastlock_load

  echo "out_altvoltage1_TX_LO_fastlock_save"
  cat out_altvoltage1_TX_LO_fastlock_save

  echo "out_altvoltage1_TX_LO_fastlock_store"
  cat out_altvoltage1_TX_LO_fastlock_store

  echo "out_altvoltage1_TX_LO_frequency"
  cat out_altvoltage1_TX_LO_frequency

  echo "out_voltage0_hardwaregain"
  cat out_voltage0_hardwaregain

  echo "out_voltage0_rf_port_select"
  cat out_voltage0_rf_port_select

  echo "out_voltage0_rssi"
  cat out_voltage0_rssi

  echo "out_voltage1_hardwaregain"
  cat out_voltage1_hardwaregain

  echo "out_voltage1_rf_port_select"
  cat out_voltage1_rf_port_select

  echo "out_voltage1_rssi"
  cat out_voltage1_rssi

  echo "out_voltage2_raw"
  cat out_voltage2_raw

  echo "out_voltage2_scale"
  cat out_voltage2_scale

  echo "out_voltage3_raw"
  cat out_voltage3_raw

  echo "out_voltage3_scale"
  cat out_voltage3_scale

  echo "out_voltage_filter_fir_en"
  cat out_voltage_filter_fir_en

  echo "out_voltage_rf_bandwidth"
  cat out_voltage_rf_bandwidth

  echo "out_voltage_rf_port_select_available"
  cat out_voltage_rf_port_select_available

  echo "out_voltage_sampling_frequency"
  cat out_voltage_sampling_frequency

  echo "power"
  cat power

  echo "rx_path_rates"
  cat rx_path_rates

  echo "trx_rate_governor"
  cat trx_rate_governor

  echo "trx_rate_governor_available"
  cat trx_rate_governor_available

  echo "tx_path_rates"
  cat tx_path_rates

  echo "uevent"
  cat uevent
}


#------------------------------------------------------------------------------
# Disable various things
#------------------------------------------------------------------------------

# Disable the cancellation (if it was used)
./sdrctl dev sdr0 set reg tx_intf 3 0

#------------------------------------------------------------------------------
# Configure loop type (gains and how data is routed)
#------------------------------------------------------------------------------

# Loop types:
# - loop_type == 0: internal loopback. Configure rx_intf to get data from tx_intf.
# - loop_type == 1 or 2: cabled or air loopback.
#     - Configure rx_intf to get data from ADC.
#     - Configure antenna pair to use. Note that if you read from 2 RX antenna, the antenna setting
#       just controls what is iq0 and iq1. The selected antenna is iq0.

if [[ $loop_type == 0 ]]; then
  echo 'Configuring board for internal loopback'

  # Ensure rx_intf gets data from tx_intf
  ./sdrctl dev sdr0 set reg rx_intf 3 256

elif [[ $loop_type == 1 || $loop_type == 2 ]]; then
  echo 'Configuring board for external loopback'

  # Configure antenna pair. Note we use drv_tx and drv_rx to set the antenna pair and not rx_intf and tx_intf
  ./sdrctl dev sdr0 set reg drv_tx 4 $tx_ant
  ./sdrctl dev sdr0 set reg drv_rx 4 $rx_ant

  # Set the CDD flag to enable the second antenna with a 50 ns delay (write to this after writing by drv_tx as otherwise overwritten)
  if [[ $cdd_en == 1 ]]; then
    ./sdrctl dev sdr0 set reg tx_intf 16 $((16 + $tx_ant))
  fi

  # Ensure rx_intf gets data from ADC
  ./sdrctl dev sdr0 set reg rx_intf 3 0

  # Disable SPI control so TX LO is always on
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

#------------------------------------------------------------------------------
# Configure common settings for loopbacks
#------------------------------------------------------------------------------

# REVISIT: I guess the CCA, auto ach and FFT window are only needed for CSI, not sure about unmute baseband part

# Turn off CCA by setting a very high threshold so channel is always seen as idle
./sdrctl dev sdr0 set reg xpu 8 1000

# Unmute the baseband self-receiving to receive openwifi own TX signal/packet
./sdrctl dev sdr0 set reg xpu 1 1

# Disable auto ack tx/reply in FPGA
./sdrctl dev sdr0 set reg xpu 11 16

# Set the FFT window
./sdrctl dev sdr0 set reg rx 5 $((768 + $fft_window_shift))

#------------------------------------------------------------------------------
# Capture CSI (monitor mode)
#------------------------------------------------------------------------------
if [[ $data_type == 0 ]]; then
  echo 'Configuring board for collecting CSI'

  # Load and configure side_ch. The default hardware and kernel drivers have a header_len of 2.
  if [[ $header_len == 2 ]]; then
    insmod side_ch.ko num_eq_init=$num_eq
  else
    insmod side_ch.ko num_eq_init=$num_eq header_len_init=$header_len
  fi

  # (Turn on addr2 source address only match)
  ./side_ch_ctl wh1h4001

  # Specify addr2 (source address) matching target: Get CSI from XX:XX:44:33:22:02
  # For packet injection we use the following 0x44332202
  ./side_ch_ctl wh7h44332202

  # Enable CSI capture
  ./side_ch_ctl wh3h0

  if [[ $ch_smooth_en == 0 ]]; then
    echo 'Disable channel smoothing'
    ./sdrctl dev sdr0 set reg rx 1 16
  else
    echo 'Force channel smoothing to always happen'
    ./sdrctl dev sdr0 set reg rx 1 1
  fi
fi

#------------------------------------------------------------------------------
# Capture IQ
#------------------------------------------------------------------------------
# REVISIT: Change this a bit depending on the loopback type. Now we set side_ch to collect only from ADC. We might want to quickly read from tx_intf instead.
# to be able to save the I/Q samples
#
# You write to a hardware register as
# ./side_ch_ctl wh5d33
#
# You can read as
# ./side_ch_ctl rh5
#
#
if [[ $data_type > 0 ]]; then

  # Load and configure side_ch
  if [[ $interrupt_init == 1 ]]; then
    insmod side_ch.ko iq_len_init=$iq_len interrupt_init=$interrupt_init
  else
    insmod side_ch.ko iq_len_init=$iq_len
  fi

  # Note that this setup reuires the customized side_ch_control.v hardware, see the Verilog file.
  # - iq_capture(slv_reg3[0]): 0 = disable, 1 = enable I/Q capture
  # - iq_capture_cfg(slv_reg3[5:4]): 0 = RSSI, AGC, I/Q. 1 = I/Q from both RX antennas, 2 = I/Q from TX and RX antenna
  if [[ $data_type == 1 ]]; then
    echo 'Configuring board for collecting RSSI, ACG and I/Q'
    ./side_ch_ctl wh3h1
  elif [[ $data_type == 2 ]]; then
    echo 'Configuring board for collecting I/Q from both RX antennas'
    ./side_ch_ctl wh3h11
  elif [[ $data_type == 3 ]]; then
    echo 'Configuring board for collecting I/Q for TX and RX at the same time'
    ./side_ch_ctl wh3h21
  fi

  if [[ $loop_type == 0 ]]; then
    # Ensure tx_intf_iq0 data is collected by side_ch and use trigger signal for trigger
    ./side_ch_ctl wh5h4
  else
    # Ensure ADC data is collected by side_ch and use trigger signal for trigger
    ./side_ch_ctl wh5h0
  fi

  # Set trigger condition to phy_tx_started signal from openofdm tx core
  ./side_ch_ctl wh8d$trigger_src

  # Set the pre_trigger_len to 0 to capture most of the data
  ./side_ch_ctl wh11d$pre_trigger_len

  # Set the iq_len_target to 4095 for Zedboard or 8187 for larger FPGA
  ./side_ch_ctl wh12d$iq_len
fi

echo 'Board has been configured successfully!'

#------------------------------------------------------------------------------
# Gains
#------------------------------------------------------------------------------
if [[ $loop_type == 0 ]]; then
  echo 'Configuring board for internal loopback'

  ./sdrctl dev sdr0 set reg tx_intf 13 $gain_tx
  ./sdrctl dev sdr0 set reg rx_intf 11 $gain_rx

elif [[ $loop_type == 1 || $loop_type == 2 ]]; then
  echo 'Configuring board for external loopback'

  ./sdrctl dev sdr0 set reg tx_intf 13 $gain_tx
  ./sdrctl dev sdr0 set reg rx_intf 11 $gain_rx

  # For boards using AD9361 we need to set the RX gain manually
  if [[ "$board_name" == 'zed_fmcs2' ]]; then

    # The following replaces calling ./set_rx_gain_manual.sh $rf_gain_rx
    # We cd to aplace where we can control the gains
    home_dir=$(pwd)

    if test -f "/sys/bus/iio/devices/iio:device0/in_voltage_rf_bandwidth"; then
      cd /sys/bus/iio/devices/iio:device0/
    else if test -f "/sys/bus/iio/devices/iio:device1/in_voltage_rf_bandwidth"; then
      cd /sys/bus/iio/devices/iio:device1/
      else if test -f "/sys/bus/iio/devices/iio:device2/in_voltage_rf_bandwidth"; then
        cd /sys/bus/iio/devices/iio:device2/
        else if test -f "/sys/bus/iio/devices/iio:device3/in_voltage_rf_bandwidth"; then
          cd /sys/bus/iio/devices/iio:device3/
          else if test -f "/sys/bus/iio/devices/iio:device4/in_voltage_rf_bandwidth"; then
            cd /sys/bus/iio/devices/iio:device4/
            else
              echo "Can not find in_voltage_rf_bandwidth!"
              echo "Check log to make sure ad9361 driver is loaded!"
              exit 1
            fi
          fi
        fi
      fi
    fi

    # Set the RX gain
    # See <https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9371>
    # Note that writing to the antenna that's not on is not allowed unless put in manual mode
    # Put both to 0 and then set to the desired value based on seting
    # REVISIT: It says not permitted wo write to in_voltage1
    # echo 1 > in_voltage0_hardwaregain
    # echo 1 > in_voltage1_hardwaregain


    if [[ $rx_ant == 0 || $data_type == 2 ]]; then
      echo manual > in_voltage0_gain_control_mode
      cat in_voltage0_gain_control_mode

      if [[ $rf_gain_rx -gt 0 ]]; then
        echo $rf_gain_rx > in_voltage0_hardwaregain
      fi
    fi

    if [[ $rx_ant == 1 || $data_type == 2 ]]; then
      echo manual > in_voltage1_gain_control_mode
      cat in_voltage1_gain_control_mode

      if [[ $rf_gain_rx -gt 0 ]]; then
        echo $rf_gain_rx > in_voltage1_hardwaregain
      fi
    fi

    # New values of RX gains (actual gain!)
    cat in_voltage0_hardwaregain
    cat in_voltage1_hardwaregain

    # Set the TX attenuation (range is from 0 to -89.75 dB)
    # Note that what happens based on `./sdrctl dev sdr0 set reg rf 0 $rf_atten_tx` is that the active TX antenna
    # is set to $rf_atten_tx while the other one is set to the lowst possible gain (-89.75 dB)
    # REVISIT: What does this mean for using the second antenna with cyclic?
    # The TX attenuation/gain can be individually controlled for TX1 and TX2. The range is from 0 to -89.75 dB in 0.25dB steps. The nomenclature used here is gain instead of attenuation, so all values are expressed negative.
    # We use the AD9361
    # https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9361
    # https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9371
    # https://www.gnuradio.org/grcon/grcon19/presentations/gr-iio_Nuances_Hidden_Features_and_New_Stuff/Travis%20Collins%20-%20gr_iio.pdf
    # For inspiration on settings https://github.com/analogdevicesinc/iio-oscilloscope/blob/master/profiles/LTE5.ini
    # REVISIT: Maybe I just have to do cat like shown here! Because it seems the driver `ad9361_set_tx_atten()` function can only do 1

    # The TX attenuation/gain can be individually controlled for TX1 and TX2. The range is from 0 to -89.75 dB in 0.25dB steps.
    # The nomenclature used here is gain instead of attenuation, so all values are expressed negative.
    # REVISIT: Give values here
    # See <https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9361>
    # Down here, it is in dB (negative), so we need to convert from dB to attenuation
    # THen, the we just need to somehow also allow for controlling this one.
    if [[ $cdd_en == 1 || $tx_ant_dual_en == 1 ]]; then
    # REVISIT: Make this work, because if this for one of the poirts is not 0, something does not work
      echo $rf_atten_tx0 > out_voltage0_hardwaregain
      echo $rf_atten_tx1 > out_voltage1_hardwaregain
      # echo -5 > out_voltage0_hardwaregain
      # echo -5 > out_voltage1_hardwaregain
    else
      $home_dir/sdrctl dev sdr0 set reg rf 0 $rf_atten_tx0
    fi

    echo "tx0 gain"
    cat out_voltage0_hardwaregain
    echo "tx1 gain"
    cat out_voltage1_hardwaregain


    # Print verything
    # set +x
    # print_variables
    # set -x


    cd $home_dir
  fi

else
  echo "Invalid loop type $loop_type"
fi
