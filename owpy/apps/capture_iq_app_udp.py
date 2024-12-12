"""IQ Capture function

We have 64-bit per dma symbol
# REVISIT: Using pipes, this can block if the pipe is full, may consider queues
"""
# REVISIT: Removed iq_header_len and header_len (csi) here since it's anyway fixed in the hardware, we used to have this for
# backwards support, but for backwards support we should just have a tag on git for that, it's impossible to support all versions
# as one developer

from multiprocessing import Process, Queue
import multiprocessing

from owpy.timing import TIMER
from owpy.capture.misc import print_percentage_done, print_capture_info
from owpy.openwifi.udp import UDPHandler
# We require some globals from the data_parsers module so we import all of it here
from owpy.capture.data_parsers import *
from owpy.logging.logging import create_logger
from owpy.apps.misc import beep_start, beep_end, beep_1_minute

logger = create_logger("iq_capture_app")
logger.info('iq_capture_app() started')


def iq_capture_app_udp(params, verbose=0, queue_rx_data_capture=None, queue_tx_data_gen=None, shutdown_event=None):
  """
  IQ capture function  using udp

  NOTE THAT AT HIGH SAMPLING RATES, THE DATA MAY BE LOST! USE THE FILE CAPTURE MODE INSTEAD IN THAT CASE (see capture_iq_app_file.py)

  Note some important things on this being used in a multiprocessing context:
  - Do not use pipes, use queues instead, and use Manager().Queue() for the queue since we do multiprocessing not threading
  - pipes can block, queues can do non-blocking reads and writes
  - Do not use infinite loops, use a flag to stop the loop

  Args:
    params (argparse.ArgumentParser): An ArgumentParser object configured with command-line arguments.
    verbose (int, optional): Verbosity level. Defaults to 0.
    queue_rx_data_capture (multiprocessing.Queue, optional): Queue for sending data to another process. Defaults to None.
    queue_tx_data_gen (multiprocessing.Queue, optional): Queue for communicating with data generator process. Defaults to None.
    shutdown_event (multiprocessing.Event, optional): Event for signaling shutdown. Defaults to None.
  """
  print("Running the IQ capture app")

  #----------------------------------------------------------------------------
  # Helper functions
  #----------------------------------------------------------------------------

  def _cleanup():
    """
    Cleanup resources before exiting.
    """
    logger.info('_cleanup() started')

    if shutdown_event is not None and not shutdown_event.is_set():
      shutdown_event.set()

    if receiver_process and receiver_process.is_alive():
      logger.info('Terminating receiver process')
      receiver_process.join()
      logger.info('Receiver process terminated')

    logger.info('_cleanup() ended')

  #----------------------------------------------------------------------------
  # Main loop
  #----------------------------------------------------------------------------

  gen_log_file(params)
  fd_dict   = gen_files(params) if params.save_data else None
  frame_idx = 0

  percentage_done_set = set()
  openwifi_data_dict  = {}  # Mirror neulog_data_dict in neulog.py

  iq_num_dma_symbol_per_trans, csi_num_dma_symbol_per_trans = get_num_dma_symbol_per_trans(params)

  iq_bytes_per_trans  = iq_num_dma_symbol_per_trans * 8
  csi_bytes_per_trans = csi_num_dma_symbol_per_trans * 8

  # If external has not created shutdown_event, we create it here (for when we just run iq_capture_app.py by itself)
  if shutdown_event is None:
    shutdown_event = multiprocessing.Manager().Event()

  udp_fail_event = multiprocessing.Manager().Event()

  # Start data collection
  start = TIMER()
  try:
    udp_queue = multiprocessing.Manager().Queue()
    receiver_process = Process(target=udp_data_receiver, args=(udp_queue, shutdown_event, udp_fail_event))
    receiver_process.start()

    while continue_loop(params, start, frame_idx, shutdown_event):
      if not udp_queue.empty():
        queue_data    = udp_queue.get_nowait()
        data_type_idx = get_data_type(queue_data)

        if is_abnormal_length(queue_data, data_type_idx, iq_bytes_per_trans, csi_bytes_per_trans, logger):
          continue

        openwifi_data_dict["local_machine_last_sample_unix"] = TIMER()

        if frame_idx == 0:
          start = TIMER() # Reset start time at first frame
          openwifi_data_dict["local_machine_first_sample_unix"] = start
          openwifi_data_dict["local_machine_last_sample_unix"]  = start
          print(f"First sample time: {openwifi_data_dict['local_machine_first_sample_unix']}")

          if params.beep:
            beep_start()

        if data_type_idx == DATA_TYPE_LIST['iq']:
          n_frames, data_dict = process_and_save_iq(queue_data, fd_dict, iq_num_dma_symbol_per_trans, params, logger)
        elif data_type_idx == DATA_TYPE_LIST['csi']:
          n_frames, data_dict = process_and_save_csi(queue_data, fd_dict, params, logger)
        else:
          logger.error(f"Unknown data type index: {data_type_idx}")

        frame_idx += n_frames

        # Forward data through this queue to another process
        if queue_rx_data_capture is not None:
          try:
            queue_rx_data_capture.put_nowait([n_frames, data_dict])
          except Queue.Full:
            logger.warning('Queue is full, dropping data_dict')
            break
          except Exception as e:
            logger.warning(f'Error sending data_dict to queue: {e}')
            break

      if verbose:
        print_percentage_done(start, params.sampling_time, percentage_done_set)

    if params.save_data:
      update_log_file(params, openwifi_data_dict)
      close_files(fd_dict)

  except KeyboardInterrupt:
    print('User quit')

  finally:
    _cleanup()

  if frame_idx > 0:
    print(f"Last sample time: {openwifi_data_dict['local_machine_last_sample_unix']}")
    end = openwifi_data_dict['local_machine_last_sample_unix']
  else:
    end = TIMER()

  print_capture_info(start, end, frame_idx)

  if params.beep:
    beep_end()

  # Check first if data_gen_enable is a parameter
  if hasattr(params, 'data_gen_enable'):
    logger.info("data_gen_enable: %s", params.data_gen_enable)
    logger.info("queue_tx_data_gen: %s", queue_tx_data_gen)
    if params.data_gen_enable and queue_tx_data_gen is not None:
      logger.info("Sending exit command to data generator")
      queue_tx_data_gen.put_nowait('exit')


def continue_loop(params, start, frame_idx, shutdown_event, max_wait_time=60):
  """
  Determine if the capture loop should continue.

  Args:
    params (argparse.ArgumentParser): An ArgumentParser object configured with command-line arguments.
    start (float): Start time of the capture process.
    shutdown_event (Event): Event flag to stop the multiprocessing.
    shutdown_event (Event): Event flag to signal shutdown.

  Returns:
    bool: True if the loop should continue, False otherwise.
  """
  if shutdown_event is not None and shutdown_event.is_set():
    logger.info("Shutdown event set, exiting")
    return False

  # If sampling_time = -1, we sample indefinitely, if frame_idx is 0, we sample up to max_wait_time seconds
  # too, if frame_idx > 0, we sample for params.sampling_time seconds
  if params.sampling_time == -1 or (frame_idx == 0 and (TIMER() - start) < max_wait_time):
    return True
  else:
    return (TIMER() - start) < params.sampling_time


def udp_data_receiver(udp_queue, shutdown_event, udp_fail_event, max_wait_time=5, max_timeout_count=10):
  """
  Subprocess function for receiving data over UDP in multiprocessing.

  We use a timeout of 5 seconds to stop. This should be plenty to never miss any actual data

  Args:
    udp_queue (Queue): Queue for data
    shutdown_event (Event): Event object for stopping the process.
  """
  logger = create_logger("udp_data_receiver")
  logger.debug('udp_data_receiver() started')

  udp_handler = UDPHandler()

  timeout_count = 0
  data_count    = 0

  try:
    while not shutdown_event.is_set() and not udp_fail_event.is_set():
      udp_data = udp_handler.receive_data(max_wait_time=max_wait_time)

      if udp_data:
        try:
          if udp_data == "timeout":
            timeout_count += 1
            print(f"UDP Data Receiver Timeout count: {timeout_count}")
            if timeout_count > max_timeout_count:
              print(f"UDP Data Receiver Timeout count exceeded: {timeout_count}")
              udp_fail_event.set() # REVISIT: We should ideally use this to signal that in the process that generates the data need to make a new ssh connection block
              shutdown_event.set()
              break

          elif udp_data == "keyboard_interrupt":
            logger.info("Keyboard interrupt received")
            shutdown_event.set()
            break

          elif udp_data == "exception":
            logger.error("Exception received")
            shutdown_event.set()
            break

          else:
            udp_queue.put_nowait(udp_data)
            timeout_count = 0

        except Queue.Full:
          logger.warning('Queue is full, dropping data')
          break

        except Exception as e:
          logger.warning(f'Error sending data to queue: {e}')
          break

  except Exception as e:
    logger.error(f"Error in UDP data receiver: {e}")

  finally:
    udp_handler.close()
    logger.info("UDP handler closed")

  logger.info("udp_data_receiver() ended")
  print(f"Data count: {data_count}")
