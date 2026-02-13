#!/bin/bash
set -e

# ==============================================================================
# CONFIGURATION (Update these variables)
# ==============================================================================
PEM_FILE="../environments/dev/spms-dev.pem"
AWS_REGION="us-east-1"
NODE_IPS_FILE="/tmp/node_ips.txt"
REMOTE_USER="ec2-user"

# ==============================================================================
# PHASE 1: LOCAL PREPARATION & DISCOVERY
# ==============================================================================

# Ensure PEM file exists and has correct permissions
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

# 2. Get Worker Node IPs (for SSH Trust later)
if [ ! -s "$NODE_IPS_FILE" ]; then
    echo "Attempting to retrieve Worker IPs via AWS CLI..."
    aws ec2 describe-instances \
        --region $AWS_REGION \
        --filters "Name=tag:Name,Values=*node-group*" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].PublicIpAddress" \
        --output text | tr '\t' '\n' > "$NODE_IPS_FILE"
fi

# 3. Handle SSH Known Hosts locally
sudo ssh-keygen -R "$MASTER_IP" 2>/dev/null || true
sudo ssh-keyscan -H "$MASTER_IP" >> ~/.ssh/known_hosts 2>/dev/null

# 4. Copy Private Key to Master (for Master -> Worker communication)
echo "Copying private key to Jenkins Master..."
sudo scp -i "$PEM_FILE" "$PEM_FILE" ${REMOTE_USER}@${MASTER_IP}:/home/${REMOTE_USER}/.ssh/id_rsa

# 5. Copy Worker IP list to Master
if [ -s "$NODE_IPS_FILE" ]; then
    scp -i "$PEM_FILE" "$NODE_IPS_FILE" ${REMOTE_USER}@${MASTER_IP}:/tmp/node_ips.txt
fi

# ==============================================================================
# PHASE 2: REMOTE INSTALLATION ON JENKINS MASTER
# ==============================================================================
echo "Starting Remote Installation on Master..."

sudo ssh -i "$PEM_FILE" ${REMOTE_USER}@${MASTER_IP} "bash -s" << 'REMOTEEF'
    set -e
    
    # 1. System Hostname & Prep
    sudo hostnamectl set-hostname jenkins-master
    sudo chmod 600 /home/ec2-user/.ssh/id_rsa
    
    echo "Updating system packages..."
    sudo dnf update -y
    sudo dnf install fontconfig java-21-amazon-corretto-devel wget git docker python3 python3-pip unzip jq -y

    # 2. Install Jenkins
    echo "Installing Jenkins..."
    sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    sudo dnf install jenkins -y

    # 3. Install Tools (AWS CLI, Kubectl)
    echo "Installing DevOps Tools..."

    # AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install && rm -rf aws awscliv2.zip

    # Kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

    # 4. Configure Services & Permissions
    echo "Configuring permissions and starting services..."
    sudo systemctl enable --now docker
    sudo usermod -aG docker ${REMOTE_USER}
    sudo usermod -aG docker ${REMOTE_USER}
    sudo systemctl restart docker

    sudo systemctl enable --now jenkins

    # 5. Install Jenkins Plugins
    echo "Installing Jenkins Plugins..."
    sudo mkdir -p /var/lib/jenkins/plugins
    sudo chown -R ${REMOTE_USER}:${REMOTE_USER} /var/lib/jenkins
    
    # Install plugin CLI if not present, then install plugins
    # Note: Plugins might take a moment to be available for the CLI
    sudo -u ${REMOTE_USER} jenkins-plugin-cli --plugins \
        workflow-aggregator git github-branch-source docker-workflow sonar \
        maven-plugin eclipse-temurin-installer credentials-binding \
        dependency-check-jenkins-plugin aws-credentials pipeline-utility-steps

    # 6. Configure SSH Trust for Workers
    if [ -f "/tmp/node_ips.txt" ]; then
        echo "Configuring SSH trust for Workers..."
        for IP in $(cat /tmp/node_ips.txt); do
            ssh-keygen -R $IP 2>/dev/null || true
            ssh-keyscan -H $IP >> ~/.ssh/known_hosts 2>/dev/null
        done
    fi

    echo "Remote installation complete!"
    echo "Versions:"
    java -version 2>&1 | head -n 1
    jenkins --version
REMOTEEF

# ==============================================================================
# PHASE 3: FINAL CONNECTIVITY TEST
# ==============================================================================
if [ -s "$NODE_IPS_FILE" ]; then
    FIRST_WORKER=$(head -n 1 "$NODE_IPS_FILE")
    echo "Testing Master -> Worker connectivity via: $FIRST_WORKER"
    sudo ssh -i "$PEM_FILE" ${REMOTE_USER}@${MASTER_IP} "ssh -o BatchMode=yes -o StrictHostKeyChecking=no ${REMOTE_USER}@${FIRST_WORKER} 'echo SSH Connection Success from Master to: \$(hostname)'"
fi

echo "Full automation script completed successfully."