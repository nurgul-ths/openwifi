"""Misc helper functions for the data capture functions
"""

from owpy.timing import TIMER

def print_percentage_done(time_start, sampling_time, percentage_done_set):
  """
  Prints the percentage of measurements completed, rounded to the nearest whole number.
  Only prints when the percentage_done is a whole number and it has not been printed before.

  Uses a set to keep track of the percentage_done values that have been printed already

  Args:
    time_start (float): Start time of the capture (seconds).
    sampling_time (float): Sampling time of the capture (seconds).
    percentage_done_set (set): Set of percentage_done values that have been printed.
  """
  if sampling_time == -1:
    return

  percentage_done = round((TIMER() - time_start) / sampling_time * 100)
  if percentage_done not in percentage_done_set:
    percentage_done_set.add(percentage_done)
    print(f"\tMeasurements: {percentage_done}%", end='\r')


def print_capture_info(time_start, time_end, frame_idx):
  """
  Prints the statistics of the data capture.

  Args:
    time_start (float): Start time of the capture (seconds).
    time_end (float): End time of the capture (seconds).
    frame_idx (int): Number of frames captured.
  """

  duration = time_end - time_start
  rate     = frame_idx / duration

  print("\nCapture done")
  print("\tMeasured for: {} seconds".format(duration))
  print("\tCapture: {} frames".format(frame_idx))
  print("\tCapture rate: {} sps".format(rate))


def print_sampling_time(sampling_time_sec):
  """Prints the sampling time in hours, minutes, and seconds based on sampling time in seconds

  Args:
    sampling_time_sec (int): The sampling time in seconds.
  """

  hours   =  sampling_time_sec // 3600
  minutes = (sampling_time_sec % 3600) // 60
  seconds = (sampling_time_sec % 3600) % 60

  if sampling_time_sec == -1:
    print("\nStarting data collection indefinitely\n")
  else:
    print(f"\nStarting data collection for {hours} hours {minutes} minutes {seconds} seconds\n")
