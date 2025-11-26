#!/bin/bash

#############################################
# K3s Agent Installation Script
# Minimal installation - just installs K3s agent
# Server IP and token must be provided
#############################################

set -euo pipefail

echo "=========================================="
echo "K3s Agent Installation"
echo "=========================================="
echo ""
date
echo ""

# Configuration
K3S_VERSION="v1.28.5+k3s1"

#############################################
# System Preparation
#############################################

echo "=== Step 1: System Preparation ==="

# Update system
echo "Updating system packages..."
sudo dnf update -y

# Install only essential packages
echo "Installing required packages..."
sudo dnf install -y --allowerasing curl

# Disable SELinux
echo "Disabling SELinux..."
sudo setenforce 0 2>/dev/null || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Disable swap
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "✓ System preparation complete"
echo ""

#############################################
# K3s Agent Installation
#############################################

echo "=== Step 2: Installing K3s Agent ==="

# Get node info
INTERNAL_IP=$(hostname -I | awk '{print $1}')
NODE_NAME="k3s-agent-$(hostname -s)"

echo "Node IP: $INTERNAL_IP"
echo "Node Name: $NODE_NAME"
echo ""

# Install K3s agent
echo "Installing K3s agent $K3S_VERSION..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" \
    K3S_URL="https://${K3S_SERVER_IP}:6443" \
    K3S_TOKEN="${K3S_TOKEN}" \
    sh -s - agent \
    --node-name "$NODE_NAME" \
    --node-ip "$INTERNAL_IP"

# Wait for service
echo ""
echo "Waiting for K3s agent service..."
for i in {1..30}; do
    if sudo systemctl is-active --quiet k3s-agent; then
        echo "✓ K3s agent is running"
        break
    fi
    sleep 2
done

echo ""
echo "=========================================="
echo "K3s Agent Installation Complete!"
echo "=========================================="
echo ""
echo "Node '$NODE_NAME' joined cluster at $K3S_SERVER_IP"
echo ""
echo "Verify on server:"
echo "  kubectl get nodes"
echo ""
echo "Check logs:"
echo "  sudo journalctl -u k3s-agent -f"
echo ""
echo "=========================================="
