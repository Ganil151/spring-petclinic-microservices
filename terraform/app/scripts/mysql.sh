#!/bin/bash

set -ea

# Change Host Name
echo "Changing Host Name..."
sudo hostnamectl set-hostname "Mysql-Server"

# Load Dependencies
echo "Updating system and installing dependencies..."
sudo yum update -y
sudo yum install -y java-21-amazon-corretto-devel wget git

# Configure Java
echo "Configure Java"
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a ~/.bashrc
echo "export PATH=$PATH:$HOME/bin:$JAVA_HOME" | sudo tee -a ~/.bashrc


# Install MySQL 8.0
echo "Downloading MySQL 8.0 repository..."
sudo wget https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
sudo yum localinstall -y mysql80-community-release-el9-1.noarch.rpm
sudo rm -f mysql80-community-release-el9-1.noarch.rpm

echo "Importing MySQL GPG key..."
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023

echo "Installing MySQL server and client..."
sudo yum install -y mysql-community-client mysql-community-server

sudo yum update -y

# Start MySQL Service
echo "Starting and enabling MySQL service..."
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Secure MySQL Installation
echo "Securing MySQL installation..."
if ! sudo grep -q 'temporary password' /var/log/mysqld.log; then
  echo "Temporary password not found in /var/log/mysqld.log"
  exit 1
fi

TEMP_PASSWORD=$(sudo grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
NEW_PASSWORD='Mysql$9999!'

mysql --connect-expired-password -uroot -p"$TEMP_PASSWORD" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF

# Restart MySQL to apply changes
echo "Restarting MySQL service..."
sudo systemctl restart mysqld

echo "MySQL installation and configuration completed successfully."