#!/bin/bash
# Install Java 21 and Ansible on Amazon Linux

set -e

# Sleep for 60 seconds as requested to ensure instance is fully ready
echo "Sleeping for 60 seconds..."
sleep 60

# Hostname
sudo hostnamectl set-hostname worker-node

# Sleep for 60 seconds as requested to ensure instance is fully ready
echo "Sleeping for 60 seconds..."
sleep 60

# Update packages
echo "Updating packages..."
sudo dnf update -y

# 1. Install Java 21 (Amazon Corretto)
echo "Installing Java 21..."
sudo dnf install fontconfig java-21-amazon-corretto-devel -y

# 2. Install Tools (Git, Docker, Python3/Pip, jq)
echo "Installing tools..."
sudo dnf install git docker python3 python3-pip unzip jq -y

# 3. Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# 4. Configure Docker
echo "Configuring Docker..."
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# 5. Install Ansible (via pip)
sudo pip3 install ansible

echo "Worker Node installation complete!"
java -version
docker --version
ansible --version
aws --version
