#------------------------------------------------------------------------------
# Repo targets
#------------------------------------------------------------------------------
submodule_init:
	git submodule init
	ln -s submodules/neulog/neulog owpy/neulog

submodule_update:
	git submodule update

YAML_FILE = "yaml/exp_iq.yaml"

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

#------------------------------------------------------------------------------
# Github copy
#------------------------------------------------------------------------------

github:
	python github_lite.py --src_dir /home/andreas/gitlab_wisense/devices/openwifi_boards --dst_dir /home/andreas/github/wcnc2024_monostatic_sensing_openwifi --config_file /home/andreas/gitlab_wisense/devices/openwifi_boards/github_lite.yaml
