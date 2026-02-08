#!/bin/bash
set -e

ENV=$1
if [ -z "$ENV" ]; then
  echo "Usage: ./deploy-full.sh <environment>"
  echo "Example: ./deploy-full.sh dev"
  exit 1
fi

SCRIPT_DIR="$(dirname "$0")"

echo "🚀 Starting full deployment for $ENV environment..."

# Step 1: Initialize Terraform
echo "📦 Step 1/5: Initializing Terraform..."
"$SCRIPT_DIR/init.sh" "$ENV"

# Step 2: Plan infrastructure
echo "📋 Step 2/5: Planning infrastructure..."
"$SCRIPT_DIR/plan.sh" "$ENV"

# Step 3: Apply infrastructure
echo "🏗️  Step 3/5: Applying infrastructure..."
"$SCRIPT_DIR/apply.sh" "$ENV"

# Step 4: Wait for instances
echo "⏳ Step 4/5: Waiting for EC2 instances..."
sleep 60

# Step 5: Run Ansible
echo "🔧 Step 5/5: Provisioning with Ansible..."
cd "$SCRIPT_DIR/../environments/$ENV"

# Generate inventory from Terraform output
INVENTORY_FILE="/tmp/ansible_inventory_${ENV}"
terraform output -json | jq -r '.ec2_public_ips.value[]' 2>/dev/null | while read IP; do
  echo "$IP ansible_user=ec2-user" >> "$INVENTORY_FILE"
done

if [ -s "$INVENTORY_FILE" ]; then
  # Wait for SSH
  "$SCRIPT_DIR/wait-for-ssh.sh" "$INVENTORY_FILE"
  
  # Run Ansible
  cd "$SCRIPT_DIR/../../ansible"
  ansible-playbook -i "$INVENTORY_FILE" playbooks/install-tools.yml
  
  echo "✅ Full deployment complete!"
else
  echo "⚠️  No EC2 instances to provision"
fi
