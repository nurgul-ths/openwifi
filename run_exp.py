#!/usr/bin/env python

"""
run_exp.py

Script for running an experiment for collecting CSI or I/Q samples. Note that
this script is actually run from the experiments folder.
"""

import argparse

from owpy.params.misc import check_required_attr, update_parser_defaults_from_yaml
from owpy.params.help import PrintCombinedHelp
from owpy.params.params_openwifi import argparser_openwifi, get_attr_no_check_openwifi, check_attr_openwifi, process_params_openwifi
from owpy.params.formatting import CustomFormatter
from owpy.apps.run import run


if __name__ == '__main__':

  # Command line
  cmdline_parser = argparse.ArgumentParser(prog='cmdline', description="Parameters for command line", formatter_class=CustomFormatter, add_help=False)
  cmdline_parser.add_argument('--yaml-file', type=str, default=None, help='Path to the YAML file.')
  cmdline_parser.add_argument('-h', '--help', action=PrintCombinedHelp, help='show this help message and exit')

  cmdline_params, cmdline_unknown = cmdline_parser.parse_known_args()
  if not cmdline_params.yaml_file:
    raise ValueError("YAML file must be provided using --yaml-file argument.")

  # Splice parsers (openwifi, processing etc.)
  parser = argparse.ArgumentParser(prog='prog', description="Parameters for experiments", add_help=False, formatter_class=CustomFormatter)
  parser = argparser_openwifi(parser)

  # Update defaults with file
  section_list = ['openwifi']
  parser = update_parser_defaults_from_yaml(parser, cmdline_params.yaml_file, section_list)

  # Parse all known arguments from the command line and overwrite both original defaults and file
  params, unknown = parser.parse_known_args(cmdline_unknown)

  # Error if unknown arguments are provided not present in any parsers
  if unknown:
    raise ValueError("This argument {} in unknown".format(unknown))

  # Check set parameters
  attr_no_check = get_attr_no_check_openwifi(params)
  check_required_attr(params, attr_no_check)
  check_attr_openwifi(params)
  process_params_openwifi(params)

  run(params)
