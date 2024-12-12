"""Helper functions for apps
"""

import time

def print_sampling_time(sampling_time_sec):
  """Prints the sampling time in hours, minutes, and seconds based on sampling time in seconds"""

  hours   =  sampling_time_sec // 3600
  minutes = (sampling_time_sec % 3600) // 60
  seconds = (sampling_time_sec % 3600) % 60

  if sampling_time_sec == -1:
    print("\nStarting data collection indefinitely\n")
  else:
    print(f"\nStarting data collection for {hours} hours {minutes} minutes {seconds} seconds\n")


def beep(n_beeps):
  """Beeps n_beeps times with a 0.1 second delay between beeps"""
  for _ in range(n_beeps):
    print("\a") # Beep
    time.sleep(0.1)

# Make 3 functions, beep start has 4 beeps, beep end has 8 beeps, and beep 1 minute has 1 beep

def beep_start():
  """Beeps 4 times with a 0.1 second delay between beeps"""
  beep(4)

def beep_end():
  """Beeps 8 times with a 0.1 second delay between beeps"""
  beep(8)

def beep_1_minute():
  """Beeps 1 time with a 0.1 second delay between beeps"""
  beep(1)
