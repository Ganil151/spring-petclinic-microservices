#!/bin/bash
set -e

ENV=$1
if [ -z "$ENV" ]; then
  echo "Usage: ./provision.sh <environment>"
  echo "Example: ./provision.sh dev"
  exit 1
fi

cd "$(dirname "$0")/../environments/$ENV"

echo "🚀 Applying Terraform for $ENV environment..."
terraform apply -auto-approve

echo "⏳ Waiting 60 seconds for EC2 instances to initialize..."
sleep 60

echo "📋 Extracting instance IPs from Terraform output..."
terraform output -json > /tmp/tf_output.json

# Extract EC2 public IPs (adjust based on your output structure)
INSTANCE_IPS=$(terraform output -json | jq -r '.ec2_public_ips.value[]' 2>/dev/null || echo "")

if [ -z "$INSTANCE_IPS" ]; then
  echo "⚠️  No EC2 instances found in Terraform output"
  echo "Skipping Ansible provisioning"
  exit 0
fi

echo "🔧 Generating Ansible inventory..."
INVENTORY_FILE="/tmp/ansible_inventory_${ENV}"
cat > "$INVENTORY_FILE" << EOF
[${ENV}_servers]
EOF

for IP in $INSTANCE_IPS; do
  echo "$IP ansible_user=ec2-user ansible_ssh_private_key_file=~/.ssh/id_rsa" >> "$INVENTORY_FILE"
done

echo "✅ Inventory created:"
cat "$INVENTORY_FILE"

echo "🔍 Testing SSH connectivity..."
for IP in $INSTANCE_IPS; do
  ssh-keyscan -H "$IP" >> ~/.ssh/known_hosts 2>/dev/null
done

echo "📦 Running Ansible playbook..."
cd "$(dirname "$0")/../../ansible"
ansible-playbook -i "$INVENTORY_FILE" playbooks/install-tools.yml

echo "✅ Provisioning complete for $ENV environment"
