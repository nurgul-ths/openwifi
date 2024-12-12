"""Helpers for the command line arguments

REVISIT: Clean this up
"""

import yaml

def update_parser_defaults_from_yaml(parser, yaml_fname, section_list):
  """Update argparse parser defaults using values from a YAML file. The YAML file should be sectioned
  by the section_list, with each section matching parameters for a specific parser.

  Args:
    parser (argparse.ArgumentParser): Argument parser to update with YAML defaults.
    yaml_fname (str): Path to the YAML file with configuration parameters.
    section_list (list): List of YAML sections to apply to the parser.

  Returns:
    argparse.ArgumentParser: The updated argument parser.

  Raises:
    FileNotFoundError: If the YAML file does not exist.
    yaml.YAMLError: If the YAML file is invalid or cannot be parsed.
  """
  with open(yaml_fname, 'r') as f:
    yaml_params = yaml.safe_load(f)
    for section in section_list:
      section_params = yaml_params.get(section, {})
      parser.set_defaults(**section_params)

  return parser


def check_required_attr(params, attrs_no_check):
  """
  Checks if required attributes are set and prints the status of optional attributes.
  In each argchecker function (e.g., argchecker_openwifi), attributes not to check are defined in `attrs_no_check`.
  All other attributes are assumed to be required.

  Args:
    params (argparse.Namespace): Parsed command-line arguments or settings object.
    attrs_no_check (list): List of optional attributes not requiring checks.

  Raises:
    ValueError: If a required attribute is not set.
  """

  # Determine attributes to check (non-callable, not in attrs_no_check, not private)
  attrs_to_check = [attr for attr in dir(params)
                    if not callable(getattr(params, attr))
                    and attr not in attrs_no_check
                    and not attr.startswith('__')]

  # Retrieve verbose status safely
  verbose = getattr(params, 'verbose', False)

  if verbose:
    print("Required attributes (must be set):")

  for attr in attrs_to_check:
    value = getattr(params, attr, None)
    if verbose:
      print(f"\tArgument '{attr}' is set with value: {value}")
    if value is None:
      raise ValueError(f"Argument '{attr}' is not set.")

  if verbose:
    print("Optional attributes (okay if not set):")
    for attr in attrs_no_check:
      if attr == 'help':
        continue
      value = getattr(params, attr, None)
      status = "not set (okay)" if value is None else f"set with value: {value}"
      print(f"\tArgument '{attr}' is {status}")


def cmdline_to_dict(cmdline_list):
  """
  Converts a list of command-line arguments to a dictionary, allowing custom command-line argument handling.
  This supports a configuration hierarchy where defaults are set by argparse, potentially overridden by YAML,
  and finally overridden by command-line arguments.

  Args:
    cmdline_list (list): List of command-line arguments following patterns like `--key=value`, `--key value`, or `-k value`.

  Returns:
    dict: A dictionary representation of the command-line arguments with `--key=value` converted to `{'key': 'value'}`.

  Raises:
    ValueError: If a key is missing its corresponding value in the `--key value` or `-k value` formats.

  Example:
    Input: ['--action=run', '--filt-angle-step=0.1']
    Output: {'action': 'run', 'filt_angle_step': '0.1'}
  """

  args_dict = {}
  iter_args = iter(cmdline_list)
  for arg in iter_args:
    if arg.startswith("--"):

      if "=" in arg:
        # Case: "--key=value"
        key, value = arg[2:].split("=", 1)
        key = key.replace('-', '_')
        args_dict[key] = value

      else:
        # Case: "--key value"
        key = arg[2:].replace('-', '_')
        try:
          value = next(iter_args)
          args_dict[key] = value
        except StopIteration:
          raise ValueError(f"Expected a value for argument '{arg}'")

    elif arg.startswith("-") and len(arg) == 2:
      # Case: "-k value"
      key = arg[1:]
      try:
        value = next(iter_args)
        args_dict[key] = value
      except StopIteration:
        raise ValueError(f"Expected a value for argument '{arg}'")

  return args_dict



