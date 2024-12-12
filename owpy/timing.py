"""Functions for execution time timing
"""

import sys
import time

TIMER = time.time # This returns unix time and is expressed in UTC, not local time

# if "linux" in sys.platform:
#   print("\nDETECTED LINUX PLATFORM")
#   TIMER = time.time # On most platforms the best timer is time.time
# else:
#   print("\nDETECTED WINDOWS PLATFORM")
#   TIMER = time.clock # On Windows, the best timer is time.clock
