#!/bin/bash

#############################################
# Fix kubectl for ec2-user
# Run this as ec2-user (not root)
#############################################

echo "=========================================="
echo "Configuring kubectl for ec2-user"
echo "=========================================="
echo ""

# Check current user
if [ "$(whoami)" = "root" ]; then
    echo "ERROR: Do not run this script as root!"
    echo "Run as ec2-user: bash $0"
    exit 1
fi

echo "Current user: $(whoami)"
echo ""

# Create .kube directory
mkdir -p ~/.kube

# Copy admin.conf
echo "Copying kubectl config..."
sudo cp /etc/kubernetes/admin.conf ~/.kube/config

# Fix ownership for ec2-user
echo "Setting ownership..."
sudo chown $(id -u):$(id -g) ~/.kube/config

# Fix permissions
chmod 600 ~/.kube/config

echo "✓ kubectl config created for ec2-user"
echo ""

# Test kubectl
echo "Testing kubectl..."
if kubectl get nodes 2>/dev/null; then
    echo ""
    echo "✓ kubectl is working!"
else
    echo "✗ kubectl test failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "Success!"
echo "=========================================="
echo ""
echo "kubectl is now configured for ec2-user"
echo ""
echo "Try these commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""
