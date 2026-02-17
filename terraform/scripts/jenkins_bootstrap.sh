#!/bin/bash
# Jenkins Master Bootstrap Script for Spring Petclinic Microservices
# Target OS: Amazon Linux 2023
# Path: terraform/scripts/jenkins_bootstrap.sh

set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname jenkins-master

# Sleep to ensure cloud-init network is stable
echo "Waiting 65 seconds for instance to stabilize..."
sleep 65

# 2. System Updates & Core Dependencies
echo "Updating system packages..."
sudo dnf update -y
sudo dnf install -y fontconfig java-21-amazon-corretto-devel wget git docker python3 python3-pip unzip jq

# 3. Install Jenkins
echo "Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install -y jenkins

# 4. Install DevOps Tools
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

# 5. Services & Permissions
echo "Configuring services..."
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
sudo usermod -aG docker jenkins

sudo systemctl enable --now jenkins

# 6. Jenkins Plugin Installation
# Note: We use the Jenkins Plugin CLI (requires manual download or available in some repos)
echo "Installing Jenkins Plugin CLI and Plugins..."
# In AL2023, we might need to get the jar directly if not in dnf
PN_VERSION="2.13.0"
wget -q "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$PN_VERSION/jenkins-plugin-manager-$PN_VERSION.jar" -O jenkins-plugin-manager.jar

# Define plugins
PLUGINS="workflow-aggregator git github-branch-source docker-workflow sonar maven-plugin eclipse-temurin-installer credentials-binding dependency-check-jenkins-plugin aws-credentials pipeline-utility-steps"

# Note: Jenkins needs to be initialized/running for plugin CLI to work perfectly against certain dirs
sudo mkdir -p /var/lib/jenkins/plugins
sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins

java -jar jenkins-plugin-manager.jar --war /usr/share/java/jenkins.war --plugin-download-directory /var/lib/jenkins/plugins --plugins $PLUGINS
sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins
sudo systemctl restart jenkins

# 7. Final Verification
echo "------------------------------------------------"
echo "✅ Jenkins Master Setup Complete!"
echo "------------------------------------------------"
printf "Java Version:    %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Jenkins Version: %s\n" "$(jenkins --version 2>/dev/null || echo 'Service running')"
printf "Docker Version:  %s\n" "$(docker --version)"
printf "AWS CLI:         %s\n" "$(aws --version)"
printf "Kubectl:         %s\n" "$(kubectl version --client --output=yaml | grep gitVersion | head -n 1)"
echo "------------------------------------------------"