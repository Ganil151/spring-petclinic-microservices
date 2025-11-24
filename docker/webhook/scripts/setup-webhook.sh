#!/bin/bash

# Automated Docker Webhook Setup Script
# Run this on the Kubernetes Master node

set -e

echo "=== Docker Webhook Receiver Setup ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Step 1: Copy webhook receiver to /root
echo "Step 1: Installing webhook receiver..."
if [ -f "webhook-receiver.py" ]; then
    cp webhook-receiver.py /root/
    chmod +x /root/webhook-receiver.py
    echo "✓ Webhook receiver installed to /root/"
else
    echo "✗ Error: webhook-receiver.py not found in current directory"
    exit 1
fi

# Step 2: Install systemd service
echo ""
echo "Step 2: Installing systemd service..."
if [ -f "docker-webhook.service" ]; then
    cp docker-webhook.service /etc/systemd/system/
    systemctl daemon-reload
    echo "✓ Systemd service installed"
else
    echo "✗ Error: docker-webhook.service not found"
    exit 1
fi

# Step 3: Create log directory
echo ""
echo "Step 3: Setting up logging..."
touch /var/log/docker-webhook.log
chmod 644 /var/log/docker-webhook.log
echo "✓ Log file created at /var/log/docker-webhook.log"

# Step 4: Open firewall port (if firewalld is running)
echo ""
echo "Step 4: Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=9000/tcp
    firewall-cmd --reload
    echo "✓ Firewall configured (port 9000 opened)"
else
    echo "⚠ Firewalld not running, skipping firewall configuration"
fi

# Step 5: Start the service
echo ""
echo "Step 5: Starting webhook receiver service..."
systemctl enable docker-webhook
systemctl start docker-webhook

# Wait a moment for service to start
sleep 2

# Check if service is running
if systemctl is-active --quiet docker-webhook; then
    echo "✓ Webhook receiver service started successfully"
else
    echo "✗ Error: Service failed to start"
    systemctl status docker-webhook
    exit 1
fi

# Step 6: Display status and next steps
echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Service Status:"
systemctl status docker-webhook --no-pager | head -10
echo ""

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me)
echo "Your webhook URL: http://$PUBLIC_IP:9000"
echo ""

echo "Next Steps:"
echo "1. Configure AWS Security Group to allow inbound traffic on port 9000"
echo "2. Add webhooks to your Docker Hub repositories with URL: http://$PUBLIC_IP:9000"
echo "3. Test the webhook with: curl -X POST http://localhost:9000"
echo ""
echo "To view logs: sudo journalctl -u docker-webhook -f"
echo "To restart service: sudo systemctl restart docker-webhook"
echo "To stop service: sudo systemctl stop docker-webhook"
