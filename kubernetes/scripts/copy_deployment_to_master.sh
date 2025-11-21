#!/bin/bash

set -e

echo "=== Copying Kubernetes Deployment Files to Master Server ==="
echo ""

# Configuration
KEY_FILE="terraform/app/master_keys.pem"
DEPLOYMENT_DIR="kubernetes/deployment"
MASTER_USER="ec2-user"

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "✗ Error: SSH key file not found: $KEY_FILE"
    exit 1
fi

# Check if deployment directory exists
if [ ! -d "$DEPLOYMENT_DIR" ]; then
    echo "✗ Error: Deployment directory not found: $DEPLOYMENT_DIR"
    exit 1
fi

# Get master server IP/hostname
if [ -z "$1" ]; then
    echo "Usage: $0 <K8s-Master-Server-IP>"
    echo ""
    echo "Example:"
    echo "  $0 98.82.165.39"
    echo "  $0 ec2-xx-xx-xx-xx.compute.amazonaws.com"
    exit 1
fi

MASTER_SERVER="$1"

echo "Master Server: $MASTER_SERVER"
echo "SSH Key: $KEY_FILE"
echo "Source Directory: $DEPLOYMENT_DIR"
echo ""

# Set correct permissions on key file
echo "Setting correct permissions on SSH key..."
chmod 400 "$KEY_FILE"

# Copy deployment files to master
echo "Copying deployment files to master server..."
scp -r -i "$KEY_FILE" -o StrictHostKeyChecking=no "$DEPLOYMENT_DIR" "${MASTER_USER}@${MASTER_SERVER}:~/"

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Deployment files copied successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. SSH to master: ssh -i $KEY_FILE ${MASTER_USER}@${MASTER_SERVER}"
    echo "  2. Apply deployments: kubectl apply -f ~/deployment/"
else
    echo ""
    echo "✗ Failed to copy deployment files"
    exit 1
fi
