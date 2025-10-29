#!/bin/bash

set -e

# Change Host Name
echo "Change Host Name"
sudo hostnamectl set-hostname "jenkins-server"

# Install dependencies and update system
echo "Install dependencies and update system"
sudo yum update -y
# Install Java
echo "Installing Java..."
sudo yum install -y java-21-amazon-corretto-devel git

# Configure Java
echo "Configure Java"
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a ~/.bashrc
echo "export PATH=$PATH:$HOME/bin:$JAVA_HOME" | sudo tee -a ~/.bashrc


# Install Jenkins
echo "Installing Jenkins"

# Add Jenkins repo key and source list
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum upgrade -y
# Add required dependencies for the jenkins package
sudo yum install jenkins -y
sudo systemctl daemon-reload

# Configure Java in Jenkins
echo "Configure Java"
sudo touch /var/lib/jenkins/.bash_profile
sudo chown -R jenkins:jenkins /var/lib/jenkins/.bash_profile
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /var/lib/jenkins/.bash_profile
echo "export PATH=$PATH:$HOME/bin:$JAVA_HOME" | sudo tee -a /var/lib/jenkins/.bash_profile


# Configure Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo yum update -y


# Configure SSH for Jenkins user
echo "Generating SSH key for Jenkins..."
sudo -u jenkins mkdir -p /var/lib/jenkins/.ssh
sudo -u jenkins ssh-keygen -t rsa -b 4096 -N "" -f /var/lib/jenkins/.ssh/id_rsa

# Fix permissions
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh
sudo chmod 600 /var/lib/jenkins/.ssh/id_rsa
sudo chmod 644 /var/lib/jenkins/.ssh/id_rsa.pub

# Create known_hosts file
sudo touch /var/lib/jenkins/.ssh/known_hosts
sudo chmod 644 /var/lib/jenkins/.ssh/known_hosts

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


echo "Script execution complete. Jenkins should be running."
