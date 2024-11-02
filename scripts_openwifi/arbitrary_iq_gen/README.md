# Arbitrary IQ Generator

These scripts are designed for controlling data delivery to hardware, specifically within a software-defined radio (SDR) environment using OpenWiFi. They are compatible with the SDR setup found at <https://github.com/open-sdr/openwifi/tree/master/user_space/arbitrary_iq_gen>.

Data is generated using code from the [`data_gen`](data_gen) directory, which produces IQ data files that can be loaded and transmitted by these scripts.

## Overview of Script Functionality

### Common Aspects

1. **Directory Navigation**:
   - All scripts operate in a specific directory associated with the SDR hardware. The scripts automatically detect and navigate to one of two possible paths on the system:
     - `/sys/devices/platform/fpga-axi@0/fpga-axi@0:sdr`
     - `/sys/devices/soc0/fpga-axi@0/fpga-axi@0:sdr`
   - After completing their operations, the scripts return to the directory from which they were initially called.

2. **IQ Data Source**:
   - IQ data files should be placed in the `~/openwifi/arbitrary_iq_gen` directory on the OpenWiFi board. This directory acts as the default source of data files for the scripts.
   - Once data is written to the hardware using a command like:
     ```bash
     cat /root/openwifi/arbitrary_iq_gen/$iq_arbitrary_fname > tx_intf_iq_data
     ```
     it remains in the buffer, so you do not need to reload it unless the data changes.

## Script Usage and Setup

### Preparation Steps

1. **Load IQ Data**:
   - Before using any transmission script, make sure to populate the buffer with data by running:
     ```bash
     ./iqa_sram_data_update.sh [iq_arbitrary_fname] [iq_sram_sel]
     ```
     - `iq_arbitrary_fname`: The IQ data file to load. If omitted, a default file is used.
     - `iq_sram_sel`: Optional parameter to select which SRAM block to write to.

2. **Start Data Transmission**:
   - Depending on your needs, there are multiple scripts to initiate data transmission:
     - **Continuous Transmission**:
       ```bash
       ./iqa_sram_data_send_hw_control.sh 0 0 1
       ```
       This script will continuously transmit data from the buffer until manually stopped or reset.
     - **Finite Frame Transmission**:
       ```bash
       ./iqa_sram_data_send.sh [n_frames] [delay] [duration]
       ```
       - `n_frames`: Number of frames to send. Default is 5.
       - `delay`: Delay in seconds between frames. Default is 0.001.
       - `duration`: Total duration to transmit frames, overriding `n_frames` if set.

     **Example Commands**:
     - Send a single frame:
       ```bash
       ./iqa_sram_data_send.sh 1 0 0
       ```
     - Run in infinite loop until manually stopped:
       ```bash
       ./iqa_sram_data_send_hw_control.sh 0 0 1
       ```

3. **Stop Transmission**:
   - To stop any infinite loop transmission, you can run:
     ```bash
     ./iqa_reset.sh
     ```
     This will reset the I/Q settings, halting any ongoing transmissions.

### Important Notes

- **Transmission Delays**:
  - Adding a delay between frames can help ensure successful data transmission. However, a delay increases total transmission time, so it’s a balance between reliability and speed.

- **Loop Constraints**:
  - Due to the limitations of shell scripting, avoid using `for` loops with high iterations (e.g., `for (( i=0; i<1000; i++ )); do; done;`). Instead, use controlled delays where possible.

This documentation should serve as a quick guide to setting up, running, and managing IQ data transmission in the OpenWiFi SDR setup.
