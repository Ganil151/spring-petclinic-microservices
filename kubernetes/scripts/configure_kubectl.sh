#!/bin/bash

set -e

echo "=== Configuring kubectl for current user ==="
echo ""

# Create .kube directory
echo "Step 1: Creating .kube directory..."
mkdir -p $HOME/.kube

# Copy the admin config
echo "Step 2: Copying admin config..."
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# Set proper ownership
echo "Step 3: Setting proper ownership..."
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo ""
echo "✓ kubectl configuration complete!"
echo ""

# Verify it works
echo "Step 4: Verifying kubectl access..."
if kubectl get nodes &> /dev/null; then
    echo "✓ kubectl is working correctly"
    echo ""
    echo "=== Cluster Nodes ==="
    kubectl get nodes
else
    echo "⚠ Warning: kubectl command failed"
    echo "Please check if the Kubernetes API server is running:"
    echo "  sudo systemctl status kubelet"
fi

echo ""
echo "You can now use kubectl commands!"
