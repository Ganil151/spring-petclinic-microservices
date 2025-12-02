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
sudo chmod +x /etc/profile.d/mysql_env.sh

# Install MySQL 8.0
Mysql_Community="mysql80-community-release-el9-1.noarch.rpm"
echo "Downloading MySQL 8.0 repository..."
sudo wget https://dev.mysql.com/get/$Mysql_Community
sudo yum localinstall -y $Mysql_Community
sudo rm -f $Mysql_Community
echo "Importing MySQL GPG key..."
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023

echo "Installing MySQL server and client..."
sudo yum install -y mysql-community-client mysql-community-server

sudo yum update -y

# Start MySQL Service
echo "Starting and enabling MySQL service..."
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Verify MySQL is running
if sudo systemctl is-active --quiet mysqld; then
    echo "✓ MySQL service started successfully."
else
    echo "✗ ERROR: MySQL service failed to start. Check logs with: sudo journalctl -u mysqld"
    exit 1
fi

# Secure MySQL Installation
echo "Securing MySQL installation..."

# Wait for MySQL to fully initialize and generate temporary password
echo "Waiting for MySQL to generate temporary password..."
COUNTER=0
MAX_WAIT=30
while ! sudo grep -q 'temporary password' /var/log/mysqld.log 2>/dev/null && [ $COUNTER -lt $MAX_WAIT ]; do
    sleep 2
    COUNTER=$((COUNTER + 2))
    echo "Waiting for temporary password... ($COUNTER/$MAX_WAIT seconds)"
done

if ! sudo grep -q 'temporary password' /var/log/mysqld.log; then
    echo "✗ ERROR: Temporary password not found in /var/log/mysqld.log"
    echo "This might mean MySQL was already configured or there was an installation issue."
    exit 1
fi

## Extract the last temporary password (in case of multiple entries)
TEMP_PASSWORD=$(sudo grep 'temporary password' /var/log/mysqld.log | tail -1 | awk '{print $NF}')
NEW_PASSWORD='PetMa3ter$3JH3!'

echo "Configuring MySQL root password and security settings..."
if mysql --connect-expired-password -uroot -p"$TEMP_PASSWORD" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
then
    echo "✓ MySQL security configuration completed successfully."
else
    echo "✗ ERROR: Failed to configure MySQL security settings."
    exit 1
fi

# Restart MySQL to apply changes
echo "Restarting MySQL service..."
sudo systemctl restart mysqld

# Verify MySQL is still running after restart
if sudo systemctl is-active --quiet mysqld; then
    echo "✓ MySQL restarted successfully."
else
    echo "✗ ERROR: MySQL service failed to restart."
    exit 1
fi

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

echo "="
echo "MySQL installation and configuration completed successfully."
echo "Root password has been set to: $NEW_PASSWORD"
echo "IMPORTANT: Change this password and store it securely!"
echo "="