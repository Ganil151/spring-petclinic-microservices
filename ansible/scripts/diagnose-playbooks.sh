#!/bin/bash

# Diagnostic script to check Ansible playbook validity and group structure

set -e

echo "==========================================="
echo "Ansible Playbook Diagnostic"
echo "==========================================="
echo ""

ANSIBLE_DIR="/home/ganil/spring-petclinic-microservices/ansible"
cd "$ANSIBLE_DIR" || exit 1

# Check inventory syntax
echo "[1/5] Checking inventory syntax..."
if ansible-inventory -i inventory.ini --list &>/dev/null; then
  echo "  ✓ Inventory is valid"
else
  echo "  ✗ Inventory has errors:"
  ansible-inventory -i inventory.ini --list || true
  exit 1
fi

# List all groups
echo ""
echo "[2/5] Defined host groups:"
ansible-inventory -i inventory.ini --graph 2>/dev/null || true

# Check playbook syntax
echo ""
echo "[3/5] Checking playbook syntax..."
for playbook in playbooks/*.yml; do
  if ansible-playbook "$playbook" --syntax-check &>/dev/null; then
    echo "  ✓ $(basename $playbook)"
  else
    echo "  ✗ $(basename $playbook) has syntax errors:"
    ansible-playbook "$playbook" --syntax-check || true
  fi
done

# List available roles
echo ""
echo "[4/5] Available roles:"
if [ -d "roles" ]; then
  ls -la roles/ | grep -v "^total\|^d.*\.$" | awk '{print "  " $NF}' || echo "  (no custom roles found)"
else
  echo "  roles directory not found"
fi

# Check requirements
echo ""
echo "[5/5] Galaxy role requirements:"
if [ -f "requirements.yml" ]; then
  grep -A 5 "^roles:" requirements.yml || echo "  (no galaxy roles defined)"
else
  echo "  requirements.yml not found"
fi

echo ""
echo "==========================================="
echo "Diagnostic complete!"
echo "==========================================="
