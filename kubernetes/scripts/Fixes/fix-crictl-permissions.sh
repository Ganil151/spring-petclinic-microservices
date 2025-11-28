#!/bin/bash

# Script to fix crictl permissions and configuration
# This allows running crictl without sudo

set -e

echo "=== Fixing crictl configuration and permissions ==="

# 1. Create crictl configuration file
echo "Creating /etc/crictl.yaml configuration..."
sudo tee /etc/crictl.yaml > /dev/null <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

echo "✓ crictl configuration created"

# 2. Fix containerd socket permissions
# Option A: Make socket readable by all users (easier but less secure)
echo "Fixing containerd socket permissions..."
sudo chmod 666 /run/containerd/containerd.sock

echo "✓ Permissions fixed"

# 3. Verify crictl works
echo ""
echo "Verifying crictl access..."
if crictl version &> /dev/null; then
    echo "✓ crictl is working properly!"
    echo ""
    echo "Testing crictl commands:"
    echo "------------------------"
    crictl version
    echo ""
    echo "Container runtime info:"
    crictl info | head -20
else
    echo "⚠ crictl still has issues. Trying alternate approach..."
    
    # Option B: Restart containerd to ensure socket has correct permissions
    sudo systemctl restart containerd
    sleep 3
    sudo chmod 666 /run/containerd/containerd.sock
    
    if crictl version &> /dev/null; then
        echo "✓ crictl is now working!"
    else
        echo "❌ Still having issues. You may need to run crictl with sudo."
    fi
fi

echo ""
echo "=== Fix complete! ==="
echo ""
echo "You can now run commands like:"
echo "  crictl ps       # List running containers"
echo "  crictl pods     # List running pods"
echo "  crictl images   # List images"
echo "  crictl stats    # Container statistics"
