# ============================================================================
# Maxwell's Wallet Production Environment
# ============================================================================
# Two VMs hosting demo and beta versions of Maxwell's Wallet.
# Both use Docker-in-Docker with cloudflared tunnels for external access.
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
# Base Infrastructure
# ============================================================================

data "terraform_remote_state" "base" {
  backend = "local"

  config = {
    path = "../../../../../infrastructure/terraform/terraform.tfstate"
  }
}

locals {
  base = data.terraform_remote_state.base.outputs
}

# ============================================================================
# VMID Allocation Reference
# ============================================================================

module "vmid" {
  source = "../../../../../infrastructure/terraform/modules/vmid-ranges"
}

# Note: VMIDs 1070-1071 are in the 1xxx range (originally LXC allocation)
# Keeping same VMIDs for consistency even though we're using VMs now

locals {
  # 4-digit TSSS pattern: VMID = 1000 + IP_octet
  wallet_instances = {
    "maxwells-wallet-demo" = {
      vmid        = 1070 # 1000 + 70 → IP .70
      node        = "joseph"
      transfer_ip = "192.168.11.70"
      mgmt_ip     = "192.168.5.70" # Management network
      environment = "demo"
      domain      = "demo.maxwellswallet.com"
      image_tag   = "latest" # Stable releases
    }
    "maxwells-wallet-beta" = {
      vmid        = 1071 # 1000 + 71 → IP .71
      node        = "maxwell"
      transfer_ip = "192.168.11.71"
      mgmt_ip     = "192.168.5.71" # Management network
      environment = "beta"
      domain      = "beta.maxwellswallet.com"
      image_tag   = "beta" # Dev builds from beta tag
    }
  }
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
# Maxwell's Wallet Module
# ============================================================================

module "wallet" {
  source = "../.."

  env            = "prod"
  ssh_public_key = local.base.ssh_public_key
  dns_primary    = local.base.dns_primary
  onboot         = true

  # VM configuration
  vm_template = "tmpl-ubuntu-2404-docker" # Template 1020 on everette

  vlans = {
    transfer = local.base.vlans["storage"] # .11.x subnet (TODO: rename in base)
    mgmt     = local.base.vlans["mgmt"]    # .5.x management network
  }

  instances = local.wallet_instances
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
  value       = module.wallet.inventory_file
}

# ============================================================================
# DNS Entries (exported for infrastructure/dns to create in Pi-hole)
# ============================================================================

output "dns_entries" {
  description = "A record entries for Pi-hole (hostname.network → IP)"
  value = merge(
    # Management network (.5.x) - SSH, monitoring
    {
      for name, inst in local.wallet_instances :
      "${name}.mgmt" => inst.mgmt_ip
    },
    # Storage/transfer network (.11.x)
    {
      for name, inst in local.wallet_instances :
      "${name}.storage" => inst.transfer_ip
    }
  )
}
