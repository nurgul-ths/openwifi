#!/bin/bash

# Script for configuring the gains on the openwifi board

board_name=${1:-"zed_fmcs2"}
system_mode=${2:-"monostatic"}
data_type=${3:-"tx_rx_iq0"}
loop_type=${4:-"air"}
rx_ant=${5:-0}
cdd_en=${6:-0}
tx_ant_dual_en=${7:-0}
rf_tx0_atten=${8:-0}
rf_tx1_atten=${9:-0}
rf_rx0_gain=${10:-0}
rf_rx1_gain=${11:-0}
gain_tx=${12:-250}
gain_rx=${13:-4}

cd /root/openwifi
set -x

#------------------------------------------------------------------------------
# Digital gains
#------------------------------------------------------------------------------
./sdrctl dev sdr0 set reg tx_intf 13 $gain_tx
./sdrctl dev sdr0 set reg rx_intf 11 $gain_rx
./sdrctl dev sdr0 set reg rf 0 $((-1000*rf_tx0_atten))

#------------------------------------------------------------------------------
# Analog gains
#------------------------------------------------------------------------------

# For the zed board with the FMCOMMS2/3/4/5 we can set
# - TX attenuation (range is from 0 to -89.75 dB in steps of 0.25 dB) individually controlled for TX1 and TX2
#
# Note that what happens based on `./sdrctl dev sdr0 set reg rf 0 $rf_atten_tx` is that the active TX antenna
# is set to $rf_atten_tx while the other one is set to the lowst possible gain (-89.75 dB)
#
# The nomenclature used here is gain instead of attenuation, so all values are expressed negative.
# We use the AD9361
# - <https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9361>
# - <https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9371>
# - <https://www.gnuradio.org/grcon/grcon19/presentations/gr-iio_Nuances_Hidden_Features_and_New_Stuff/Travis%20Collins%20-%20gr_iio.pdf>
#
# For inspiration on settings <https://github.com/analogdevicesinc/iio-oscilloscope/blob/master/profiles/LTE5.ini>
# Down here, it is in dB (negative), since it is attenuation, the gain is negative.

if [[ "$loop_type" == 'int' ]]; then
  echo 'Configuring board for internal loopback'

elif [[ "$loop_type" == 'cabled' || "$loop_type" == 'air' ]]; then
  echo 'Configuring board for external loopback'

  # For boards using AD9361 we need to set the RX gain manually
  if [[ "$board_name" == 'zed_fmcs2' ]]; then

    # The following replaces calling ./set_rx_gain_manual.sh $rf_gain_rx. We cd to a place where we can control the gains
    home_dir=$(pwd)

    for dev in {0..4}; do
      if test -f "/sys/bus/iio/devices/iio:device$dev/in_voltage_rf_bandwidth"; then
        cd "/sys/bus/iio/devices/iio:device$dev/"
        break
      fi
    done

    # Ensure that the frequency does not change
    echo 1 > restrict_freq_mhz
    cat restrict_freq_mhz

    if [ ! -f "in_voltage_rf_bandwidth" ]; then
      echo "Cannot find in_voltage_rf_bandwidth!"
      echo "Check log to make sure ad9361 driver is loaded!"
      exit 1
    fi

    # Set the RX gain (manually) (<https://wiki.analog.com/resources/tools-software/linux-drivers/iio-transceiver/ad9361>)
    # Note that writing to the antenna that's not on is not allowed unless put in manual mode
    if [[ $rx_ant == 0 || "$data_type" == 'rx_iq0_iq1' || "$data_type" == 'iq_all' ]]; then
      echo manual > in_voltage0_gain_control_mode
      cat in_voltage0_gain_control_mode

      if [[ $rf_rx0_gain -ge -3 ]]; then
        echo $rf_rx0_gain > in_voltage0_hardwaregain
      fi
    else
      echo slow_attack > in_voltage0_gain_control_mode
    fi

    if [[ $rx_ant == 1 || "$data_type" == 'rx_iq0_iq1' || "$data_type" == 'iq_all' ]]; then
      echo manual > in_voltage1_gain_control_mode
      cat in_voltage1_gain_control_mode

      if [[ $rf_rx1_gain -ge -3 ]]; then
        echo $rf_rx1_gain > in_voltage1_hardwaregain
      fi
    else
      echo slow_attack > in_voltage1_gain_control_mode
    fi

    # New values of RX gains (actual gain!)
    cat in_voltage0_hardwaregain
    cat in_voltage1_hardwaregain

    # REVIIST: Need tx_ant in this script
    # REVISIT: Check if this works
    if [[ $cdd_en == 1 || $tx_ant_dual_en == 1 ]]; then
      echo $rf_tx0_atten > out_voltage0_hardwaregain
      echo $rf_tx1_atten > out_voltage1_hardwaregain
    else
      # REVISIT: Make this better
      # REVISIT: Now, ahh, above worked fine, as I changed both at the same time, but, I should really just change , fine for cancellation, as I set the tx1 to match
      echo $rf_tx0_atten > out_voltage0_hardwaregain
      # REVISIT: We also have to set this, or openwifi complains
    fi

    echo "tx0 gain"
    cat out_voltage0_hardwaregain
    echo "tx1 gain"
    cat out_voltage1_hardwaregain

    cd $home_dir
  fi

else
  echo "Invalid loop type "$loop_type""
fi

set +x
