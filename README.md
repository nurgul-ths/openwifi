# wcnc2024_monostatic_sensing_openwifi (Under Construction)

## Running the Demo

To run the demo, go to [experiments/demos/starter](experiments/demos/starter) and follow the README instructions. This will guide you through a basic setup and initial data capture using openwifi-based hardware.

Pre-requisites:
- You can download the sd card image from [here](https://drive.google.com/file/d/1uQMX8zfUFNDDfW1cvrgORAVHtUJXXgkP/view?usp=sharing)

You need a python environment with
```bash
conda config --append channels conda-forge
conda create -n openwifi python=3.9
conda activate openwifi
conda install pandas paramiko pyyaml
```


## Post-Processing the Data

After running the demo and collecting raw CSV data, you can process it using scripts in [scripts_data](scripts_data):

1. Generate a searchable database:
```bash
python script_create_database.py
```
2. Convert CSV files to HDF5 for faster access:
```bash
python script_create_hdf5_files.py
```

HDF5 files load more quickly, especially for large datasets, improving your analysis workflow.

## MATLAB Data Processing

To analyze and visualize the data, open [wispr/script_process_dataset_demo.m](wispr/script_process_dataset_demo.m) in MATLAB. Set the path to your dataset and run the script. This estimates the channel impulse response (CIR) and plots the results.

## Future Work

We are preparing a full release of this project, including FPGA RTL code, Linux kernel modifications, C programs, and Python post-processing tools. This takes time to organize and document properly.

For early access or inquiries, please contact andreas.kristensen@epfl.ch.

Thank you for your patience and support.
