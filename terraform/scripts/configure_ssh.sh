#!/bin/bash
set -e

# Configuration
PEM_FILE="../environments/dev/spms-dev.pem"
AWS_REGION="us-east-1"
NODE_IPS_FILE="/tmp/node_ips.txt"

# Ensure PEM file exists and has correct permissions locally
if [ ! -f "$PEM_FILE" ]; then
    echo "Error: Private key file not found at $PEM_FILE"
    exit 1
fi
chmod 400 "$PEM_FILE"

# 1. Get Jenkins Master IP
echo "Retrieving Jenkins Master IP..."
MASTER_IP=$(aws ec2 describe-instances \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=jenkins-master" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

if [ "$MASTER_IP" == "None" ] || [ -z "$MASTER_IP" ]; then
    echo "Error: Jenkins Master not found or not running."
    exit 1
fi
echo "Jenkins Master IP: $MASTER_IP"

# 2. Get Worker Node IPs
# Note: In EKS, nodes might not have a specific Name tag unless we tagged the ASG. 
# We'll try to find them by the tag 'kubernetes.io/cluster/<cluster-name>' or checking the ASG.
# For now, relying on the user following the checklist to generate /tmp/node_ips.txt via kubectl is safer if AWS tags are ambiguous.
# However, let's try to populate it if it doesn't exist.
if [ ! -s "$NODE_IPS_FILE" ]; then
    echo "Attempting to retrieve Worker IPs via AWS CLI (Tag: role=worker)..."
    aws ec2 describe-instances \
        --region $AWS_REGION \
        --filters "Name=tag:Name,Values=*node-group*" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].PublicIpAddress" \
        --output text | tr '\t' '\n' > "$NODE_IPS_FILE"
fi

if [ ! -s "$NODE_IPS_FILE" ]; then
    echo "Warning: No worker IPs found. Ensure EKS nodes are running or /tmp/node_ips.txt is populated."
else
    echo "Worker IPs found: $(cat $NODE_IPS_FILE | tr '\n' ' ')"
fi

# 3. Clean up existing keys in local known_hosts
echo "Removing existing keys for Master from local known_hosts..."
ssh-keygen -R $MASTER_IP 2>/dev/null || true

# 4. Add Master to local known_hosts
echo "Adding Master to local known_hosts..."
ssh-keyscan -H $MASTER_IP >> ~/.ssh/known_hosts 2>/dev/null

# 5. Copy Private Key to Master
echo "Copying private key to Jenkins Master..."
scp -i "$PEM_FILE" "$PEM_FILE" ec2-user@$MASTER_IP:/home/ec2-user/.ssh/id_rsa

# 6. Set Key Permissions on Master
echo "Setting permissions on Master..."
ssh -i "$PEM_FILE" ec2-user@$MASTER_IP "chmod 600 /home/ec2-user/.ssh/id_rsa"

# 7. Configure Master to Trust Workers
if [ -s "$NODE_IPS_FILE" ]; then
    echo "Configuring Master to trust Workers..."
    
    # Copy IP list to master
    scp -i "$PEM_FILE" "$NODE_IPS_FILE" ec2-user@$MASTER_IP:/tmp/node_ips.txt

    # Execute remote scan
    ssh -i "$PEM_FILE" ec2-user@$MASTER_IP "bash -s" << 'EOF'
        # Remove workers from known_hosts
        for IP in $(cat /tmp/node_ips.txt); do
            ssh-keygen -R $IP 2>/dev/null || true
        done
        
        # Add workers to known_hosts
        for IP in $(cat /tmp/node_ips.txt); do
            ssh-keyscan -H $IP >> ~/.ssh/known_hosts 2>/dev/null
        done
EOF
    
    # 8. Test Connectivity (first node)
    FIRST_WORKER=$(head -n 1 "$NODE_IPS_FILE")
    echo "Testing connectivity to first worker: $FIRST_WORKER"
    ssh -i "$PEM_FILE" ec2-user@$MASTER_IP "ssh -o BatchMode=yes -o StrictHostKeyChecking=no ec2-user@$FIRST_WORKER 'echo \"SSH Connection Success: \$(hostname)\"'"
fi

echo "SSH Configuration script completed successfully."
