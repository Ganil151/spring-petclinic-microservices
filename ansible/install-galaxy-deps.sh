#!/bin/bash
# Ansible Galaxy Installation Script
# This script installs all required Ansible Galaxy roles and collections

set -e  # Exit on error

echo "=================================="
echo "Installing Ansible Galaxy Dependencies"
echo "=================================="
echo ""

# Install collections
echo "Step 1: Installing Ansible Collections..."
echo "-------------------------------------------"
ansible-galaxy collection install community.mysql
ansible-galaxy collection install community.general
echo "✅ Collections installed successfully!"
echo ""

# Install roles
echo "Step 2: Installing Ansible Roles..."
echo "-------------------------------------------"
ansible-galaxy role install geerlingguy.mysql
echo "✅ Roles installed successfully!"
echo ""

# Verify installation
echo "Step 3: Verifying Installation..."
echo "-------------------------------------------"
echo "Installed roles:"
ansible-galaxy role list | grep geerlingguy.mysql || echo "⚠️  geerlingguy.mysql not found"
echo ""
echo "Installed collections:"
ansible-galaxy collection list | grep community.mysql || echo "⚠️  community.mysql not found"
ansible-galaxy collection list | grep community.general || echo "⚠️  community.general not found"
echo ""

echo "=================================="
echo "✅ Installation Complete!"
echo "=================================="
