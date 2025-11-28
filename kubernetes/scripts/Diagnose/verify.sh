#!/bin/bash
set -e

echo "=== Kubernetes Installation Verification ==="

# 1. Verify containerd installed and running
echo "[1/7] Checking containerd..."
if systemctl is-active --quiet containerd; then
    echo "✔ containerd is running"
else
    echo "✘ containerd NOT running"
    exit 1
fi

# 2. Verify kubelet installed and enabled
echo "[2/7] Checking kubelet installation..."
if command -v kubelet >/dev/null 2>&1; then
    echo "✔ kubelet installed"
else
    echo "✘ kubelet NOT installed"
    exit 1
fi

echo "[3/7] Checking kubelet service..."
if systemctl is-enabled --quiet kubelet; then
    echo "✔ kubelet enabled"
else
    echo "✘ kubelet NOT enabled"
    exit 1
fi

# 4. Check kubeadm
echo "[4/7] Checking kubeadm..."
if command -v kubeadm >/dev/null 2>&1; then
    echo "✔ kubeadm installed"
else
    echo "✘ kubeadm NOT installed"
    exit 1
fi

# 5. Check kubectl
echo "[5/7] Checking kubectl..."
if command -v kubectl >/dev/null 2>&1; then
    echo "✔ kubectl installed"
else
    echo "✘ kubectl NOT installed"
    exit 1
fi

# 6. Validate kubelet is not crashlooping
echo "[6/7] Validating kubelet status..."
if systemctl is-active --quiet kubelet; then
    echo "✔ kubelet active (normal before/after init)"
else
    echo "✘ kubelet is NOT active — check logs"
    journalctl -u kubelet -n 20
    exit 1
fi

# 7. If this is the master: check cluster init status
echo "[7/7] Checking kubectl config..."
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "✔ Master node detected"
    
    export KUBECONFIG=/etc/kubernetes/admin.conf

    if kubectl get nodes >/dev/null 2>&1; then
        echo "✔ Kubernetes API reachable"
        kubectl get nodes -o wide
    else
        echo "✘ API server not reachable — cluster not initialized?"
    fi
else
    echo "✔ Worker node detected (admin.conf missing)"
    echo "Note: Worker will be validated fully after kubeadm join"
fi

echo "=== Kubernetes verification complete ==="
