# Maxwell's Wallet Infrastructure

Hosting infrastructure for [Maxwell's Wallet](https://maxwellswallet.com) demo and beta environments.

**Domains:**
- https://demo.maxwellswallet.com (stable releases)
- https://beta.maxwellswallet.com (development builds)

## Quick Start

```bash
# Clone repository
git clone git@github.com:poindexter12/jacaranda-maxwells-wallet.git
cd jacaranda-maxwells-wallet

# Initialize submodule
git submodule update --init --recursive

# Install tools (just, opentofu, uv, pre-commit)
mise install

# Install Python dependencies (infrastructure uses uv pip install pattern)
uv pip install -r <(echo "ansible-core>=2.17,<2.18
ansible>=10.0.0
jmespath>=1.0.1
netaddr>=1.3.0")

# Verify 1Password secrets access
just check-secrets

# Create VMs and deploy
just prod::full

# Validate deployment
just prod::validate
```

## Architecture

Two VMs running Ubuntu 24.04 with Docker:

| Instance | VMID | Node | Domain | Image Tag |
|----------|------|------|--------|-----------|
| demo | 1070 | joseph | demo.maxwellswallet.com | :latest |
| beta | 1071 | maxwell | beta.maxwellswallet.com | :beta |

**Components:**
- SWAG (reverse proxy + Cloudflare Tunnel)
- Maxwell's Wallet (Next.js app)
- Watchtower (auto-updates)

**Traffic flow:** Internet → Cloudflare Edge → Tunnel → SWAG → App

## Common Operations

```bash
# Deploy to both instances
just prod::deploy

# Deploy demo only
just prod::deploy-demo

# Deploy beta only
just prod::deploy-beta

# Check container status
just prod::validate

# View logs
just prod::logs

# Upgrade OpenTofu providers
just upgrade

# Destroy infrastructure
just prod::destroy
```

## Auto-Updates

Watchtower monitors GHCR for new images every 5 minutes:
- **Demo** pulls `:latest` tag (stable releases)
- **Beta** pulls `:beta` tag (development builds)

No manual intervention needed for updates.

## Secrets

1Password items required:

| Item | Field | Purpose |
|------|-------|---------|
| maxwells-wallet-demo | password | Cloudflare tunnel token |
| maxwells-wallet-beta | password | Cloudflare tunnel token |
| cloudflare-maxwells-wallet | api-token | DNS validation |
| github | pat | GHCR authentication |

See [CLAUDE.md](./CLAUDE.md) for detailed documentation.

## Development

**Prerequisites:**
- [mise](https://mise.jdx.dev/) - Tool version management
- [1Password CLI](https://developer.1password.com/docs/cli/) - Secrets access
- SSH access to Proxmox cluster
- GitHub access to jacaranda-shared-libs

**Setup:**
1. Clone repo + initialize submodule
2. Run `mise install` to get tools
3. Install Python deps with `uv pip install` (see Quick Start)
4. Verify secrets with `just check-secrets`

**Workflow:**
1. Make infrastructure changes in `terraform/envs/prod/`
2. Run `just prod::plan` to preview
3. Run `just prod::apply` to create/update VMs
4. Run `just prod::deploy` to configure via Ansible
5. Run `just prod::validate` to verify

## Troubleshooting

**Tunnel not connecting:**
```bash
ssh ubuntu@192.168.5.70 "docker logs swag 2>&1 | grep cloudflare"
```

**Containers not running:**
```bash
ssh ubuntu@192.168.5.70 "docker ps"
```

**Manual update:**
```bash
ssh ubuntu@192.168.5.70 "cd /opt/maxwells-wallet && docker compose pull && docker compose up -d"
```

See [CLAUDE.md](./CLAUDE.md) for comprehensive troubleshooting guide.

## License

Private infrastructure repository. Not licensed for public use.
