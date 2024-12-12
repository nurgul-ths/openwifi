REPO_DIR    := $(shell git rev-parse --show-toplevel)
MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURR_DIR    := $(dir $(MKFILE_PATH))
YAML_FILE   := $(CURR_DIR)/config.yaml

all: run

init:
	cd $(REPO_DIR); python run_exp.py --action=init --yaml-file=$(YAML_FILE)

setup:
	cd $(REPO_DIR); python run_exp.py --action=setup --yaml-file=$(YAML_FILE)

side_ch:
	cd $(REPO_DIR); python run_exp.py --action=side_ch --yaml-file=$(YAML_FILE)

inject:
	cd $(REPO_DIR); python run_exp.py --action=inject --yaml-file=$(YAML_FILE)

run:
	cd $(REPO_DIR); python run_exp.py --action=run --yaml-file=$(YAML_FILE)


copy_files:
	@echo "Copying .sh, .yaml, and .md files to $(REPO_DIR)/$(DEST_DIR)"
	@mkdir -p $(REPO_DIR)/$(DEST_DIR)
	@cp *.sh $(REPO_DIR)/$(DEST_DIR)
	@cp *.yaml $(REPO_DIR)/$(DEST_DIR)
	@cp *.md $(REPO_DIR)/$(DEST_DIR)
