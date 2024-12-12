# Example Experiments

## Setup

1. **Login to the host computer and navigate to the openwifi directory:**
```bash
ssh root@192.168.10.122
cd openwifi
```

2. **Initialize and set up the openwifi board:**
```bash
make init && make setup
```
This command prints details verbosely, allowing you to verify the setup.

3. **Check the system:**
In a second terminal window, run on the openwifi board:
```bash
./side_ch_ctl g0
```
Immediately after booting, run the above command, then close it. You should see output similar to:
```bash
Statistics (end):
  side info count 49
  side info dma symbol count 200655
  udp count 49
  udp dma symbol count 200655
  file count 0
  file dma symbol count 0
```
If these counts are `0`, power cycle the board and try again. If they are not `0`, you can proceed.

## Transmitting Data

To transmit data using the SRAM on the openwifi board, ensure another terminal is running `./side_ch_ctl g0`:
```bash
cd openwifi
./iqa_reset.sh
./iqa_sram_data_update.sh wlanFrameFull_3920_15p5.bin 0
./iqa_sram_data_send.sh 1
```

This starts data transmission from the SRAM. To measure how many transmissions occur over 10 seconds:
```bash
./iqa_sram_data_send.sh 0 0.0 10
```
- `0` (first argument): Ignore the number of frames.
- `0.0` (second argument): Delay between frames.
- `10` (third argument): Duration in seconds.

Close `./side_ch_ctl g0` to see the total number of transmissions. For example, you might observe `1206` transmissions in 10 seconds (~120.6 per second). Since you have access to all I/Q samples, this corresponds to about `6000` packets per second if considering a single HT-LTF (~50 OFDM symbols * 120 frames per second).

Advantages of using SRAM:
- The SRAM does not drain; no need for the CPU to continually reinsert frames.
- If transmitting the same data repeatedly, using SRAM is equivalent to the original packet injection program without added overhead.

You can also run certain commands from Python. For example, to set the RX RF gain to 50 dB on antenna 0:
```bash
python board_cmd_exec.py --cmd=set_rx_rf_gain --args="50 0"
```
When choosing gain settings, avoid pushing it to the point of clipping. A slightly lower gain that ensures no clipping will still yield good results, as it can be averaged over many OFDM symbols.

## Capturing Data

On your computer, you can capture transmitted data using a provided script. This script creates a folder structure for your experiments.

Use the following command structure:
```bash
./collect_results.sh <exp_name> <label> <exp_descr> <room> <sampling_time>
```

For example:
```bash
exp_name="respiration_test"
exp_descr="Test the respiration rate"
room="lab"
./collect_results.sh "$exp_name" "respiration" "$exp_descr" "$room" 10
```

This runs the capture for 10 seconds and stores the results in a structured directory. The data collection code waits until the first packet is received before starting the count, ensuring proper data capture.

Note: For data capture to work, the openwifi board must be running and transmitting data (via SRAM, packet injection, or as a normal Wi-Fi router). Also, `./side_ch_ctl g0` must be running in parallel.

## Debugging

On the board, monitor kernel messages:
```bash
sudo dmesg -wH
```
This shows live kernel messages, including frequency changes from the SDR hardware.

You can also view settings under

```bash
cd /sys/bus/iio/devices/iio:device2
```

Then call `cat` on the desired file. For example, to view the current RF gain setting on antenna 0:
```bash
root@analog:/sys/bus/iio/devices/iio:device2# cat in_voltage0_hardwaregain
50.000000 dB
```
