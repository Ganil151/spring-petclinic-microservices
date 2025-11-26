#!/bin/bash

#############################################
# Fix kubectl Configuration
# Resolves "connection refused localhost:8080" error
#############################################

set -e

echo "=========================================="
echo "Fixing kubectl Configuration"
echo "=========================================="
echo ""

# Check if we're running as the correct user
CURRENT_USER=$(whoami)
echo "Current user: $CURRENT_USER"
echo ""

#############################################
# Step 1: Check if K8s is installed
#############################################

echo "=== Step 1: Checking Kubernetes Installation ==="
echo ""

if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "✗ ERROR: /etc/kubernetes/admin.conf not found"
    echo ""
    echo "Kubernetes is not installed or kubeadm init hasn't been run yet."
    echo ""
    echo "Check if kubelet is running:"
    echo "  sudo systemctl status kubelet"
    echo ""
    echo "Check kubeadm logs:"
    echo "  sudo journalctl -u kubelet -n 100"
    echo ""
    echo "If K8s master installation is still running, wait for it to complete."
    exit 1
fi

echo "✓ Found /etc/kubernetes/admin.conf"
echo ""

#############################################
# Step 2: Set up kubectl config
#############################################

echo "=== Step 2: Setting up kubectl config ==="
echo ""

# Create .kube directory
mkdir -p ~/.kube

# Copy admin.conf
echo "Copying admin.conf to ~/.kube/config..."
sudo cp /etc/kubernetes/admin.conf ~/.kube/config

# Set correct ownership
echo "Setting ownership..."
sudo chown $(id -u):$(id -g) ~/.kube/config

# Set correct permissions
chmod 600 ~/.kube/config

echo "✓ kubectl config created"
echo ""

#############################################
# Step 3: Verify kubectl works
#############################################

echo "=== Step 3: Verifying kubectl ==="
echo ""

# Test kubectl
if kubectl version --short 2>/dev/null || kubectl version 2>/dev/null; then
    echo "✓ kubectl is working!"
else
    echo "⚠ kubectl still has issues"
    echo ""
    echo "Check API server status:"
    echo "  sudo systemctl status kube-apiserver"
    echo ""
    echo "Check if API server is listening:"
    echo "  sudo netstat -tlnp | grep 6443"
    exit 1
fi

echo ""

#############################################
# Step 4: Check cluster status
#############################################

echo "=== Step 4: Checking Cluster Status ==="
echo ""

echo "Nodes:"
kubectl get nodes

echo ""
echo "System Pods:"
kubectl get pods -n kube-system

echo ""

#############################################
# Step 5: Add kubectl completion (optional)
#############################################

echo "=== Step 5: Adding kubectl completion ==="
echo ""

if ! grep -q "kubectl completion bash" ~/.bashrc; then
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    echo 'alias k=kubectl' >> ~/.bashrc
    echo 'complete -F __start_kubectl k' >> ~/.bashrc
    echo "✓ Added kubectl completion to ~/.bashrc"
else
    echo "✓ kubectl completion already configured"
fi

echo ""

#############################################
# Success
#############################################

echo "=========================================="
echo "kubectl Configuration Complete!"
echo "=========================================="
echo ""
echo "kubectl is now configured and working."
echo ""
echo "Test it:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""
echo "To use completion in current session:"
echo "  source ~/.bashrc"
echo ""
echo "=========================================="
