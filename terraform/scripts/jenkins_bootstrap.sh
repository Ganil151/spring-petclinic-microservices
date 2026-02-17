#!/bin/bash
# Optimized Jenkins Master Bootstrap for AL2023
# Target: Spring Petclinic Microservices CI/CD
set -e

# 1. Initialization
sudo hostnamectl set-hostname jenkins-master
echo "Stabilizing instance..."
sleep 30 

# 2. System Updates & Core Dependencies
echo "Updating system and installing base tools..."
sudo dnf update -y
sudo dnf install -y fontconfig wget git docker python3 python3-pip unzip jq

# 3. Java 21 (Amazon Corretto)
echo "Installing Java 21..."
sudo dnf install -y java-21-amazon-corretto-devel

# 4. Jenkins Installation (AL2023 specific repo setup)
echo "Configuring Jenkins Repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# Import the NEW 2023 key (critical for AL2023 compatibility)
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install -y jenkins

# 5. DevOps Tooling (AWS CLI & Kubectl)
echo "Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip

echo "Installing Kubectl..."
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 6. Service Configuration & Permissions
echo "Configuring Docker and Permissions..."
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
sudo usermod -aG docker jenkins

# 7. Jenkins Plugin Installation Manager
echo "Downloading Jenkins Plugin Manager..."
PM_VERSION="2.13.0"
sudo mkdir -p /opt/jenkins-tools
sudo wget -q "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$PM_VERSION/jenkins-plugin-manager-$PM_VERSION.jar" -O /opt/jenkins-tools/jenkins-plugin-manager.jar

# Define modern microservices plugin set
PLUGINS="workflow-aggregator git github-branch-source docker-workflow sonar maven-plugin eclipse-temurin-installer credentials-binding dependency-check-jenkins-plugin aws-credentials pipeline-utility-steps"

sudo mkdir -p /var/lib/jenkins/plugins
sudo chown -R jenkins:jenkins /var/lib/jenkins/

# Run plugin manager as the jenkins user to preserve permissions
sudo java -jar /opt/jenkins-tools/jenkins-plugin-manager.jar \
    --war /usr/share/java/jenkins.war \
    --plugin-download-directory /var/lib/jenkins/plugins \
    --plugins $PLUGINS

# Ensure permissions are correct before first start
sudo chown -R jenkins:jenkins /var/lib/jenkins/plugins

# Start Jenkins
echo "Starting Jenkins..."
sudo systemctl enable --now jenkins

# 8. Verification
echo "------------------------------------------------"
echo "✅ Jenkins Master Setup Complete!"
echo "------------------------------------------------"
printf "Java Version:    %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Jenkins Status:  %s\n" "$(systemctl is-active jenkins)"
printf "Admin Password:  %s\n" "$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
echo "------------------------------------------------"