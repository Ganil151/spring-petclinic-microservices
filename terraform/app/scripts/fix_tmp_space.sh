#!/bin/bash

set -e

echo "=== Fixing /tmp Space Issue ==="
echo ""

# Check current /tmp usage
echo "Current /tmp usage:"
df -h /tmp
echo ""

# Clean up old temporary files
echo "Step 1: Cleaning up old temporary files..."
sudo find /tmp -type f -atime +1 -delete 2>/dev/null || true
sudo find /tmp -type d -empty -delete 2>/dev/null || true

echo "After cleanup:"
df -h /tmp
echo ""

# Increase /tmp size persistently
echo "Step 2: Increasing /tmp size to 1.5GB persistently..."
if ! grep -q "/tmp tmpfs" /etc/fstab; then
    echo "Adding tmpfs entry to /etc/fstab..."
    echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
    echo "✓ Added to /etc/fstab"
else
    echo "✓ /tmp tmpfs entry already exists in /etc/fstab"
fi

# Remount /tmp with new size
echo ""
echo "Step 3: Remounting /tmp with new size..."
if sudo mount -o remount /tmp; then
    echo "✓ /tmp remounted successfully"
else
    echo "⚠ Warning: Failed to remount /tmp immediately"
    echo "  The change will take effect after reboot"
    echo "  You can reboot now with: sudo reboot"
fi

echo ""
echo "Final /tmp usage:"
df -h /tmp

echo ""
echo "=== Fix Complete ==="
echo "You can now re-run your Ansible playbook"
