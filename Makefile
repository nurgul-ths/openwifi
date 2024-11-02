#==============================================================================
#
# AUTHOR: Andreas Toftegaard Kristensen
#
# BRIEF: The Makefile is called from the experiments directory and contains the
# the main rules for setting up the openwifi_board and running the experiments.
#
#==============================================================================

#------------------------------------------------------------------------------
# Targets
#------------------------------------------------------------------------------
YAML_FILE = ""

init:
	python run_exp.py --action=init --yaml-file=$(YAML_FILE)

setup:
	python run_exp.py --action=setup --yaml-file=$(YAML_FILE)

side_ch:
	python run_exp.py --action=side_ch --yaml-file=$(YAML_FILE)

inject:
	python run_exp.py --action=inject --yaml-file=$(YAML_FILE)

run:
	python run_exp.py --action=run --yaml-file=$(YAML_FILE)
