# ============================================================================
# Maxwell's Wallet VM Module
# ============================================================================
# Creates VM(s) for hosting Maxwell's Wallet web application via cloudflared
# tunnel. Uses Ubuntu 24.04 VM template with Docker pre-installed.
#
# NOTE: Provider is configured in the calling environment (envs/prod),
# not here. The module just uses whatever provider the root module configures.

terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      # Version controlled by root module lockfile
    }
  }
}

# ============================================================================
# Cloud-init Configuration
# ============================================================================

# Generate user-data cloud-init from template (SSH + hostname + User CA)
resource "local_file" "user_data_cloud_init" {
  for_each = var.instances

  content = templatefile("${path.module}/user-data-cloud-init.yaml.tpl", {
    hostname           = each.key
    username           = var.cloud_init_user
    ssh_public_key     = trimspace(var.ssh_public_key)
    password_hash      = var.cloud_init_password_hash
    ssh_user_ca_pubkey = trimspace(var.ssh_user_ca_pubkey)
  })
  filename = "${path.module}/.generated/user-data-${each.key}.yaml"
}

# Upload cloud-init files to Proxmox snippets directory
resource "null_resource" "upload_cloud_init_files" {
  for_each = var.instances

  triggers = {
    user_hash = local_file.user_data_cloud_init[each.key].content_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      scp ${local_file.user_data_cloud_init[each.key].filename} root@${each.value.node}.lan:/var/lib/vz/snippets/user-data-${each.key}.yaml
    EOT
  }

  depends_on = [local_file.user_data_cloud_init]
}

# ============================================================================
# Maxwell's Wallet VMs
# ============================================================================

resource "proxmox_vm_qemu" "wallet" {
  for_each = var.instances

  # VM identification
  vmid        = each.value.vmid
  name        = each.key
  target_node = each.value.node

  # Clone from template (linked clone - requires shared storage like ceph)
  clone      = var.vm_template
  full_clone = false

  # VM settings
  onboot   = var.onboot
  vm_state = "running"
  agent    = 1
  scsihw   = "virtio-scsi-single"

  # Serial device for cloud-init output
  serial {
    id = 0
  }

  # Resources
  cpu {
    cores   = var.vm_cores
    sockets = 1
  }
  memory = var.vm_memory

  # Disk configuration
  disks {
    scsi {
      scsi0 {
        disk {
          size    = var.vm_disk_size
          storage = var.vm_storage
        }
      }
    }
    # Cloud-init drive - required for applying cloud-init settings
    ide {
      ide2 {
        cloudinit {
          storage = var.vm_storage
        }
      }
    }
  }

  # Network: eth0 - Transfer VLAN (external traffic via cloudflared)
  network {
    id     = 0
    model  = "virtio"
    bridge = var.vlans["transfer"].bridge
  }

  # Network: eth1 - Management VLAN (SSH, internal access)
  network {
    id     = 1
    model  = "virtio"
    bridge = var.vlans["mgmt"].bridge
  }

  # Cloud-init configuration (custom template with User CA)
  os_type  = "cloud-init"
  cicustom = "user=local:snippets/user-data-${each.key}.yaml"

  # Static IP configuration via cloud-init
  ipconfig0    = "ip=${each.value.transfer_ip}/24,gw=${var.vlans["transfer"].gateway}"
  ipconfig1    = "ip=${each.value.mgmt_ip}/24"
  nameserver   = var.dns_primary
  searchdomain = var.vlans["transfer"].domain

  depends_on = [null_resource.upload_cloud_init_files]

  # Tags for organization
  tags = join(",", compact([
    each.value.environment, # demo, beta
    "maxwells-wallet",
    var.env
  ]))

  lifecycle {
    ignore_changes = [
      # Prevent recreation on template changes
      clone,
    ]
  }
}

# ============================================================================
# Sign Host Certificates
# ============================================================================
# Signs host cert after VM creation. Uses StrictHostKeyChecking=no since we're
# establishing trust (signing the cert) - verifying host key first is circular.
# Future: Issue #83 tracks moving to ACME-SSH for non-SSH-based signing.

resource "null_resource" "sign_host_cert" {
  for_each = var.instances

  triggers = {
    vm_id = proxmox_vm_qemu.wallet[each.key].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

      echo "=== Waiting for ${each.key} to be SSH-ready ==="
      for i in $(seq 1 30); do
        if ssh $SSH_OPTS ${var.cloud_init_user}@${each.key}.lan "echo ready" 2>/dev/null; then
          break
        fi
        echo "  Attempt $i/30 - waiting..."
        sleep 5
      done

      echo "=== Fetching host public key from ${each.key} ==="
      HOST_PUBKEY=$(ssh $SSH_OPTS ${var.cloud_init_user}@${each.key}.lan \
        "cat /etc/ssh/ssh_host_ed25519_key.pub")

      echo "=== Signing certificate on step-ca ==="
      HOST_IPS=$(ssh $SSH_OPTS ${var.cloud_init_user}@${each.key}.lan \
        "hostname -I | tr ' ' ','")

      PRINCIPALS="${each.key},${each.key}.lan,${each.key}.mgmt,$${HOST_IPS%,}"

      echo "$HOST_PUBKEY" | ssh root@step-ca.lan "cat > /tmp/${each.key}.pub"

      ssh root@step-ca.lan "
        set -e
        export OP_SERVICE_ACCOUNT_TOKEN=\$(cat /var/lib/step-ca/secrets/.op_token)
        KEY_FILE=/var/lib/step-ca/secrets/.ephemeral_ca_key.${each.key}
        op read 'op://SSH-CA/ssh-ca-host-virtual/private_key' > \$KEY_FILE
        chmod 600 \$KEY_FILE
        ssh-keygen -s \$KEY_FILE -I ${each.key} -h -n $PRINCIPALS -V +52w /tmp/${each.key}.pub
        rm -f \$KEY_FILE
      "

      SIGNED_CERT=$(ssh root@step-ca.lan "cat /tmp/${each.key}-cert.pub")
      ssh root@step-ca.lan "rm -f /tmp/${each.key}.pub /tmp/${each.key}-cert.pub"

      echo "=== Installing certificate on ${each.key} ==="
      echo "$SIGNED_CERT" | ssh $SSH_OPTS ${var.cloud_init_user}@${each.key}.lan \
        "sudo tee /etc/ssh/ssh_host_ed25519_key-cert.pub > /dev/null && sudo systemctl reload ssh"

      echo "=== ${each.key} host certificate signed and installed ==="
    EOT
  }

  depends_on = [proxmox_vm_qemu.wallet]
}

# ============================================================================
# Outputs for Ansible Inventory
# ============================================================================

locals {
  hosts = {
    for name, inst in var.instances : name => {
      ansible_host   = "${name}.lan"    # SSH via .lan for cert auth
      transfer_ip    = inst.transfer_ip # For SWAG/cloudflared
      mgmt_ip        = inst.mgmt_ip
      dns_mgmt       = "${name}.mgmt"   # DNS name on mgmt network
      wallet_env     = inst.environment # Renamed from 'environment' (Ansible reserved word)
      domain         = inst.domain
      swag_subdomain = inst.environment # demo or beta
      image_tag      = inst.image_tag
      vmid           = inst.vmid
    }
  }

  ansible_inventory = {
    all = {
      children = {
        maxwells_wallet = { hosts = local.hosts }
      }
      vars = {
        ansible_user = var.cloud_init_user
      }
    }
  }
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/${var.env}.yaml"
  content         = "---\n# Auto-generated by Terraform - do not edit\n${yamlencode(local.ansible_inventory)}"
  file_permission = "0644"
}
