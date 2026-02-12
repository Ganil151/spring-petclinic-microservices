#!/bin/bash
# Install Java 21 and Ansible on Amazon Linux

set -e

# Sleep for 60 seconds as requested to ensure instance is fully ready
echo "Sleeping for 60 seconds..."
sleep 60

# Update system packages
echo "Updating system packages..."
sudo yum update -y

# 1. Install Java 21 (Amazon Corretto)
echo "Installing Java 21..."
# Check for dnf (AL2023) or fallback to yum
if command -v dnf &> /dev/null; then
    sudo dnf install java-21-amazon-corretto-headless -y
else
    # AL2 fallback or direct install
    sudo yum install java-21-amazon-corretto-headless -y || sudo yum install java-21-openjdk-headless -y
fi

# Verify Java
java -version

# 2. Install Ansible
echo "Installing Ansible..."
# Ensure pip is installed
sudo yum install python3-pip -y

# Install Ansible via pip to get a reasonably recent version
sudo pip3 install ansible

# Verify Ansible
ansible --version

echo "Worker node installation complete!"
