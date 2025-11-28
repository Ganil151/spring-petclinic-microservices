#!/bin/bash

#############################################
# Kubernetes Worker Auto-Fix Script
# Automatically fixes common worker issues
#############################################

set -e

echo "=========================================="
echo "Kubernetes Worker Auto-Fix"
echo "=========================================="
echo ""
date
echo ""

#############################################
# Fix 1: Disable Swap
#############################################

echo "=========================================="
echo "Fix 1: Disabling Swap"
echo "=========================================="
echo ""

SWAP_TOTAL=$(free -g | grep Swap | awk '{print $2}')

if [ "$SWAP_TOTAL" -gt 0 ]; then
    echo "Disabling swap..."
    sudo swapoff -a
    
    # Disable permanently
    sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
    
    echo "✓ Swap disabled"
else
    echo "✓ Swap already disabled"
fi

echo ""

#############################################
# Fix 2: Start Container Runtime
#############################################

echo "=========================================="
echo "Fix 2: Starting Container Runtime"
echo "=========================================="
echo ""

if systemctl is-active --quiet containerd; then
    echo "✓ containerd is already running"
else
    echo "Starting containerd..."
    sudo systemctl start containerd
    sudo systemctl enable containerd
    echo "✓ containerd started"
fi

echo ""

#############################################
# Fix 3: Start Kubelet
#############################################

echo "=========================================="
echo "Fix 3: Starting Kubelet"
echo "=========================================="
echo ""

if systemctl is-active --quiet kubelet; then
    echo "✓ kubelet is already running"
else
    echo "Starting kubelet..."
    sudo systemctl start kubelet
    sudo systemctl enable kubelet
    echo "✓ kubelet started"
fi

echo ""
echo "Kubelet status:"
sudo systemctl status kubelet --no-pager | head -15

echo ""

#############################################
# Fix 4: Check Node Registration
#############################################

echo "=========================================="
echo "Fix 4: Checking Node Registration"
echo "=========================================="
echo ""

if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo "✓ Worker has joined the cluster"
    echo ""
    echo "kubelet.conf exists"
else
    echo "⚠ Worker has NOT joined the cluster yet"
    echo ""
    echo "To join this worker to the cluster:"
    echo "  1. On the master, run:"
    echo "     kubeadm token create --print-join-command"
    echo ""
    echo "  2. Copy the output and run it on this worker with sudo"
    echo ""
    echo "Example:"
    echo "  sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
fi

echo ""

#############################################
# Fix 5: Wait for Kubelet to Stabilize
#############################################

echo "=========================================="
echo "Fix 5: Waiting for Kubelet to Stabilize"
echo "=========================================="
echo ""

echo "Waiting 30 seconds for kubelet to stabilize..."
sleep 30

if systemctl is-active --quiet kubelet; then
    echo "✓ kubelet is running"
else
    echo "✗ kubelet failed to start"
    echo ""
    echo "Check logs:"
    echo "  sudo journalctl -u kubelet -n 50"
fi

echo ""

#############################################
# Verification
#############################################

echo "=========================================="
echo "Verification"
echo "=========================================="
echo ""

echo "Service Status:"
echo "  containerd: $(systemctl is-active containerd 2>/dev/null || echo 'not running')"
echo "  kubelet: $(systemctl is-active kubelet 2>/dev/null || echo 'not running')"
echo ""

echo "Swap Status:"
SWAP_NOW=$(free -g | grep Swap | awk '{print $2}')
if [ "$SWAP_NOW" -eq 0 ]; then
    echo "  ✓ Swap is disabled"
else
    echo "  ✗ Swap is still enabled"
fi

echo ""

# Check if worker has pods
if command -v crictl &>/dev/null; then
    echo "Pods on this worker:"
    sudo crictl pods 2>/dev/null || echo "  No pods yet (normal if just joined)"
fi

echo ""

#############################################
# Summary
#############################################

echo "=========================================="
echo "Fix Summary"
echo "=========================================="
echo ""

# Count issues
ISSUES=0

if ! systemctl is-active --quiet kubelet; then
    echo "✗ kubelet is not running"
    ISSUES=$((ISSUES + 1))
fi

if ! systemctl is-active --quiet containerd; then
    echo "✗ containerd is not running"
    ISSUES=$((ISSUES + 1))
fi

SWAP_CHECK=$(free -g | grep Swap | awk '{print $2}')
if [ "$SWAP_CHECK" -gt 0 ]; then
    echo "✗ Swap is still enabled"
    ISSUES=$((ISSUES + 1))
fi

if [ "$ISSUES" -eq 0 ]; then
    echo "✓ ALL ISSUES FIXED!"
    echo ""
    echo "Worker node is healthy!"
    echo ""
    
    if [ -f /etc/kubernetes/kubelet.conf ]; then
        echo "Worker has joined the cluster."
        echo ""
        echo "Verify on master:"
        echo "  kubectl get nodes"
        echo "  kubectl get pods -A -o wide"
    else
        echo "Worker is ready to join the cluster."
        echo ""
        echo "Get join command from master:"
        echo "  kubeadm token create --print-join-command"
        echo ""
        echo "Then run it here with sudo"
    fi
else
    echo "⚠ $ISSUES issue(s) still exist"
    echo ""
    echo "Check logs:"
    echo "  sudo journalctl -u kubelet -f"
    echo "  sudo journalctl -u containerd -f"
    echo ""
    echo "Run diagnostic again:"
    echo "  bash ~/spring-petclinic-microservices/kubernetes/scripts/diagnose-k8s-worker.sh"
fi

echo ""
echo "=========================================="
