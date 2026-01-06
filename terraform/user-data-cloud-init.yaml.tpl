#cloud-config
# Cloud-init for virtual VMs - SSH certificate authentication only
# No key-based auth - if broken, rebuild the VM
#
# User CA baked in so VM trusts user certs from birth.
# Host cert signed after creation via signing playbook.

hostname: ${hostname}
manage_etc_hosts: true
fqdn: ${hostname}.mgmt

users:
  - name: ${username}
    groups: [adm, docker, sudo]
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
    # No ssh_authorized_keys - cert auth only for virtual VMs
    lock_passwd: false
    passwd: ${password_hash}

chpasswd:
  expire: False

# SSH User CA - VM trusts user certificates signed by this CA
write_files:
  - path: /etc/ssh/user_ca.pub
    content: |
      ${ssh_user_ca_pubkey}
    permissions: '0644'
    owner: root:root
  - path: /etc/ssh/sshd_config.d/99-ssh-ca.conf
    content: |
      # Trust User CA for certificate authentication
      TrustedUserCAKeys /etc/ssh/user_ca.pub
      # Host certificate (will be signed after VM creation)
      HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
    permissions: '0644'
    owner: root:root

runcmd:
  - systemctl start qemu-guest-agent
  - systemctl enable qemu-guest-agent
  - systemctl restart sshd
