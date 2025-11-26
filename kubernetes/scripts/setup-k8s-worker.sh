#!/bin/bash
#############################################
# K8s Worker Setup
# Prepares worker node to join cluster
#############################################

set -euo pipefail

echo "=========================================="
echo "K8s Worker Setup"
echo "=========================================="
echo ""

# Disable swap
echo "=== Disabling swap ==="
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "✓ Swap disabled"
echo ""

# Start services
echo "=== Starting services ==="
sudo systemctl start containerd && sudo systemctl enable containerd
sudo systemctl start kubelet && sudo systemctl enable kubelet
echo "✓ Services started"
echo ""

# Check status
echo "=== Status ==="
echo "containerd: $(systemctl is-active containerd)"
echo "kubelet: $(systemctl is-active kubelet)"
echo ""

if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo "✓ Worker has joined cluster"
else
    echo "⚠ Worker not joined yet"
    echo ""
    echo "On master, run:"
    echo "  kubeadm token create --print-join-command"
    echo ""
    echo "Then run the output here with sudo"
fi
echo ""
