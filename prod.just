# Maxwell's Wallet Production Environment Module
#
# Two VMs: demo (latest) and beta (beta tag)
#
# Usage: just prod::<recipe>
#
# Examples:
#   just prod::apply           # Create VMs
#   just prod::deploy          # Deploy to both instances
#   just prod::deploy-demo     # Deploy demo.maxwellswallet.com only
#   just prod::deploy-beta     # Deploy beta.maxwellswallet.com only
#   just prod::full            # Apply + deploy
#   just prod::validate        # Check deployment health (includes preflight)
#   just prod::logs            # Show container logs

import '../../lib/infrastructure/just/terraform.just'
import '../../lib/infrastructure/just/ansible.just'

# ============================================================================
# Terraform Operations
# ============================================================================

# Initialize terraform
init: (tf-init "prod")

# Plan infrastructure changes
plan: (tf-plan "prod")

# Apply infrastructure changes
[confirm("Create/update Maxwell's Wallet VMs?")]
apply: (tf-apply "prod")

# Destroy infrastructure
[confirm("Destroy Maxwell's Wallet VMs?")]
destroy: (tf-destroy "prod")

# ============================================================================
# Ansible Operations
# ============================================================================

# Deploy to all instances (demo + beta)
deploy:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible
    mkdir -p logs
    export ANSIBLE_LOG_PATH="logs/ansible-$(date +%Y%m%d-%H%M%S).log"

    ANSIBLE_CONFIG=ansible.cfg {{ uv_run }} ansible-playbook \
        {{ ansible_verbose }} \
        -i inventory/prod.yaml \
        playbooks/deploy.yaml \
        -e "github_token=$({{ op_read }} 'op://Homelab/github/pat')" \
        -e "cloudflare_api_token=$({{ op_read }} 'op://Homelab/cloudflare-maxwells-wallet/api-token')" \
        -e "cloudflare_tunnel_token_demo=$({{ op_read }} 'op://Homelab/maxwells-wallet-demo/password')" \
        -e "cloudflare_tunnel_token_beta=$({{ op_read }} 'op://Homelab/maxwells-wallet-beta/password')"

# Deploy demo only
deploy-demo:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible
    mkdir -p logs
    export ANSIBLE_LOG_PATH="logs/ansible-$(date +%Y%m%d-%H%M%S).log"

    ANSIBLE_CONFIG=ansible.cfg {{ uv_run }} ansible-playbook \
        {{ ansible_verbose }} \
        -i inventory/prod.yaml \
        playbooks/deploy.yaml \
        --limit maxwells-wallet-demo \
        -e "github_token=$({{ op_read }} 'op://Homelab/github/pat')" \
        -e "cloudflare_api_token=$({{ op_read }} 'op://Homelab/cloudflare-maxwells-wallet/api-token')" \
        -e "cloudflare_tunnel_token_demo=$({{ op_read }} 'op://Homelab/maxwells-wallet-demo/password')" \
        -e "cloudflare_tunnel_token_beta=''"

# Deploy beta only
deploy-beta:
    #!/usr/bin/env bash
    set -euo pipefail
    cd ansible
    mkdir -p logs
    export ANSIBLE_LOG_PATH="logs/ansible-$(date +%Y%m%d-%H%M%S).log"

    ANSIBLE_CONFIG=ansible.cfg {{ uv_run }} ansible-playbook \
        {{ ansible_verbose }} \
        -i inventory/prod.yaml \
        playbooks/deploy.yaml \
        --limit maxwells-wallet-beta \
        -e "github_token=$({{ op_read }} 'op://Homelab/github/pat')" \
        -e "cloudflare_api_token=$({{ op_read }} 'op://Homelab/cloudflare-maxwells-wallet/api-token')" \
        -e "cloudflare_tunnel_token_demo=''" \
        -e "cloudflare_tunnel_token_beta=$({{ op_read }} 'op://Homelab/maxwells-wallet-beta/password')"

# ============================================================================
# Validation
# ============================================================================

# Preflight: DNS and SSH connectivity
[private]
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%b=== DNS Resolution Test (prod environment) ===%b\n' '{{ BOLD }}' '{{ NC }}'
    for host in maxwells-wallet-demo maxwells-wallet-beta; do
        printf '%b%s.lan: %b' '{{ CYAN }}' "$host" '{{ NC }}'
        dig +short $host.lan || printf '%b✗ FAIL%b\n' '{{ RED }}' '{{ NC }}'
    done
    echo ""

    printf '%b=== SSH Test ===%b\n' '{{ BOLD }}' '{{ NC }}'
    for host in maxwells-wallet-demo maxwells-wallet-beta; do
        printf '%b%s.lan: %b' '{{ CYAN }}' "$host" '{{ NC }}'
        if ssh -o BatchMode=yes -o ConnectTimeout=5 ubuntu@$host.lan "hostname" 2>/dev/null; then
            printf '%b✓ OK%b\n' '{{ GREEN }}' '{{ NC }}'
        else
            printf '%b✗ FAIL%b\n' '{{ RED }}' '{{ NC }}'
        fi
    done

# Validate deployment health (fast checks)
validate: verify
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%b=== Testing Maxwell'\''s Wallet (prod) ===%b\n' '{{ BOLD }}' '{{ NC }}'
    echo ""

    for host in maxwells-wallet-demo maxwells-wallet-beta; do
        printf '%b--- %s ---%b\n' '{{ BOLD }}' "$host" '{{ NC }}'

        # SSH connectivity
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 ubuntu@$host.lan "hostname" 2>/dev/null >/dev/null; then
            printf '%b✗ SSH: FAIL%b\n' '{{ RED }}' '{{ NC }}'
            echo ""
            continue
        fi
        printf '%b✓ SSH: OK%b\n' '{{ GREEN }}' '{{ NC }}'

        # Docker containers
        if ssh -o BatchMode=yes ubuntu@$host.lan "docker ps" 2>/dev/null | grep -q "maxwells-wallet"; then
            printf '%b✓ maxwells-wallet container running%b\n' '{{ GREEN }}' '{{ NC }}'
        else
            printf '%b✗ maxwells-wallet container not running%b\n' '{{ RED }}' '{{ NC }}'
        fi

        if ssh -o BatchMode=yes ubuntu@$host.lan "docker ps" 2>/dev/null | grep -q "swag"; then
            printf '%b✓ swag container running%b\n' '{{ GREEN }}' '{{ NC }}'
        else
            printf '%b✗ swag container not running%b\n' '{{ RED }}' '{{ NC }}'
        fi

        if ssh -o BatchMode=yes ubuntu@$host.lan "docker ps" 2>/dev/null | grep -q "watchtower"; then
            printf '%b✓ watchtower container running%b\n' '{{ GREEN }}' '{{ NC }}'
        else
            printf '%b✗ watchtower container not running%b\n' '{{ RED }}' '{{ NC }}'
        fi

        echo ""
    done

# Show container logs from both instances
logs:
    #!/usr/bin/env bash
    set -euo pipefail
    printf '%b=== Container Status ===%b\n' '{{ BOLD }}' '{{ NC }}'
    for host in maxwells-wallet-demo.lan maxwells-wallet-beta.lan; do
        printf '%b--- %s ---%b\n' '{{ CYAN }}' "$host" '{{ NC }}'
        ssh ubuntu@$host 'docker ps --format "table {{{{.Names}}\t{{{{.Status}}}}"' 2>/dev/null || echo "  not reachable"
        echo ""
    done

# ============================================================================
# Workflows
# ============================================================================

# Full deployment: apply + deploy
full: apply
    @echo "Waiting 30s for VMs to be ready..."
    @sleep 30
    just prod::deploy
