#!/bin/bash
# Pure Bash Jenkins Master Bootstrap Script for Spring Petclinic Microservices
# Target OS: Amazon Linux 2023
# Path: terraform/scripts/jenkins_bootstrap.sh

set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname jenkins-master

echo "Waiting 60 seconds for instance to stabilize..."
sleep 60

# 2. System Updates & Core Dependencies
echo "Updating system packages..."
sudo dnf update -y
sudo dnf install -y fontconfig wget git docker python3 python3-pip unzip jq

# 3. Install Java 21 (Required for modern Jenkins)
echo "Installing Amazon Corretto 21..."
sudo dnf install -y java-21-amazon-corretto-devel

# 4. Install Jenkins
echo "Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install -y jenkins

# 5. Install DevOps Tools
echo "Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

echo "Installing Kubectl..."
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 6. Services & Permissions
echo "Configuring services..."
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
sudo usermod -aG docker jenkins

# Start Jenkins
sudo systemctl enable --now jenkins

# 7. Jenkins Plugin Installation
echo "Installing Jenkins Plugins..."
# Download the plugin manager tool
PN_VERSION="2.13.0"
wget -q "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$PN_VERSION/jenkins-plugin-manager-$PN_VERSION.jar" -O /opt/jenkins-plugin-manager.jar

# Define plugins
PLUGINS="workflow-aggregator git github-branch-source docker-workflow sonar maven-plugin eclipse-temurin-installer credentials-binding dependency-check-jenkins-plugin aws-credentials pipeline-utility-steps"

# Ensure plugin directory exists
sudo mkdir -p /var/lib/jenkins/plugins
sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins

# Run the manager tool (Note: this downloads .hpi files into the plugin directory)
sudo java -jar /opt/jenkins-plugin-manager.jar \
    --war /usr/share/java/jenkins.war \
    --plugin-download-directory /var/lib/jenkins/plugins \
    --plugins $PLUGINS

# Fix permissions again after download
sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins

# Restart to load plugins
sudo systemctl restart jenkins

# 8. Final Verification
echo "------------------------------------------------"
echo "✅ Jenkins Master Pure Bash Setup Complete!"
echo "------------------------------------------------"
printf "Java Version:    %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Jenkins Status:  %s\n" "$(systemctl is-active jenkins)"
printf "Docker Version:  %s\n" "$(docker --version)"
echo "------------------------------------------------"