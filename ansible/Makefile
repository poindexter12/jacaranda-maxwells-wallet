# Maxwell's Wallet - Ansible
#
# Deploys SWAG + cloudflared + app containers with Watchtower auto-updates.
# Secrets from 1Password: tunnel tokens + Cloudflare API token

.DEFAULT_GOAL := help

ANSIBLE_CFG = ansible.cfg
PLAYBOOK = playbooks/deploy.yaml

# 1Password items
OP_VAULT = Homelab

# DNS hostnames (resolved via Pi-hole .mgmt zone)
HOST_DEMO = maxwells-wallet-demo.mgmt
HOST_BETA = maxwells-wallet-beta.mgmt

.PHONY: help deploy deploy-demo deploy-beta logs validate clean-containers

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

deploy: ## Deploy to all hosts (demo + beta)
	@ANSIBLE_CONFIG=$(ANSIBLE_CFG) ansible-playbook $(PLAYBOOK) \
		-e "github_token=$$(op read 'op://$(OP_VAULT)/github/pat')" \
		-e "cloudflare_api_token=$$(op read 'op://$(OP_VAULT)/cloudflare-maxwells-wallet/api-token')" \
		-e "cloudflare_tunnel_token_demo=$$(op read 'op://$(OP_VAULT)/maxwells-wallet-demo/password')" \
		-e "cloudflare_tunnel_token_beta=$$(op read 'op://$(OP_VAULT)/maxwells-wallet-beta/password')"

deploy-demo: ## Deploy demo only
	@ANSIBLE_CONFIG=$(ANSIBLE_CFG) ansible-playbook $(PLAYBOOK) \
		--limit maxwells-wallet-demo \
		-e "github_token=$$(op read 'op://$(OP_VAULT)/github/pat')" \
		-e "cloudflare_api_token=$$(op read 'op://$(OP_VAULT)/cloudflare-maxwells-wallet/api-token')" \
		-e "cloudflare_tunnel_token_demo=$$(op read 'op://$(OP_VAULT)/maxwells-wallet-demo/password')" \
		-e "cloudflare_tunnel_token_beta=''"

deploy-beta: ## Deploy beta only
	@ANSIBLE_CONFIG=$(ANSIBLE_CFG) ansible-playbook $(PLAYBOOK) \
		--limit maxwells-wallet-beta \
		-e "github_token=$$(op read 'op://$(OP_VAULT)/github/pat')" \
		-e "cloudflare_api_token=$$(op read 'op://$(OP_VAULT)/cloudflare-maxwells-wallet/api-token')" \
		-e "cloudflare_tunnel_token_demo=''" \
		-e "cloudflare_tunnel_token_beta=$$(op read 'op://$(OP_VAULT)/maxwells-wallet-beta/password')"

logs: ## View container logs (all hosts)
	@for host in $(HOST_DEMO) $(HOST_BETA); do \
		echo "=== $$host ==="; \
		ssh ubuntu@$$host "docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>/dev/null || echo "  not reachable"; \
	done

validate: ## Verify deployments are healthy
	@echo "=== Checking Maxwell's Wallet deployments ==="
	@for host in $(HOST_DEMO) $(HOST_BETA); do \
		echo "--- $$host ---"; \
		ssh ubuntu@$$host "docker ps --format '{{.Names}}: {{.Status}}'" 2>/dev/null || echo "  not reachable"; \
		echo ""; \
	done

clean-containers: ## Stop and remove all containers (for fresh deploy)
	@for host in $(HOST_DEMO) $(HOST_BETA); do \
		echo "=== Cleaning $$host ==="; \
		ssh ubuntu@$$host "cd /opt/maxwells-wallet && docker compose down -v 2>/dev/null || true"; \
	done
