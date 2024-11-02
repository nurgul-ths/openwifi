"""For printing on help when we have multiple parsers but we want the output sorted by parser
"""

import argparse
from owpy.params.params_openwifi import argparser_openwifi

class PrintCombinedHelp(argparse.Action):
  def __init__(self, option_strings, dest=argparse.SUPPRESS, default=argparse.SUPPRESS, help=None):
    super(PrintCombinedHelp, self).__init__(option_strings=option_strings, dest=dest, default=default, nargs=0, help=help)

  def __call__(self, parser, namespace, values, option_string=None):
    # Print the help of the main parser first
    parser.print_help()

    # Print the help for each additional parser
    print("\nOpenWifi Arguments:")
    argparser_openwifi().print_help()

    # Exit the script after printing help
    parser.exit()
