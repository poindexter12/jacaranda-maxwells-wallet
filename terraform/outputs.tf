# ============================================================================
# Maxwell's Wallet Outputs
# ============================================================================

output "instances" {
  description = "Created VM instances"
  value = {
    for name, vm in proxmox_vm_qemu.wallet : name => {
      vmid        = vm.vmid
      name        = vm.name
      node        = vm.target_node
      transfer_ip = var.instances[name].transfer_ip
      environment = var.instances[name].environment
      domain      = var.instances[name].domain
      image_tag   = var.instances[name].image_tag
    }
  }
}

output "inventory_file" {
  description = "Path to generated Ansible inventory"
  value       = local_file.ansible_inventory.filename
}

output "dns_entries" {
  description = "DNS entries for Pi-hole"
  value = merge(
    { for name, inst in var.instances : "${name}.mgmt" => inst.mgmt_ip },
    { for name, inst in var.instances : "${name}.transfer" => inst.transfer_ip }
  )
}
