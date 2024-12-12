# Experiments scripts

This directory contains the various experiments that we have run. The experiments are organized in subdirectories.

Each directory contains a config.yaml file that sets the base settings for the experiment and then you can use various scripts for related experiments or if the config file is for a dataset these scripts represent experiments in the dataset.

## Datasets

## Experiments

## Best-practices

Best practices:
- Always run the RX and TX gain calibrations a few times (we do first RX, then TX, then RX, then TX)
- Antenna choises do matter!
- Also, put TX and RX at 90 degree angles to each other if possible (gives better cancellation. Then, I guess I could have even more power)
- BP filter may not be necessary, see the h1 error go up with this, but h1 is also a bit all over the place! The board at EPFL seems better?

This directory contains for experiments. Please only use these scripts to run experiments, don't make multiple copies of them or of the main python script, just use these shell scripts in combination with the YAML config files. If you need to make a copy of a script, please copy it to the `scripts` directory and make your changes there.

We use the [shared](shared) folder for shared files, like the Makefile templates.

## Settings

To organize the datasets, you have several options

```python
  # Data save control
  parser.add_argument("--save-data", type=int, default=1, choices=[0,1], help="Save data.")
  parser.add_argument("--save-raw", type=int, default=0, choices=[0,1], help="Save raw data.")
  # Data folders
  parser.add_argument("--exp-dir", type=str.lower, default="data/raw", help="Directory to save data.")
  parser.add_argument("--exp-dataset", type=str.lower, help="Name of a dataset. This helps separate data into different folders instead of mixing things.")
  parser.add_argument("--exp-name", type=str.lower, help="Name of experiment used as prefix for file names.")
  # Data file name
  parser.add_argument("--exp-fname-extra", type=str.lower, help="Extra text in file name after exp_name.")
  parser.add_argument("--exp-fname-param-list", type=str.lower, help="Parameters for experiment file name separated by spaces, e.g. 'rf_atten_tx0 rf_gain_rx'")
  # Data text description
  parser.add_argument("--exp-descr", type=str, help="Descriptor for experiment in logfile (no effect on filename).")
```

and for labeling

```python
  parser.add_argument("--room", type=str, help="Room where the data is collected")
  parser.add_argument("--location", type=str, help="Location where the data is collected. Usually an indicator like pos 1")
  parser.add_argument("--ref-file-name", type=str, help="File created where a room/environment is static to act as reference to current data. These should be stored in the same directory, so don't change exp_name etc. Leave empty if you don't have a reference or if this is a reference itself.")
  parser.add_argument("--label", type=str, help="Activity/pose/etc. descriptor")
```

room options:
- tcl_hallway
- tcl_meeting_room
- tcl_lab
- andreas_office

location is then for specific locations in these rooms
