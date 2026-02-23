#!/bin/bash
# =============================================================================
# Ansible Deployment Bootstrapper
# =============================================================================
# This script prepares the local environment and triggers the Ansible deployment.
# =============================================================================

set -e

# Change directory to the ansible root
cd "$(dirname "$0")/.."

echo "🚀 Starting Ansible Deployment Bootstrapper..."

# 1. Install required collections
if [ -f requirements.yml ]; then
    echo "📦 Installing Ansible collections..."
    ansible-galaxy collection install -r requirements.yml
fi

# 2. Check for vault password file
if [ ! -f .vault_pass ]; then
    echo "⚠️ Warning: .vault_pass not found. Automation may prompt for password."
fi

# 3. Run the main site playbook
echo "🛠️ Executing main site playbook..."
ansible-playbook -i inventory/hosts playbooks/site.yml "$@"

echo "✅ Deployment finished successfully!"
