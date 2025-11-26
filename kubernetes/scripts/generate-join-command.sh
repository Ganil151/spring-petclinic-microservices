#!/bin/bash

#############################################
# Kubernetes Join Command Generator
# Run this on the K8s master node
#############################################

set -e

echo "=========================================="
echo "Kubernetes Join Command Generator"
echo "=========================================="
echo ""

# Check if running on master
if ! command -v kubeadm &> /dev/null; then
    echo "ERROR: kubeadm not found. This script must run on the K8s master node."
    exit 1
fi

# Check if kubectl is configured
if ! kubectl get nodes &> /dev/null; then
    echo "ERROR: kubectl not configured. Make sure you're on the K8s master."
    exit 1
fi

echo "Generating join command..."
echo ""

# Generate new token and join command
JOIN_COMMAND=$(kubeadm token create --print-join-command 2>/dev/null)

if [ -z "$JOIN_COMMAND" ]; then
    echo "ERROR: Failed to generate join command"
    echo "Try running manually: sudo kubeadm token create --print-join-command"
    exit 1
fi

# Get master IP
MASTER_IP=$(hostname -I | awk '{print $1}')

echo "=========================================="
echo "Kubernetes Cluster Join Command"
echo "=========================================="
echo ""
echo "Master Node IP: $MASTER_IP"
echo ""
echo "On each worker node, run this command:"
echo ""
echo "sudo $JOIN_COMMAND"
echo ""
echo "=========================================="
echo ""

# Save to file
cat > ~/k8s-join-command.sh <<EOF
#!/bin/bash
# Kubernetes Join Command
# Generated: $(date)
# Master IP: $MASTER_IP

sudo $JOIN_COMMAND
EOF

chmod +x ~/k8s-join-command.sh

echo "Join command saved to: ~/k8s-join-command.sh"
echo ""
echo "To use on worker:"
echo "  1. Copy the command above"
echo "  2. SSH to worker node"
echo "  3. Paste and run the command"
echo ""
echo "Or copy the script:"
echo "  scp ~/k8s-join-command.sh ec2-user@<worker-ip>:~/"
echo "  ssh ec2-user@<worker-ip> 'bash ~/k8s-join-command.sh'"
echo ""
echo "Verify nodes joined:"
echo "  kubectl get nodes"
echo ""
