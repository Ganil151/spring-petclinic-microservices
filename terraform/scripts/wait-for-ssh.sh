#!/bin/bash
set -e

INVENTORY_FILE=$1
MAX_RETRIES=30
RETRY_INTERVAL=10

if [ -z "$INVENTORY_FILE" ]; then
  echo "Usage: ./wait-for-ssh.sh <inventory_file>"
  exit 1
fi

echo "🔍 Waiting for SSH to be available on all hosts..."

# Extract IPs from inventory
IPS=$(grep -oP '^\d+\.\d+\.\d+\.\d+' "$INVENTORY_FILE" || echo "")

if [ -z "$IPS" ]; then
  echo "❌ No IPs found in inventory file"
  exit 1
fi

for IP in $IPS; do
  echo "Checking $IP..."
  RETRY=0
  
  while [ $RETRY -lt $MAX_RETRIES ]; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes ec2-user@"$IP" "echo 'SSH Ready'" 2>/dev/null; then
      echo "✅ $IP is ready"
      break
    fi
    
    RETRY=$((RETRY + 1))
    if [ $RETRY -lt $MAX_RETRIES ]; then
      echo "⏳ Attempt $RETRY/$MAX_RETRIES failed, retrying in ${RETRY_INTERVAL}s..."
      sleep $RETRY_INTERVAL
    else
      echo "❌ $IP failed to respond after $MAX_RETRIES attempts"
      exit 1
    fi
  done
done

echo "✅ All hosts are SSH-ready"
