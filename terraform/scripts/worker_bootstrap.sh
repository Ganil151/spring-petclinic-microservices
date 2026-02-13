#!/bin/bash
# Enhanced Worker Node Setup for Spring Petclinic Microservices
# Target OS: Amazon Linux 2023 / AL2
set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname worker-node
echo "Waiting 60s for instance to stabilize..."
sleep 60

# 2. Repository & System Updates
echo "Updating system packages..."
sudo dnf update -y
# Install core dependencies in one batch for speed
sudo dnf install -y git docker python3 python3-pip unzip jq fontconfig java-21-amazon-corretto-devel maven

# 3. AWS CLI v2 Installation
echo "Installing/Updating AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

# 4. Kubernetes Tooling (Kubectl & Helm)
echo "Installing Kubernetes Tools..."
# Install latest stable Kubectl
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Helm
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 5. Configuration & Permissions
echo "Configuring Docker and User Groups..."
sudo systemctl enable --now docker
# Allow ec2-user to run docker without sudo
sudo usermod -aG docker ec2-user
# Ensure the SSH directory is ready for the Jenkins Master connection
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# 6. DevOps Tooling (Ansible)
echo "Installing Ansible..."
sudo pip3 install --upgrade pip
sudo pip3 install ansible

# 7. Final Verification
echo "------------------------------------------------"
echo "✅ Worker Node Setup Complete!"
echo "------------------------------------------------"
printf "Java:    %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Maven:   %s\n" "$(mvn -version | head -n 1)"
printf "Docker:  %s\n" "$(docker --version)"
printf "Kubectl: %s\n" "$(kubectl version --client --output=yaml | grep gitVersion | head -n 1)"
printf "Helm:    %s\n" "$(helm version --short)"
printf "Ansible: %s\n" "$(ansible --version | head -n 1)"
echo "------------------------------------------------"