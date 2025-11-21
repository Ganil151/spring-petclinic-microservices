#!/bin/bash

set -e

echo "=== Fixing K8s Worker Connectivity Issues ==="
echo ""

# Get master IP from join command
if [ -f "k8s_join_command.sh" ]; then
    MASTER_IP=$(grep -oP 'https://\K[^:]+' k8s_join_command.sh | head -1)
    echo "Detected Master IP: $MASTER_IP"
else
    read -p "Enter Master IP address: " MASTER_IP
fi

echo ""
echo "Step 1: Opening required ports on worker firewall..."
if command -v firewall-cmd &> /dev/null; then
    if sudo firewall-cmd --state &> /dev/null; then
        echo "Configuring firewalld..."
        # Worker node required ports
        sudo firewall-cmd --permanent --add-port=10250/tcp  # Kubelet API
        sudo firewall-cmd --permanent --add-port=30000-32767/tcp  # NodePort Services
        sudo firewall-cmd --reload
        echo "✓ Firewall rules updated"
    else
        echo "Firewalld is not running, skipping..."
    fi
else
    echo "Firewalld not installed, skipping..."
fi

echo ""
echo "Step 2: Ensuring kubelet and containerd are running..."
sudo systemctl enable containerd
sudo systemctl restart containerd
sudo systemctl enable kubelet
sudo systemctl restart kubelet
echo "✓ Services restarted"

echo ""
echo "Step 3: Testing connectivity to master API server..."
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$MASTER_IP/6443" 2>/dev/null; then
    echo "✓ Can reach API server on $MASTER_IP:6443"
else
    echo "✗ Cannot reach API server on $MASTER_IP:6443"
    echo ""
    echo "IMPORTANT: You need to configure the MASTER node!"
    echo ""
    echo "Run these commands on the MASTER node ($MASTER_IP):"
    echo ""
    echo "# 1. Check if kubelet is running"
    echo "sudo systemctl status kubelet"
    echo ""
    echo "# 2. Open firewall ports (if using firewalld)"
    echo "sudo firewall-cmd --permanent --add-port=6443/tcp"
    echo "sudo firewall-cmd --permanent --add-port=2379-2380/tcp"
    echo "sudo firewall-cmd --permanent --add-port=10250-10252/tcp"
    echo "sudo firewall-cmd --reload"
    echo ""
    echo "# 3. If using AWS/Cloud, update Security Groups:"
    echo "#    - Master SG: Allow inbound TCP 6443 from Worker IP/SG"
    echo "#    - Master SG: Allow inbound TCP 10250 from Worker IP/SG"
    echo "#    - Worker SG: Allow all outbound traffic"
    echo ""
    exit 1
fi

echo ""
echo "Step 4: Checking if master hostname needs to be added to /etc/hosts..."
MASTER_HOSTNAME=$(grep -oP 'https://\K[^:]+' k8s_join_command.sh | head -1)
if [ "$MASTER_HOSTNAME" != "$MASTER_IP" ]; then
    # It's a hostname, not an IP
    if ! grep -q "$MASTER_HOSTNAME" /etc/hosts; then
        echo "Adding $MASTER_IP $MASTER_HOSTNAME to /etc/hosts..."
        echo "$MASTER_IP $MASTER_HOSTNAME" | sudo tee -a /etc/hosts
        echo "✓ Master hostname added to /etc/hosts"
    else
        echo "✓ Master hostname already in /etc/hosts"
    fi
fi

echo ""
echo "=== Fix Complete ==="
echo "You can now try running the join command again:"
echo "  sudo bash k8s_join_command.sh"
