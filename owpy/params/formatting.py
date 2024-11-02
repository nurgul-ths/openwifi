"""Helpers for formatting the command line arguments
"""


import argparse
from argparse import HelpFormatter
from operator import attrgetter

class SortingHelpFormatter(HelpFormatter):
  """Sort everything for the command line arguments"""

  def add_arguments(self, actions):
    actions = sorted(actions, key=attrgetter('option_strings'))
    super(SortingHelpFormatter, self).add_arguments(actions)

class CustomFormatter(argparse.ArgumentDefaultsHelpFormatter, SortingHelpFormatter):
  """Use inheritance to get multiple formatters"""
  pass
