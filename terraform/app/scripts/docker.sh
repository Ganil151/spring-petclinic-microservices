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

# Update system packages
echo "=== Updating system packages ==="
sudo yum update -y

# Install YQ for YAML processing
echo "=== Installing YQ ==="
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    sudo wget https://github.com/mikefarah/yq/releases/download/v4.34.1/yq_linux_amd64 -O /usr/local/bin/yq
    sudo chmod +x /usr/local/bin/yq
fi

# Ensure Docker is installed (optional, as it's a prerequisite)
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Define the Docker plugins directory (using the standard user directory)
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
PLUGINS_DIR="$DOCKER_CONFIG/cli-plugins"

# Create the plugins directory if it doesn't exist
echo "=== Creating Docker CLI plugins directory ==="
mkdir -p $PLUGINS_DIR

# Download the Docker Compose binary for Linux (x86_64)
COMPOSE_VERSION="v2.40.1" # You can update this to the latest version if needed
echo "=== Downloading Docker Compose binary ==="
curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
     -o "$PLUGINS_DIR/docker-compose"

# Make the binary executable
echo "=== Making Docker Compose binary executable ==="
chmod +x "$PLUGINS_DIR/docker-compose"

# Verify the installation
echo "=== Verifying Docker Compose installation ==="
if docker compose version; then
    echo "=== Docker Compose has been successfully installed! ==="
else
    echo "=== Error: Docker Compose verification failed. ==="
    exit 1
fi

echo '=== Verify Docker & Compose ==='
docker --version || { echo 'Docker not working'; exit 1; }
docker compose version || { echo 'Docker Compose V2 not working or not found in expected location'; exit 1; }

# Add the current user to the docker group
echo "Adding the current user to the docker group..."

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
