# OpenWiFi Experiment Guide

This guide helps you run experiments on an OpenWiFi board using scripts and tools provided in the repository.

## Directory Structure

You will work with two directories on your host computer:

- **Git repository root directory**: Only used for running Python control commands.
- **`experiments/demos/starter` directory**: Contains this README, the `collect_results.sh` script, and the Makefile for board setup.

The Makefile in `experiments/demos/starter` is a symlink to `experiments/shared/Makefile_template.mk`. If the symlink is broken, you can restore it by copying `Makefile_template.mk` from `experiments/shared` to your current directory and renaming it to `Makefile`.

## Terminal Setup

You will need these terminals:

**Host Computer Terminals:**
1. **Host Root Terminal**
  - Used only for Python control commands
  - Must stay in the Git repository root directory

2. **Host Experiment Terminal**
  - Used for board setup (make init/setup) and data collection
  - Must stay in `experiments/demos/starter` directory

**OpenWiFi Board Terminals:**
1. **Board Main Terminal**
  - Primary terminal for running commands on the board
  - Stays in the `openwifi` directory on the board

2. **Board Monitor Terminal**
  - Dedicated to running `./side_ch_ctl g0`
  - Stays in the `openwifi` directory on the board

## Initial Setup

**Important**: Ensure password-less SSH login is configured. You must be able to:
```bash
ssh root@192.168.10.122
```
without being prompted for a password. This is required for the automated scripts.

1. **Connect to the OpenWiFi Board**
  In both the **Board Main Terminal** and **Board Monitor Terminal**:
  ```bash
  ssh root@192.168.10.122
  cd openwifi
  ```

2. **Initialize the Board (Host Experiment Terminal)**
  Before running the following command, verify that you are in the `experiments/demos/starter` directory on your host computer:
  ```bash
  cd experiments/demos/starter
  make init && make setup
  ```
  This command prints details verbosely, allowing you to verify the setup.

3. **Check the System (Board Monitor Terminal)**
  Immediately after booting, run:
  ```bash
  ./side_ch_ctl g0
  ```

  You should see statistics like:
  ```
  Statistics (end):
    side info count 49
    side info dma symbol count 200655
    udp count 49
    udp dma symbol count 200655
    file count 0
    file dma symbol count 0
  ```

  If the `side info count` is `0`, power cycle the board by turning it off and on again, then re-run the command. The `udp count` should match the `side info count`, indicating successful sample transmission over UDP. Note that as we have a file system, please run `sudo shutdown -h now` to power off the board and then wait a few seconds before before turning off the power and turning it back on.

## Data Transmission

Ensure `./side_ch_ctl g0` is running in your **Board Monitor Terminal**.

Then, in your **Board Main Terminal**:
```bash
./iqa_reset.sh
./iqa_sram_data_update.sh wlanFrameFull_3920_15p5.bin 0
./iqa_sram_data_send.sh 1
```

To measure transmission rate over 10 seconds:
```bash
./iqa_sram_data_send.sh 0 0.0 10
```
Where:
- First argument `0`: Ignore the number of frames
- Second argument `0.0`: No delay between frames
- Third argument `10`: Duration in seconds

After 10 seconds, close `./side_ch_ctl g0` in the **Board Monitor Terminal** to see the total transmissions. For example, you might observe `1206` transmissions in 10 seconds (~120.6 per second).

**Explaining the Packets per Second Calculation**:
If considering a single High-Throughput Long Training Field (HT-LTF), a standard system may only extract 1 OFDM symbol per frame. However, with full access to the I/Q samples on this system, you can effectively extract ~50 OFDM symbols per transmitted frame (because we can read out more data than just the HT-LTF, allowing for better SNR estimation). Therefore, one frame here provides the equivalent OFDM symbol insights of 50 frames in a standard HT-LTF-only system. Hence, ~120 frames per second here equates to the equivalent data of ~6000 frames per second in a system limited to HT-LTF alone (50 symbols * 120 frames = 6000 symbol-equivalents).

**Advantages of Using SRAM over FIFO**:
- Unlike FIFO, which requires continuous CPU intervention to insert frames, SRAM maintains the data without draining.
- If transmitting the same data repeatedly, using SRAM is equivalent to the original packet injection program without added overhead.

## Remote Control from Host Computer

From your **Host Root Terminal** (in the Git repository root directory), you can adjust board parameters. For example, to set the RX RF gain to 30 dB on antenna 0:
```bash
python board_cmd_exec.py --cmd=set_rx_rf_gain --args="30 0"
```

When choosing gain settings, avoid pushing it to the point of clipping. A slightly lower gain that ensures no clipping will still yield good results, as it can be averaged over many OFDM symbols.

## Data Collection

In your **Host Experiment Terminal** (in `experiments/demos/starter`):
```bash
exp_name="respiration_test"
exp_descr="Test the respiration rate"
room="lab"
./collect_results.sh "$exp_name" "respiration" "$exp_descr" "$room" 10
```

This captures data for 10 seconds and stores the results in a structured directory. The code waits for the first packet before starting the timer, ensuring accurate timing.

**Requirements**:
- `./side_ch_ctl g0` must be running in the **Board Monitor Terminal**
- The board can begin transmitting data before or after running `collect_results.sh`, as the script waits for the first packet to arrive.

## Debugging

### Kernel Message Monitoring
In your **Board Main Terminal**:
```bash
sudo dmesg -wH
```
This shows live kernel messages, including frequency changes from the SDR hardware.

### Hardware Settings Inspection
In your **Board Main Terminal**:
```bash
cd /sys/bus/iio/devices/iio:device2
cat in_voltage0_hardwaregain
```

Example output:
```bash
30.000000 dB
```

## Notes
- Keep gain levels below clipping thresholds for cleaner signals.
- SRAM-based transmission is efficient for repetitive frames.
- Always keep terminals in their designated directories to avoid confusion.
- If the Makefile symlink breaks, copy `Makefile_template.mk` from `experiments/shared` and rename it to `Makefile`.
- Power cycle the board if counts are `0`.
