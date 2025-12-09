#!/bin/bash

# Script to setup kubeconfig for root and ec2-user

set -e

echo "==========================================="
echo "Setting up kubeconfig for all users"
echo "==========================================="
echo ""

# Find the kubeconfig file
if [ -f "/root/.kube/config" ]; then
  KUBECONFIG_SOURCE="/root/.kube/config"
elif [ -f "/home/ec2-user/.kube/config" ]; then
  KUBECONFIG_SOURCE="/home/ec2-user/.kube/config"
elif [ -f "/etc/kubernetes/admin.conf" ]; then
  KUBECONFIG_SOURCE="/etc/kubernetes/admin.conf"
else
  echo "ERROR: Could not find kubeconfig file!"
  exit 1
fi

echo "Found kubeconfig at: $KUBECONFIG_SOURCE"
echo ""

# Setup for root user
echo "[1/2] Setting up kubeconfig for root..."
if [ ! -d "/root/.kube" ]; then
  mkdir -p /root/.kube
fi

cp "$KUBECONFIG_SOURCE" /root/.kube/config
chmod 600 /root/.kube/config
export KUBECONFIG=/root/.kube/config

echo "  ✓ Root kubeconfig configured"
echo "  Location: /root/.kube/config"

# Setup for ec2-user
echo ""
echo "[2/2] Setting up kubeconfig for ec2-user..."
if [ ! -d "/home/ec2-user/.kube" ]; then
  mkdir -p /home/ec2-user/.kube
  chown ec2-user:ec2-user /home/ec2-user/.kube
fi

cp "$KUBECONFIG_SOURCE" /home/ec2-user/.kube/config
chown ec2-user:ec2-user /home/ec2-user/.kube/config
chmod 600 /home/ec2-user/.kube/config

echo "  ✓ ec2-user kubeconfig configured"
echo "  Location: /home/ec2-user/.kube/config"

# Test connectivity
echo ""
echo "[3/2] Testing connectivity..."
export KUBECONFIG=/root/.kube/config

if kubectl cluster-info &>/dev/null; then
  echo "  ✓ kubectl is working correctly"
  kubectl cluster-info | grep -E "Kubernetes|server|CoreDNS"
else
  echo "  ✗ kubectl connection still failing"
  kubectl cluster-info || true
fi

echo ""
echo "==========================================="
echo "Setup complete!"
echo "==========================================="
echo ""
echo "You can now run kubectl commands without sudo:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
