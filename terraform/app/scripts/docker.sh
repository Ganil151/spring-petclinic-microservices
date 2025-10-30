#!/bin/bash

set -e

# Change Host Name
echo "Changing Host Name..."
sudo hostnamectl set-hostname "Worker-Server"

# Install dependencies and update system
echo "Installing dependencies and updating system...😎"
sudo yum update -y

# Install Java
echo "Installing Java..."
sudo yum install -y java-21-amazon-corretto-devel git

# Configure Java
echo "Configure Java"
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a ~/.bashrc
echo "export PATH=$PATH:$HOME/bin:$JAVA_HOME" | sudo tee -a ~/.bashrc

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker git

# Install Docker Compose
echo '=== Installing Docker Compose V2 if missing ==='
if ! docker compose version &> /dev/null; then
    echo 'Installing Docker Compose V2...'
    mkdir -p ~/.docker/cli-plugins/
    # Ensure the binary is downloaded to the correct location and is executable
    curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose

    # Optional: Add the directory to PATH if not recognized by default
    # This might be redundant as Docker usually looks in ~/.docker/cli-plugins/
    export PATH=\$PATH:/home/ec2-user/.docker/cli-plugins
    echo 'export PATH=\$PATH:/home/ec2-user/.docker/cli-plugins' >> ~/.bashrc

fi

echo '=== Verify Docker & Compose ==='
docker --version || { echo 'Docker not working'; exit 1; }
docker compose version || { echo 'Docker Compose V2 not working or not found in expected location'; exit 1; }

# Add the current user to the docker group
echo "Adding the current user to the docker group..."
sudo usermod -a -G docker ec2-user

# Configure Docker to start on boot
echo "Configuring Docker to start on boot..."
sudo systemctl enable docker
sudo systemctl start docker

sudo yum update -y

# Increase /tmp file size persistently and remount
echo "Increasing /tmp file size to 1.5GB persistently..."
if ! grep -q "/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
fi

echo "Remounting /tmp with the new size..."
if sudo mount -o remount /tmp; then
    echo "/tmp remounted successfully."
else
    echo "WARNING: Failed to remount /tmp immediately. A reboot is required for the change to take effect."
    exit 0 
fi

echo "Docker installation and configuration complete."
