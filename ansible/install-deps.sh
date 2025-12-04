#!/bin/bash
# Manual Ansible Galaxy Installation
# This bypasses the requirements file and installs directly

echo "Installing Ansible Collections..."
ansible-galaxy collection install community.mysql --force
ansible-galaxy collection install community.general --force

echo ""
echo "Installing Ansible Roles..."
ansible-galaxy role install geerlingguy.mysql --force

echo ""
echo "✅ Installation complete!"
echo ""
echo "Verify with:"
echo "  ansible-galaxy collection list"
echo "  ansible-galaxy role list"
