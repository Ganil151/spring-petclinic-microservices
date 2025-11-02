#!/bin/bash

set -e

# --- 1. System Setup and Dependencies ---

echo "--- 1. System Setup ---"
# Set Host Name
NEW_HOSTNAME="Master-Server"
echo "Setting Host Name to: ${NEW_HOSTNAME}"
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"

# Install core dependencies and update system
echo "Installing core dependencies and updating system..."
sudo yum update -y
sudo yum install -y java-21-amazon-corretto-devel git wget yum-utils device-mapper-persistent-data lvm2

# --- 2. Java and Maven Configuration ---

echo "--- 2. Java and Maven Configuration ---"
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

# --- 3. Install and Start Jenkins ---

echo "--- 3. Install and Start Jenkins ---"
# Add Jenkins repo key and source list
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum upgrade -y
# Install Jenkins
sudo yum install jenkins -y
sudo systemctl daemon-reload

# Start and enable Jenkins
echo "Starting Jenkins service..."
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins | grep Active

# --- 4. Configure Jenkins User Environment (Critical for builds) ---
echo "Configure Jenkins User Environment Variables..."
JENKINS_PROFILE="/var/lib/jenkins/.bashrc"
echo "Configuring Jenkins user's shell profile (${JENKINS_PROFILE})..."

# Ensure the file exists and is owned by jenkins
sudo touch "${JENKINS_PROFILE}"
sudo chown jenkins:jenkins "${JENKINS_PROFILE}"

{
    echo "# Jenkins user specific environment variables"
    echo "export JAVA_HOME=${JAVA_HOME}"
    if [ -n "$M2_HOME" ]; then
        echo "export M2_HOME=${M2_HOME}"
    fi
    echo "export PATH=\$PATH:\$JAVA_HOME/bin"
    if [ -n "$M2_HOME" ]; then
        echo "export PATH=\$PATH:\$M2_HOME/bin"
    fi
} | sudo tee -a "${JENKINS_PROFILE}"

# --- 5. SSH Configuration for Jenkins User ---

echo "--- 5. SSH Configuration for Jenkins User ---"
SSH_DIR="/var/lib/jenkins/.ssh"
echo "Generating SSH key for Jenkins in ${SSH_DIR}..."

# Use -p to create parent directories if they don't exist
sudo -u jenkins mkdir -p "${SSH_DIR}"
# Generate SSH keypair
sudo -u jenkins ssh-keygen -t rsa -b 4096 -N "" -f "${SSH_DIR}/id_rsa" -C "jenkins@${NEW_HOSTNAME}"

# Fix permissions
sudo chown -R jenkins:jenkins "${SSH_DIR}"
sudo chmod 700 "${SSH_DIR}"
sudo chmod 600 "${SSH_DIR}/id_rsa"
sudo chmod 644 "${SSH_DIR}/id_rsa.pub"

# Create or ensure known_hosts file exists with correct permissions
sudo touch "${SSH_DIR}/known_hosts"
sudo chmod 644 "${SSH_DIR}/known_hosts"
sudo chown jenkins:jenkins "${SSH_DIR}/known_hosts"

# --- 6. /tmp Filesystem Tuning ---
echo "--- 6. /tmp Filesystem Tuning ---"
if ! grep -q "/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
fi

echo "Remounting /tmp with the new size..."
if sudo mount -o remount /tmp; then
    echo "/tmp remounted successfully with 1.5GB size."
else
    echo "WARNING: Failed to remount /tmp immediately. A system reboot is required for the change to take full effect."
fi

# --- 7. Final Output ---
echo "--- Script execution complete. ---"
echo "Jenkins is starting. Initial Admin Password:"
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
echo "NOTE: Remember to add the contents of ${SSH_DIR}/id_rsa.pub to your GitHub deploy keys."