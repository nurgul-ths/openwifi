"""Helper functions for openwifi
"""

def frequency_to_channel(freq_mhz):
  """Converts a frequency in MHz to a channel number for 20 MHz channels in the 2.4GHz and 5GHz bands.

  Args:
    freq_mhz (int): Frequency in MHz

  Returns:
    int: Channel number
  """
  # 2.4GHz band
  if freq_mhz == 2412: return 1
  elif freq_mhz == 2417: return 2
  elif freq_mhz == 2422: return 3
  elif freq_mhz == 2427: return 4
  elif freq_mhz == 2432: return 5
  elif freq_mhz == 2437: return 6
  elif freq_mhz == 2442: return 7
  elif freq_mhz == 2447: return 8
  elif freq_mhz == 2452: return 9
  elif freq_mhz == 2457: return 10
  elif freq_mhz == 2462: return 11
  elif freq_mhz == 2467: return 12
  elif freq_mhz == 2472: return 13
  elif freq_mhz == 2484: return 14  # Channel 14 is only used in Japan.

  # 5GHz band
  elif freq_mhz == 5180: return 36
  elif freq_mhz == 5200: return 40
  elif freq_mhz == 5220: return 44
  elif freq_mhz == 5240: return 48
  elif freq_mhz == 5260: return 52
  elif freq_mhz == 5280: return 56
  elif freq_mhz == 5300: return 60
  elif freq_mhz == 5320: return 64
  elif freq_mhz == 5500: return 100
  elif freq_mhz == 5520: return 104
  elif freq_mhz == 5540: return 108
  elif freq_mhz == 5560: return 112
  elif freq_mhz == 5580: return 116
  elif freq_mhz == 5600: return 120
  elif freq_mhz == 5620: return 124
  elif freq_mhz == 5640: return 128
  elif freq_mhz == 5660: return 132
  elif freq_mhz == 5680: return 136
  elif freq_mhz == 5700: return 140
  elif freq_mhz == 5720: return 144
  elif freq_mhz == 5745: return 149
  elif freq_mhz == 5765: return 153
  elif freq_mhz == 5785: return 157
  elif freq_mhz == 5805: return 161
  elif freq_mhz == 5825: return 165
  else:
    raise ValueError(f"Frequency {freq_mhz} MHz does not correspond to a recognized 20 MHz channel.")


def channel_to_frequency(channel):
  """Converts a channel number to its corresponding carrier frequency for 20 MHz channels in the 2.4GHz and 5GHz bands.

  Args:
    channel (int): Channel number

  Returns:
    int: Carrier frequency in MHz
  """
  # 2.4GHz band channels
  if channel == 1: return 2412
  elif channel == 2: return 2417
  elif channel == 3: return 2422
  elif channel == 4: return 2427
  elif channel == 5: return 2432
  elif channel == 6: return 2437
  elif channel == 7: return 2442
  elif channel == 8: return 2447
  elif channel == 9: return 2452
  elif channel == 10: return 2457
  elif channel == 11: return 2462
  elif channel == 12: return 2467
  elif channel == 13: return 2472
  elif channel == 14: return 2484  # Channel 14 is only used in Japan.

  # 5GHz band channels
  elif channel == 36: return 5180
  elif channel == 40: return 5200
  elif channel == 44: return 5220
  elif channel == 48: return 5240
  elif channel == 52: return 5260
  elif channel == 56: return 5280
  elif channel == 60: return 5300
  elif channel == 64: return 5320
  elif channel == 100: return 5500
  elif channel == 104: return 5520
  elif channel == 108: return 5540
  elif channel == 112: return 5560
  elif channel == 116: return 5580
  elif channel == 120: return 5600
  elif channel == 124: return 5620
  elif channel == 128: return 5640
  elif channel == 132: return 5660
  elif channel == 136: return 5680
  elif channel == 140: return 5700
  elif channel == 144: return 5720
  elif channel == 149: return 5745
  elif channel == 153: return 5765
  elif channel == 157: return 5785
  elif channel == 161: return 5805
  elif channel == 165: return 5825
  else:
    raise ValueError(f"Channel {channel} does not correspond to a recognized 20 MHz carrier frequency.")
