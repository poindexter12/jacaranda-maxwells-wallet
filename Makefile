# Maxwell's Wallet Service
#
# Hosts demo and beta versions of Maxwell's Wallet via Cloudflare Tunnels.
# VMs auto-update when new Docker images are pushed to GHCR.
#
# Self-documenting: run `make help` to see all targets

.DEFAULT_GOAL := help

.PHONY: help
.PHONY: prod-init prod-plan prod-apply prod-destroy prod-deploy prod-full prod-validate prod-logs
.PHONY: deploy-demo deploy-beta check-secrets

# ============================================================================
# CONFIGURATION
# ============================================================================

OP_VAULT = Homelab

# ============================================================================
# TARGETS
# ============================================================================

##@ Production Environment

prod-init: ## Initialize OpenTofu
	@$(MAKE) -C terraform/envs/prod init

prod-plan: ## Plan infrastructure changes
	@$(MAKE) -C terraform/envs/prod plan

prod-apply: ## Create VMs (mw-demo + mw-beta)
	@$(MAKE) -C terraform/envs/prod apply

prod-destroy: ## Destroy VMs
	@$(MAKE) -C terraform/envs/prod destroy

prod-deploy: ## Deploy app to all VMs (Ansible)
	@$(MAKE) -C ansible deploy

prod-full: prod-apply ## Create VMs (cert signing included) + deploy
	@$(MAKE) prod-deploy

prod-validate: ## Check deployment health
	@$(MAKE) -C ansible validate

prod-logs: ## View container logs
	@$(MAKE) -C ansible logs

##@ Individual Deployments

deploy-demo: ## Deploy demo.maxwellswallet.com only
	@$(MAKE) -C ansible deploy-demo

deploy-beta: ## Deploy beta.maxwellswallet.com only
	@$(MAKE) -C ansible deploy-beta

##@ Setup

check-secrets: ## Verify 1Password items exist
	@echo "Checking 1Password items..."
	@op read 'op://$(OP_VAULT)/maxwells-wallet-demo/password' > /dev/null && echo "✓ maxwells-wallet-demo" || echo "✗ maxwells-wallet-demo MISSING"
	@op read 'op://$(OP_VAULT)/maxwells-wallet-beta/password' > /dev/null && echo "✓ maxwells-wallet-beta" || echo "✗ maxwells-wallet-beta MISSING"

##@ Help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
