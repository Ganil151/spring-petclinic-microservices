#!/bin/bash

set -e

# Change Host Name
echo "Changing Host Name..."
sudo hostnamectl set-hostname "sonarqube-server"

# Update System Packages
echo "Updating system packages..."
sudo yum update -y

sudo yum install -y java-21-amazon-corretto-devel git

# Configure Java
echo "Configure Java"
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a ~/.bashrc
echo "export PATH=$PATH:$HOME/bin:$JAVA_HOME" | sudo tee -a ~/.bashrc

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker docker-cli docker-compose-plugin
sudo yum update -y

# Start and Enable Docker Service
echo "Starting and enabling Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add the Current User to the Docker Group (Optional)
echo "Adding the current user to the Docker group..."
sudo usermod -aG docker $(whoami)
echo "You must log out and log back in for the group changes to take effect."

# Pull the SonarQube Docker Image
echo "Pulling the SonarQube Docker image..."
sudo docker pull sonarqube:latest

# Create Persistent Storage Directories
echo "Creating persistent storage directories for SonarQube data and plugins..."
sudo mkdir -p /var/sonarqube/data
sudo mkdir -p /var/sonarqube/extensions

# Set Permissions for Persistent Storage
echo "Setting permissions for persistent storage directories..."
sudo chmod -R 755 /var/sonarqube

# Run the SonarQube Docker Container
echo "Running the SonarQube Docker container..."
sudo docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  -p 9001:9001 \
  -v /var/sonarqube/data:/opt/sonarqube/data \
  -v /var/sonarqube/extensions:/opt/sonarqube/extensions \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:latest

# Verify the Container is Running
echo "Verifying the SonarQube container is running..."
if sudo docker ps | grep -q sonarqube; then
    echo "SonarQube container is running successfully."
else
    echo "ERROR: SonarQube container failed to start."
    exit 1
fi

# Increase /tmp File Size Persistently
echo "Increasing /tmp file size to 1.5GB persistently..."
if ! grep -q "/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
fi

echo "Remounting /tmp with the new size..."
if sudo mount -o remount /tmp; then
    echo "/tmp remounted successfully."
else
    echo "WARNING: Failed to remount /tmp immediately. A reboot is required for the change to take effect."
fi

echo "SonarQube Docker container setup complete. Access SonarQube at http://<your-server-ip>:9000"