# Maxwell's Wallet Service
#
# Hosts demo and beta versions via Cloudflare Tunnels.
# VMs auto-update when new Docker images are pushed to GHCR.
#
# Usage: just prod::<recipe>
#
# Examples:
#   just prod::full              # Create VMs + deploy
#   just prod::deploy            # Deploy to both instances
#   just prod::deploy-demo       # Deploy demo only
#   just prod::deploy-beta       # Deploy beta only
#   just prod::validate          # Check deployment health
#   just check-secrets           # Verify 1Password items exist

import '../../infrastructure/just/styles.just'
import '../../infrastructure/just/secrets.just'

# Module declaration
mod prod

# Show available recipes
@_default:
    just --list

# ============================================================================
# Cross-Environment Utilities
# ============================================================================

# Verify 1Password items exist
check-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%b─── Checking 1Password items ───%b\n' '{{ BOLD }}' '{{ NC }}'

    items=(
        "Homelab/maxwells-wallet-demo/password"
        "Homelab/maxwells-wallet-beta/password"
        "Homelab/cloudflare-maxwells-wallet/api-token"
        "Homelab/github/pat"
    )

    for item in "${items[@]}"; do
        vault=$(echo "$item" | cut -d/ -f1)
        name=$(echo "$item" | cut -d/ -f2)
        field=$(echo "$item" | cut -d/ -f3)
        if {{ op_read }} "op://$item" > /dev/null 2>&1; then
            printf '%b  ✓ %s/%s/%s exists%b\n' '{{ GREEN }}' "$vault" "$name" "$field" '{{ NC }}'
        else
            printf '%b  ✗ %s/%s/%s missing%b\n' '{{ RED }}' "$vault" "$name" "$field" '{{ NC }}'
        fi
    done
