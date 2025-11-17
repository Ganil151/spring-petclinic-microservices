#!/bin/bash

set -e

# Change Host Name
NEW_HOSTNAME="Worker-Server"
echo "Changing Host Name ${NEW_HOSTNAME} ..."
sudo hostnamectl set-hostname $NEW_HOSTNAME

# Install dependencies and update system
echo "Installing dependencies and updating system..."
sudo yum update -y

# Install Java
echo "Installing Java..."
sudo yum install -y java-21-amazon-corretto-devel git

# Configure Java
echo "Configure Java"
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a ~/.bashrc
echo "export PATH=$PATH:$HOME/bin:$JAVA_HOME" | sudo tee -a ~/.bashrc

# Install Maven (Already in the dependencies list, but we'll re-verify)
if ! command -v mvn &> /dev/null; then
    echo "Maven is not installed. Installing Maven..."
    sudo yum install -y maven 
fi

JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
# Maven is typically installed to /usr/share/maven on RHEL-based systems
M2_HOME="/usr/share/maven"
# Verify Maven installation path for M2_HOME (best practice)
if [ ! -d "$M2_HOME" ]; then
    echo "WARNING: Could not confirm standard M2_HOME directory ($M2_HOME). Skipping M2_HOME export."
    M2_HOME="" # Clear if not found to prevent exporting an invalid path
fi

# Configure environment variables for the current user's profile
echo "Configuring environment variables (JAVA_HOME, M2_HOME) for current user..."
{
    echo "export JAVA_HOME=${JAVA_HOME}"
    if [ -n "$M2_HOME" ]; then
        echo "export M2_HOME=${M2_HOME}"
    fi
    echo "export PATH=\$PATH:\$HOME/bin:\$JAVA_HOME/bin"
    if [ -n "$M2_HOME" ]; then
        echo "export PATH=\$PATH:\$M2_HOME/bin"
    fi
} | sudo tee -a /etc/profile.d/jenkins_env.sh # Use a profile.d script for system-wide shell configuration

# Make the profile script executable
sudo chmod +x /etc/profile.d/jenkins_env.sh


# Install Docker
echo "Installing Docker..."
sudo yum install -y docker git

# Install Docker Compose
echo '=== Installing Docker Compose V2 if missing ==='
if ! docker compose version &> /dev/null; then
    echo 'Installing Docker Compose V2...'
    sudo mkdir -p /usr/libexec/docker/cli-plugins/
    sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/libexec/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose
    docker compose version
    

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
sudo usermod -a -G docker ${whoami}

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
