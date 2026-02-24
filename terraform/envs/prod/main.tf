# ============================================================================
# Maxwell's Wallet Production Environment
# ============================================================================
# Two VMs hosting demo and beta versions of Maxwell's Wallet.
# Both use Docker with cloudflared tunnels for external access.
# Watchtower handles automatic image updates.
#
# VMID Allocation: 1070-1071 (4-digit TSSS: 1xxx + IP octet)
# Reference: .claude/skills/vmid-allocation/SKILL.md
#
# Domains:
#   - demo.maxwellswallet.com (stable releases, :latest tag)
#   - beta.maxwellswallet.com (dev builds, :beta tag)

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "= 3.0.2-rc04"
    }
  }
}

# ============================================================================
# Base Infrastructure Module
# ============================================================================

module "base_infra" {
  source = "git::https://github.com/poindexter12/jacaranda-shared-libs.git//infrastructure/terraform/modules/base-infra?ref=v1.4.0"

  # Path to hub state file (sibling repo convention)
  hub_state_path = "../../../../../jacaranda-infra/infrastructure/terraform/terraform.tfstate"
}

locals {
  base = module.base_infra
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "proxmox" {
  pm_api_url          = local.base.proxmox_api_url
  pm_api_token_id     = local.base.proxmox_api_token_id
  pm_api_token_secret = local.base.proxmox_api_token_secret
  pm_tls_insecure     = local.base.proxmox_tls_insecure
  pm_timeout          = 600
}

# ============================================================================
# Instance Configuration
# ============================================================================

locals {
  instances = {
    "maxwells-wallet-demo" = {
      vmid        = 1070
      node        = "joseph"
      mgmt_ip     = "192.168.5.70"
      transfer_ip = "192.168.11.70"
    }
    "maxwells-wallet-beta" = {
      vmid        = 1071
      node        = "maxwell"
      mgmt_ip     = "192.168.5.71"
      transfer_ip = "192.168.11.71"
    }
  }
}

# ============================================================================
# Maxwell's Wallet VMs (Shared VM Module via lib/)
# ============================================================================

module "wallet" {
  source = "../../../lib/infrastructure/terraform/modules/vm"

  name     = "maxwells-wallet"
  template = "tmpl-ubuntu-2404-docker"
  env      = "prod"
  vlans    = local.base.vlans

  # SSH CA configuration
  ssh_user_ca_pubkey       = local.base.ssh_user_ca_pubkey
  cloud_init_password_hash = local.base.cloud_init_password_hash
  dns_server               = local.base.dns_primary

  # VM instances (infrastructure only)
  instances = local.instances

  # Resources
  cores        = 1
  memory       = 1024
  os_storage   = "ceph-seymour"
  os_disk_size = "20G"
  onboot       = true

  # Use module's inventory generation (app config in Ansible host_vars/)
  ansible_inventory_path = "${path.module}/../../../ansible/inventory/prod.yaml"
  ansible_group_name     = "maxwells_wallet"
}

# ============================================================================
# Outputs
# ============================================================================

output "instances" {
  description = "Maxwell's Wallet instances"
  value       = module.wallet.instances
}

output "inventory_file" {
  description = "Generated Ansible inventory path"
  value       = module.wallet.ansible_inventory_path
}

# ============================================================================
# DNS Entries (exported for Pi-hole)
# ============================================================================

output "dns_entries" {
  description = "DNS A record entries for Pi-hole"
  value       = module.wallet.dns_entries
}

output "cname_entries" {
  description = "CNAME entries for Pi-hole"
  value       = module.wallet.cname_entries
}
