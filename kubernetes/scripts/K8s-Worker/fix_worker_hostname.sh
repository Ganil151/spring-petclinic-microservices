#!/bin/bash

set -e

echo "=== Fixing K8s Worker Hostname Resolution ==="

# Get the current hostname
CURRENT_HOSTNAME=$(hostname)
echo "Current hostname: $CURRENT_HOSTNAME"

# Get the primary IP address (excluding loopback)
PRIMARY_IP=$(hostname -I | awk '{print $1}')
echo "Primary IP address: $PRIMARY_IP"

# Backup /etc/hosts
echo "Backing up /etc/hosts..."
sudo cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)

# Remove any existing entries for this hostname
echo "Removing old hostname entries..."
sudo sed -i "/$CURRENT_HOSTNAME/d" /etc/hosts

# Add the hostname entry to /etc/hosts
echo "Adding hostname entry to /etc/hosts..."
echo "$PRIMARY_IP $CURRENT_HOSTNAME" | sudo tee -a /etc/hosts

# Also add localhost entries if missing
if ! grep -q "127.0.0.1.*localhost" /etc/hosts; then
    echo "127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4" | sudo tee -a /etc/hosts
fi

if ! grep -q "::1.*localhost" /etc/hosts; then
    echo "::1 localhost localhost.localdomain localhost6 localhost6.localdomain6" | sudo tee -a /etc/hosts
fi

echo ""
echo "=== Updated /etc/hosts ==="
cat /etc/hosts

echo ""
echo "=== Testing hostname resolution ==="
if ping -c 2 $CURRENT_HOSTNAME &> /dev/null; then
    echo "✓ Hostname $CURRENT_HOSTNAME is now resolvable"
else
    echo "⚠ Warning: Hostname resolution test failed, but /etc/hosts has been updated"
fi

echo ""
echo "=== Hostname fix complete ==="
echo "You can now re-run the kubeadm join command"
