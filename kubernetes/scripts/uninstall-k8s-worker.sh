#!/bin/bash

#############################################
# Complete K8s Worker Uninstall Script
# Removes all Kubernetes components
#############################################

set -e

echo "=========================================="
echo "Kubernetes Worker Complete Uninstall"
echo "=========================================="
echo ""
date
echo ""

echo "⚠️  WARNING: This will completely remove Kubernetes from this worker node!"
echo "⚠️  All pods and data on this node will be lost!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
echo "Starting uninstall in 5 seconds... (Ctrl+C to cancel)"
sleep 5

# Step 1: Reset kubeadm (this will drain the node if possible)
echo ""
echo "=== Step 1: Resetting kubeadm ==="
sudo kubeadm reset -f

# Step 2: Stop and disable services
echo ""
echo "=== Step 2: Stopping Kubernetes services ==="
sudo systemctl stop kubelet 2>/dev/null || true
sudo systemctl stop docker 2>/dev/null || true
sudo systemctl disable kubelet 2>/dev/null || true

# Step 3: Remove Kubernetes packages
echo ""
echo "=== Step 3: Removing Kubernetes packages ==="
sudo dnf remove -y kubelet kubeadm kubectl kubernetes-cni 2>/dev/null || true
sudo yum remove -y kubelet kubeadm kubectl kubernetes-cni 2>/dev/null || true

# Step 4: Remove configuration files and directories
echo ""
echo "=== Step 4: Removing configuration files ==="
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/kubelet/
sudo rm -rf /etc/cni/
sudo rm -rf /opt/cni/
sudo rm -rf /var/lib/cni/
sudo rm -rf /run/flannel/
sudo rm -rf /etc/systemd/system/kubelet.service.d/
sudo rm -rf ~/.kube/

# Step 5: Remove iptables rules
echo ""
echo "=== Step 5: Cleaning up iptables rules ==="
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X

# Step 6: Remove network interfaces
echo ""
echo "=== Step 6: Removing network interfaces ==="
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true
sudo ip link delete kube-bridge 2>/dev/null || true
sudo ip link delete weave 2>/dev/null || true
sudo ip link delete datapath 2>/dev/null || true

# Step 7: Remove Calico components
echo ""
echo "=== Step 7: Removing Calico components ==="
sudo systemctl stop calico-node 2>/dev/null || true
sudo systemctl disable calico-node 2>/dev/null || true
sudo rm -rf /var/lib/calico/
sudo rm -rf /etc/calico/
sudo rm -rf /opt/calico/
sudo ip link delete tunl0 2>/dev/null || true
sudo ip link delete vxlan.calico 2>/dev/null || true

# Step 8: Remove systemd files
echo ""
echo "=== Step 8: Removing systemd files ==="
sudo rm -f /etc/systemd/system/kubelet.service
sudo rm -f /usr/lib/systemd/system/kubelet.service
sudo systemctl daemon-reload

# Step 9: Remove Kubernetes repository
echo ""
echo "=== Step 9: Removing Kubernetes repository ==="
sudo rm -f /etc/yum.repos.d/kubernetes.repo

# Step 10: Clean up Docker (optional)
echo ""
echo "=== Step 10: Cleaning Docker containers and images ==="
read -p "Do you want to remove all Docker containers and images? (yes/no): " CLEAN_DOCKER

if [ "$CLEAN_DOCKER" = "yes" ]; then
    sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
    sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
    sudo docker rmi $(sudo docker images -q) 2>/dev/null || true
    sudo docker system prune -af --volumes
    echo "✓ Docker cleaned"
else
    echo "Skipping Docker cleanup"
fi

# Step 11: Remove kernel modules
echo ""
echo "=== Step 11: Removing kernel modules ==="
sudo modprobe -r br_netfilter 2>/dev/null || true
sudo modprobe -r overlay 2>/dev/null || true

# Step 12: Clean up sysctl settings
echo ""
echo "=== Step 12: Cleaning sysctl settings ==="
sudo rm -f /etc/sysctl.d/k8s.conf
sudo sysctl --system

# Step 13: Verify cleanup
echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="
echo ""

echo "Checking for remaining Kubernetes processes:"
ps aux | grep -E 'kube' | grep -v grep || echo "✓ No Kubernetes processes found"

echo ""
echo "Checking for remaining Kubernetes files:"
sudo find / -name "*kube*" 2>/dev/null | head -20 || echo "✓ No major Kubernetes files found"

echo ""
echo "Checking network interfaces:"
ip link show | grep -E 'cni|flannel|calico|kube|weave' || echo "✓ No Kubernetes network interfaces found"

echo ""
echo "=========================================="
echo "Kubernetes Worker Uninstall Complete!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Kubernetes packages removed"
echo "  ✓ Configuration files deleted"
echo "  ✓ Network interfaces cleaned"
echo "  ✓ iptables rules flushed"
echo "  ✓ System ready for fresh installation"
echo ""
echo "Next steps:"
echo "  1. Reboot the server (recommended): sudo reboot"
echo "  2. This server can now be used as a K3s agent or standalone server"
echo ""
echo "=========================================="
