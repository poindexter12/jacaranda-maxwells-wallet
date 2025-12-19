# ============================================================================
# Maxwell's Wallet Variables
# ============================================================================

variable "env" {
  description = "Environment name (prod)"
  type        = string
}

variable "instances" {
  description = "Map of VM instances to create"
  type = map(object({
    vmid        = number
    node        = string
    transfer_ip = string
    mgmt_ip     = string # Management network IP (192.168.5.x)
    environment = string # demo or beta
    domain      = string # e.g., demo.maxwellswallet.com
    image_tag   = string # Docker image tag to deploy
  }))
}

# ============================================================================
# VM Configuration
# ============================================================================

variable "vm_template" {
  description = "VM template to clone (Ubuntu 24.04 with Docker)"
  type        = string
  default     = "tmpl-ubuntu-2404-docker"
}

variable "vm_cores" {
  description = "Number of CPU cores per VM"
  type        = number
  default     = 1
}

variable "vm_memory" {
  description = "Memory in MB per VM"
  type        = number
  default     = 1024
}

variable "vm_storage" {
  description = "Storage pool for VM disk (use shared storage like ceph for linked clones)"
  type        = string
  default     = "ceph-seymour"
}

variable "vm_disk_size" {
  description = "Disk size per VM"
  type        = number
  default     = 20
}

variable "onboot" {
  description = "Start VM on Proxmox boot"
  type        = bool
  default     = true
}

# ============================================================================
# Network Configuration
# ============================================================================

variable "vlans" {
  description = "VLAN configuration"
  type = map(object({
    bridge  = string
    gateway = string
    domain  = string
  }))
}

variable "dns_primary" {
  description = "Primary DNS server"
  type        = string
  default     = "192.168.1.20"
}

# ============================================================================
# Cloud-init Configuration
# ============================================================================

variable "cloud_init_user" {
  description = "Cloud-init default user"
  type        = string
  default     = "ubuntu"
}

variable "cloud_init_password" {
  description = "Cloud-init default password (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for access"
  type        = string
}
