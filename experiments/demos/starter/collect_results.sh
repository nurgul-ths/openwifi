#!/bin/bash
set -x

# Description:
# This script is used for collecting data in different experimental setups.

#==============================================================================
# Setup
#==============================================================================

ORIG_DIR=$(pwd)
REPO_DIR=$(git rev-parse --show-toplevel)
YAML_FILE="$ORIG_DIR/config.yaml"
EMAIL="test@outlook.com"

#==============================================================================
# Arguments
#==============================================================================

COMMON_ARGS="--sampling-delay=0 --beep=0"
SAMPLE_ARGS="--save-data=1 --capture-mode=udp"

#==============================================================================
# Main function
#==============================================================================

sample() {
  local exp_name=$1
  local label=$2
  local exp_descr=$3
  local room=$4
  local sampling_time=$5

  python run_exp.py --action=run --yaml-file="$YAML_FILE" $COMMON_ARGS $SAMPLE_ARGS \
    --exp-name="${exp_name}" \
    --label="$label" \
    --exp-descr="$exp_descr" \
    --room="$room" \
    --sampling-time="$sampling_time"
}

#==============================================================================
# Main logic
#==============================================================================

cd "$REPO_DIR"
echo "Experiment running" | mail -s "Experiment running" $EMAIL

if [ $# -lt 4 ]; then
  echo "Usage: $0 <exp_name> <label> <exp_descr> <room> <sampling_time>"
  echo "Example: $0 cnc 'cnc_meeting_room_test1' 'CNC machines moving in meeting room' tcl_meeting_room 60"
  exit 1
fi

sample "$@"

cd "$ORIG_DIR"
set +x
echo "Experiment done" | mail -s "Experiment done" $EMAIL
