#!/bin/bash

set -e

# Change Host Name
NEW_HOSTNAME="Monitor-Server"
echo "Changing Host Name to: ${NEW_HOSTNAME}"
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"

# Install dependencies and update system
echo "Installing dependencies and updating system...😎"
sudo yum update -y

# Install Java
echo "Installing Java..."
sudo yum install -y java-21-amazon-corretto-devel git wget

# Configure Java environment
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "Configuring Java environment variables..."
{
    echo "export JAVA_HOME=${JAVA_HOME}"
    echo "export PATH=\$PATH:\$HOME/bin:\$JAVA_HOME/bin"
} | sudo tee -a /etc/profile.d/