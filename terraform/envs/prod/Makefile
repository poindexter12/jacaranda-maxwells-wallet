# Maxwell's Wallet Production - Terraform
#
# Uses OpenTofu with state encryption.
# Secrets: Uses 1Password Connect Server via secrets.mk

.DEFAULT_GOAL := help

TF = tofu
REPO_ROOT = $(shell git rev-parse --show-toplevel)

# Include secrets.mk for Connect Server integration
include $(REPO_ROOT)/secrets.mk

# ENCRYPTION_PASSPHRASE provided by secrets.mk
TF_FLAGS = -var="encryption_passphrase=$(ENCRYPTION_PASSPHRASE)"

.PHONY: help init plan apply destroy output

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

init: ## Initialize OpenTofu
	$(TF) init $(TF_FLAGS)

plan: init ## Plan infrastructure changes
	$(TF) plan $(TF_FLAGS)

apply: init ## Apply infrastructure changes
	$(TF) apply -auto-approve $(TF_FLAGS)

destroy: ## Destroy infrastructure (with confirmation)
	$(TF) destroy -auto-approve $(TF_FLAGS)

output: ## Show outputs
	$(TF) output $(TF_FLAGS)
