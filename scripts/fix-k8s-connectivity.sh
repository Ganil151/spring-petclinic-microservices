#!/bin/bash
# Fix K8s node connectivity - Run this on EACH node

echo "=== Fixing Node Connectivity ==="

# Stop and disable firewalld
sudo systemctl stop firewalld 2>/dev/null
sudo systemctl disable firewalld 2>/dev/null

# Flush existing iptables rules that might block
sudo iptables -F
sudo iptables -X

# Allow all traffic on K8s subnet
sudo iptables -A INPUT -s 10.0.1.0/24 -j ACCEPT
sudo iptables -A OUTPUT -d 10.0.1.0/24 -j ACCEPT

# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Restart kubelet
sudo systemctl restart kubelet

echo "=== Done - Node configured ==="
