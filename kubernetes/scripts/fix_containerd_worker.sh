#!/bin/bash

# Fix containerd runtime issues on Kubernetes worker nodes
# Run this script on EACH worker node

set -e

echo "=== Fixing Containerd Runtime on Worker Node ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# 1. Restart containerd
echo "[Step 1] Restarting containerd..."
systemctl restart containerd
systemctl enable containerd
echo "Containerd restarted"

# 2. Verify containerd is running
echo "[Step 2] Checking containerd status..."
if systemctl is-active --quiet containerd; then
    echo "✓ Containerd is running"
else
    echo "✗ Containerd is NOT running!"
    systemctl status containerd
    exit 1
fi

# 3. Check socket permissions
echo "[Step 3] Checking socket permissions..."
ls -la /run/containerd/containerd.sock

# 4. Fix socket permissions if needed
echo "[Step 4] Setting socket permissions..."
chmod 666 /run/containerd/containerd.sock || true
echo "Socket permissions updated"

# 5. Restart kubelet
echo "[Step 5] Restarting kubelet..."
systemctl restart kubelet
systemctl enable kubelet
echo "Kubelet restarted"

# 6. Wait for kubelet to be ready
echo "[Step 6] Waiting for kubelet to be ready..."
sleep 5

# 7. Check kubelet status
echo "[Step 7] Checking kubelet status..."
if systemctl is-active --quiet kubelet; then
    echo "✓ Kubelet is running"
else
    echo "⚠ Kubelet status:"
    systemctl status kubelet --no-pager -l
fi

# 8. Test crictl
echo "[Step 8] Testing crictl connection..."
crictl ps 2>/dev/null && echo "✓ Crictl works" || echo "⚠ Crictl might need sudo"

echo ""
echo "=== Fix Complete ==="
echo "Check node status from master with: kubectl get nodes"
echo "Check pod status with: kubectl get pods -o wide"
