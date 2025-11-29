#!/bin/bash
# fix_cri_socket.sh
# Fixes the "cri-dockerd.sock" error by pointing kubelet and crictl to containerd
# Run this on ANY node (master or worker) that shows the error

set -e

echo "=== Fixing CRI Socket Configuration ==="

# 1. Configure crictl to use containerd
echo "[Step 1] Configuring /etc/crictl.yaml..."
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
echo "Updated /etc/crictl.yaml"

# 2. Fix kubelet arguments if they point to the wrong socket
echo "[Step 2] Checking kubelet configuration..."
KUBEADM_FLAGS_FILE="/var/lib/kubelet/kubeadm-flags.env"

if [ -f "$KUBEADM_FLAGS_FILE" ]; then
    if grep -q "cri-dockerd.sock" "$KUBEADM_FLAGS_FILE"; then
        echo "Found incorrect socket in $KUBEADM_FLAGS_FILE. Fixing..."
        sudo sed -i 's|unix:///var/run/cri-dockerd.sock|unix:///run/containerd/containerd.sock|g' "$KUBEADM_FLAGS_FILE"
        sudo sed -i 's|unix:///run/cri-dockerd.sock|unix:///run/containerd/containerd.sock|g' "$KUBEADM_FLAGS_FILE"
        echo "Fixed kubelet flags."
    else
        echo "No reference to cri-dockerd.sock found in kubelet flags."
    fi
else
    echo "Warning: $KUBEADM_FLAGS_FILE not found. Skipping flag fix."
fi

# 3. Restart services
echo "[Step 3] Restarting services..."
sudo systemctl daemon-reload
sudo systemctl restart containerd
sudo systemctl restart kubelet

# 4. Verification
echo "[Step 4] Verifying..."
sleep 5
if systemctl is-active --quiet kubelet; then
    echo "✓ Kubelet is running"
else
    echo "✗ Kubelet failed to start. Check logs: journalctl -u kubelet -n 50"
fi

echo "=== Done ==="
