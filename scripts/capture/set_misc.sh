#!/bin/bash

# Miscellaneous settings for capture

fft_window_shift=${1:-0}

cd /root/openwifi
set -x

#------------------------------------------------------------------------------
# Disable various things
#------------------------------------------------------------------------------

# Disable the cancellation (if it was used)
./sdrctl dev sdr0 set reg tx_intf 3 0

# Disable any gain scaling (also disables)
./sdrctl dev sdr0 set reg tx_intf 13 0

#------------------------------------------------------------------------------
# Set various things
#------------------------------------------------------------------------------

# Set the FFT window
./sdrctl dev sdr0 set reg rx 5 $((768 + $fft_window_shift))

set +x
