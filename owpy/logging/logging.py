""" Functions for data logging """

import os
import logging
from datetime import datetime

def create_logger(name):
 """
 Base logger configuration for defaults. Used in the different apps to set up their individual loggers
 with the correct settings. Ensure that in functions where you want to use this logger you are
 in the same process (if doing multiprocessing) and that you call with the name of the logger
 at the top of the file. An example is given below for the processing_app

 >>> import logging
 >>> logger = logging.getLogger('processing_app')

 Args:
   name (str): Name of the logger
 """
 logger = logging.getLogger(name)
 logger.propagate = False  # Do not pass messages to the root logger (also stops printing to the terminal)

 format = '[%(asctime)s] %(levelname)s [%(name)s.%(funcName)s:%(lineno)d] %(message)s'

 handler = logging.FileHandler(get_logger_fname(name), mode='w')
 handler.setFormatter(logging.Formatter(format))

 logger.addHandler(handler)
 # logger.setLevel(logging.NOTSET)  # Level 0  - Log absolutely everything (lowest level)
 # logger.setLevel(logging.DEBUG)   # Level 10 - Detailed information for debugging
 # logger.setLevel(logging.INFO)    # Level 20 - General operational messages
 # logger.setLevel(logging.WARNING) # Level 30 - Warning messages for potential issues
 # logger.setLevel(logging.ERROR)   # Level 40 - Error messages for serious problems
 # logger.setLevel(logging.CRITICAL)# Level 50 - Critical errors that may prevent program from running

 logger.setLevel(logging.DEBUG)  # Current setting: Detailed debug information

 return logger

def get_logger_fname(name):
 """
 Function to create consistent logger file name with date and time appended to end.

 Args:
   name (str): Name of the logger

 Returns:
   str: Path to the log file
 """
 current_datetime = datetime.now().strftime("%Y%m%d_%H%M%S")  # Format: YYYYMMDD_HHMMSS
 log_dir = 'logfiles'

 if not os.path.exists(log_dir):
   os.makedirs(log_dir)

 # Return the filename with path in the logfiles directory
 return os.path.join(log_dir, 'logging_{}_{}.log'.format(name, current_datetime))

def log_stream_content(stdin, stdout, stderr, logger):
 """
 Log content from stdin, stdout, and stderr streams using the given logger.

 Args:
   stdin: Standard input stream
   stdout: Standard output stream
   stderr: Standard error stream
   logger: Logger instance to use for logging
 """
 try:
   stdin_content = stdin.read().decode('utf-8')
   if stdin_content:
     logger.debug("STDIN: %s", stdin_content)
 except:
   pass

 try:
   stdout_content = stdout.read().decode('utf-8')
   if stdout_content:
     logger.debug("STDOUT: %s", stdout_content)
 except:
   pass

 try:
   stderr_content = stderr.read().decode('utf-8')
   if stderr_content:
     logger.debug("STDERR: %s", stderr_content)
 except:
   pass
