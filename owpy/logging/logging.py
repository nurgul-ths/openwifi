"""
Utility functions for logging data in various applications.
Provides a consistent setup for loggers and a standard naming convention for log files.
"""

import os
import logging
from datetime import datetime

def create_logger(name):
  """
  Create and configure a logger with a given name.

  This function sets up a logger that writes log messages to a dedicated file.
  By default, it logs at the DEBUG level (which includes all messages DEBUG and above).

  To use this logger in another module, ensure you import and get the logger by name:

  >>> import logging
  >>> logger = logging.getLogger('processing_app')
  >>> logger.debug('This is a debug message')

  Args:
    name (str): Name of the logger, typically the application or module name.

  Returns:
    logging.Logger: Configured logger instance.
  """

  logger = logging.getLogger(name)
  logger.propagate = False  # Prevent messages from bubbling up to the root logger

  log_format = '[%(asctime)s] %(levelname)s [%(name)s.%(funcName)s:%(lineno)d] %(message)s'

  handler = logging.FileHandler(get_logger_fname(name), mode='w')
  handler.setFormatter(logging.Formatter(log_format))

  logger.addHandler(handler)

  # Possible log levels (uncomment one as needed):
  # logger.setLevel(logging.NOTSET)    # Log all messages (lowest threshold)
  # logger.setLevel(logging.INFO)      # Log INFO, WARNING, ERROR, CRITICAL
  # logger.setLevel(logging.DEBUG)       # Log DEBUG and above (DEBUG, INFO, WARNING, ERROR, CRITICAL)
  logger.setLevel(logging.CRITICAL)  # Log only CRITICAL messages. This effectively disables all other messages.

  return logger


def get_logger_fname(name):
  """
  Generate a standardized log filename for the given logger name, including a timestamp.

  The log files are placed in the 'logfiles' directory.
  If the directory does not exist, it is created.

  Args:
    name (str): Logger name or application name to include in the log filename.

  Returns:
    str: Full path to the log file.
  """

  current_datetime = datetime.now().strftime("%Y%m%d_%H%M%S")  # YYYYMMDD_HHMMSS format
  log_dir = 'logfiles'

  if not os.path.exists(log_dir):
    os.makedirs(log_dir)

  return os.path.join(log_dir, f'logging_{name}_{current_datetime}.log')


def log_stream_content(stdin, stdout, stderr, logger):
  """
  Read from stdin, stdout, and stderr streams and log their contents using the provided logger.

  If any of these streams contain data, it will be logged at the DEBUG level.
  This function is useful when capturing the output of subprocesses or other external commands.

  Args:
    stdin:  Input stream to read as standard input.
    stdout: Output stream to read as standard output.
    stderr: Error stream to read as standard error.
    logger (logging.Logger): Logger to write the contents.
  """

  try:
    stdin_content = stdin.read().decode('utf-8')
    if stdin_content:
      logger.debug("STDIN: %s", stdin_content)
  except Exception:
    pass

  try:
    stdout_content = stdout.read().decode('utf-8')
    if stdout_content:
      logger.debug("STDOUT: %s", stdout_content)
  except Exception:
    pass

  try:
    stderr_content = stderr.read().decode('utf-8')
    if stderr_content:
      logger.debug("STDERR: %s", stderr_content)
  except Exception:
    pass
