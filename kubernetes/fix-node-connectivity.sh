#!/bin/bash
# Fix node connectivity issues

echo "=== Fixing Node Connectivity ==="

# On Master Node - Allow all traffic from worker nodes
echo "1. Configuring firewall on master..."
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.1.0/24" accept' 2>/dev/null || true
sudo firewall-cmd --reload 2>/dev/null || true

# Disable firewalld if causing issues
sudo systemctl stop firewalld 2>/dev/null || true
sudo systemctl disable firewalld 2>/dev/null || true

# Allow all on internal network
sudo iptables -I INPUT -s 10.0.1.0/24 -j ACCEPT
sudo iptables -I OUTPUT -d 10.0.1.0/24 -j ACCEPT

# Test connectivity
echo "2. Testing connectivity to worker nodes..."
ping -c 2 10.0.1.232
ping -c 2 10.0.1.142

echo "=== Done ==="
