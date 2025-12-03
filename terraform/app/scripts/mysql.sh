#!/bin/bash

set -e

# Change Host Name
NEW_HOSTNAME="Mysql-Server"
echo "Changing Host Name to: ${NEW_HOSTNAME}"
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"

# Load Dependencies
echo "Updating system and installing dependencies..."
sudo yum update -y
sudo yum install -y java-21-amazon-corretto-devel wget git

# Configure Java environment
echo "Configuring Java environment variables..."
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
{
    echo "export JAVA_HOME=${JAVA_HOME}"
    echo "export PATH=\$PATH:\$HOME/bin:\$JAVA_HOME/bin"
} | sudo tee -a /etc/profile.d/mysql_env.sh

# Increase /tmp file size persistently and remount
echo "Increasing /tmp file size to 1.5GB persistently..."
if ! grep -q "/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
fi

echo "Remounting /tmp with the new size..."
if sudo mount -o remount /tmp; then
    echo "/tmp remounted successfully with 1.5GB size."
else
    echo "WARNING: Failed to remount /tmp immediately. A system reboot is required for the change to take full effect."
fi
