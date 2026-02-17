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
sudo usermod -aG docker ec2-user

# 7. SSH Key Generation for ec2-user
echo "Generating RSA 4096 SSH key for ec2-user..."
sudo mkdir -p /var/lib/jenkins/.ssh
if [ ! -f /var/lib/jenkins/.ssh/id_rsa ]; then
    sudo ssh-keygen -t rsa -b 4096 -f /var/lib/jenkins/.ssh/id_rsa -N "" -q
fi
sudo chown -R ec2-user:ec2-user /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh
sudo chmod 600 /var/lib/jenkins/.ssh/id_rsa
sudo chmod 644 /var/lib/jenkins/.ssh/id_rsa.pub

# 8. Jenkins Plugin Installation Manager
echo "Downloading Jenkins Plugin Manager..."
PM_VERSION="2.13.0"
sudo mkdir -p /opt/jenkins-tools
sudo wget -q "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/$PM_VERSION/jenkins-plugin-manager-$PM_VERSION.jar" -O /opt/jenkins-tools/jenkins-plugin-manager.jar

# Define modern microservices plugin set
PLUGINS="workflow-aggregator git github-branch-source docker-workflow sonar maven-plugin temurin-installer credentials-binding dependency-check-jenkins-plugin aws-credentials pipeline-utility-steps"

sudo mkdir -p /var/lib/jenkins/plugins
sudo chown -R ec2-user:ec2-user /var/lib/jenkins/

# Run plugin manager as the ec2-user user to preserve permissions
sudo java -jar /opt/jenkins-tools/jenkins-plugin-manager.jar \
    --war /usr/share/java/jenkins.war \
    --plugin-download-directory /var/lib/jenkins/plugins \
    --plugins $PLUGINS

# Ensure permissions are correct before first start
sudo chown -R ec2-user:ec2-user /var/lib/jenkins/plugins

# Start Jenkins
echo "Starting Jenkins..."
sudo systemctl enable --now jenkins

# 9. Verification
echo "------------------------------------------------"
echo "✅ Jenkins Master Setup Complete!"
echo "------------------------------------------------"
printf "Java Version:    %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Jenkins Status:  %s\n" "$(systemctl is-active jenkins)"
printf "Admin Password:  %s\n" "$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
printf "Jenkins SSH Pub: %s\n" "$(sudo cat /var/lib/jenkins/.ssh/id_rsa.pub)"
echo "------------------------------------------------"