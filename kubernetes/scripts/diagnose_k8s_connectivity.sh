#!/bin/bash

echo "=== Kubernetes Worker-to-Master Connectivity Diagnostics ==="
echo ""

# Extract master IP and port from join command if available
if [ -f "k8s_join_command.sh" ]; then
    echo "Reading join command..."
    MASTER_INFO=$(grep -oP 'https://\K[^:]+:\d+' k8s_join_command.sh || echo "")
    if [ -n "$MASTER_INFO" ]; then
        MASTER_IP=$(echo $MASTER_INFO | cut -d: -f1)
        MASTER_PORT=$(echo $MASTER_INFO | cut -d: -f2)
        echo "Master IP: $MASTER_IP"
        echo "Master Port: $MASTER_PORT"
    else
        echo "⚠ Could not extract master info from k8s_join_command.sh"
        read -p "Enter Master IP address: " MASTER_IP
        MASTER_PORT=6443
    fi
else
    echo "⚠ k8s_join_command.sh not found"
    read -p "Enter Master IP address: " MASTER_IP
    MASTER_PORT=6443
fi

echo ""
echo "=== Test 1: Ping Master Node ==="
if ping -c 3 $MASTER_IP &> /dev/null; then
    echo "✓ Can ping master at $MASTER_IP"
else
    echo "✗ FAILED: Cannot ping master at $MASTER_IP"
    echo "  This indicates a network connectivity issue"
fi

echo ""
echo "=== Test 2: Check API Server Port (6443) ==="
if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$MASTER_IP/$MASTER_PORT" 2>/dev/null; then
    echo "✓ Port $MASTER_PORT is reachable on $MASTER_IP"
else
    echo "✗ FAILED: Cannot connect to port $MASTER_PORT on $MASTER_IP"
    echo "  Possible causes:"
    echo "  - Firewall blocking port $MASTER_PORT"
    echo "  - API server not running on master"
    echo "  - Security group rules blocking traffic"
fi

echo ""
echo "=== Test 3: Check Local Firewall ==="
if command -v firewall-cmd &> /dev/null; then
    echo "Firewall status:"
    sudo firewall-cmd --state || echo "Firewall is not running"
else
    echo "firewalld not installed (this is OK)"
fi

echo ""
echo "=== Test 4: Check Routing ==="
echo "Route to master:"
ip route get $MASTER_IP

echo ""
echo "=== Test 5: DNS Resolution ==="
if [ -f "k8s_join_command.sh" ]; then
    MASTER_HOSTNAME=$(grep -oP 'https://\K[^:]+' k8s_join_command.sh | head -1)
    if [ "$MASTER_HOSTNAME" != "$MASTER_IP" ]; then
        echo "Testing DNS resolution for: $MASTER_HOSTNAME"
        if nslookup $MASTER_HOSTNAME &> /dev/null || host $MASTER_HOSTNAME &> /dev/null; then
            echo "✓ DNS resolution working"
        else
            echo "⚠ DNS resolution failed for $MASTER_HOSTNAME"
            echo "  Consider adding to /etc/hosts: $MASTER_IP $MASTER_HOSTNAME"
        fi
    fi
fi

echo ""
echo "=== Test 6: Check Kubelet Status ==="
sudo systemctl status kubelet --no-pager | head -10

echo ""
echo "=== Test 7: Check Containerd Status ==="
sudo systemctl status containerd --no-pager | head -10

echo ""
echo "=== Recommendations ==="
echo ""
if ! timeout 5 bash -c "cat < /dev/null > /dev/tcp/$MASTER_IP/$MASTER_PORT" 2>/dev/null; then
    echo "⚠ CRITICAL: Cannot reach API server on master node"
    echo ""
    echo "On the MASTER node, run these commands:"
    echo "  1. Check if API server is running:"
    echo "     sudo systemctl status kubelet"
    echo "     kubectl get nodes"
    echo ""
    echo "  2. Check firewall rules (if using firewalld):"
    echo "     sudo firewall-cmd --list-all"
    echo ""
    echo "  3. Open required ports:"
    echo "     sudo firewall-cmd --permanent --add-port=6443/tcp"
    echo "     sudo firewall-cmd --permanent --add-port=2379-2380/tcp"
    echo "     sudo firewall-cmd --permanent --add-port=10250-10252/tcp"
    echo "     sudo firewall-cmd --reload"
    echo ""
    echo "On AWS/Cloud, check Security Group rules:"
    echo "  - Ensure master's security group allows inbound TCP 6443 from worker's IP"
    echo "  - Ensure worker's security group allows outbound to master"
else
    echo "✓ Basic connectivity looks good"
    echo "  If join still fails, check master node logs:"
    echo "    sudo journalctl -u kubelet -n 50"
fi
