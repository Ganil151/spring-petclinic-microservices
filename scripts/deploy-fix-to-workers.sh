#!/bin/bash
# Deploy connectivity fix to all K8s nodes

KEY="~/.ssh/master_keys.pem"

echo "=== Deploying fix to K8s nodes ==="

# Worker 1
echo "Fixing K8s-Primary (54.224.7.121)..."
ssh -i $KEY -o StrictHostKeyChecking=no ec2-user@54.224.7.121 'sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo iptables -F; sudo iptables -A INPUT -s 10.0.1.0/24 -j ACCEPT; sudo systemctl restart kubelet'

# Worker 2
echo "Fixing K8s-Secondary (3.208.26.252)..."
ssh -i $KEY -o StrictHostKeyChecking=no ec2-user@3.208.26.252 'sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo iptables -F; sudo iptables -A INPUT -s 10.0.1.0/24 -j ACCEPT; sudo systemctl restart kubelet'

# Master
echo "Fixing K8s-Master (54.237.211.185)..."
ssh -i $KEY -o StrictHostKeyChecking=no ec2-user@54.237.211.185 'sudo systemctl stop firewalld; sudo systemctl disable firewalld; sudo iptables -F; sudo iptables -A INPUT -s 10.0.1.0/24 -j ACCEPT'

echo "=== Testing connectivity ==="
ssh -i $KEY ec2-user@54.237.211.185 'ping -c 2 10.0.1.232; ping -c 2 10.0.1.142'

echo "=== Done ==="
