#!/bin/bash
# Install Jenkins, Java 21, Git, and Docker on Amazon Linux 2023/AL2

set -e

# Initialization
sudo hostnamectl set-hostname jenkins-master 
echo "Stabilizing instance for 60 seconds..."
sleep 60

# Update system packages
echo "Updating system packages..."
sudo dnf update -y

# 1. Install Java 21 (Amazon Corretto)
echo "Installing Java 21..."
sudo dnf install fontconfig java-21-amazon-corretto-devel -y

# 2. Install Jenkins
echo "Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install jenkins -y

# 3. Install Git, Docker, Python3, and Tools
echo "Installing Git, Docker, Python3, Ansible, jq..."
sudo dnf install git docker python3 python3-pip unzip jq -y

# Start Docker
sudo systemctl enable --now docker

# 4. Install Ansible (via pip for latest version)
sudo pip3 install ansible

# 5. Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# 6. Install Kubectl (Latest Stable)
echo "Installing Kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 7. Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 8. Install Terraform
echo "Installing Terraform..."
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo dnf -y install terraform

# 9. Configure Permissions and SSH
echo "Configuring permissions and SSH..."
# Add jenkins and ec2-user to docker group
sudo usermod -aG docker jenkins
sudo usermod -aG docker ec2-user

# Generate SSH key for ec2-user (RSA 4096)
echo "Generating SSH key for ec2-user..."
sudo -u ec2-user mkdir -p /home/ec2-user/.ssh
sudo -u ec2-user chmod 700 /home/ec2-user/.ssh
if [ ! -f /home/ec2-user/.ssh/id_rsa ]; then
    sudo -u ec2-user ssh-keygen -t rsa -b 4096 -f /home/ec2-user/.ssh/id_rsa -N "" -q
fi

# 10. Install Jenkins Plugins
echo "Installing Jenkins Plugins..."

# Ensure the plugin directory exists and has correct permissions
sudo mkdir -p /var/lib/jenkins/plugins
sudo chown -R jenkins:jenkins /var/lib/jenkins

# Install plugins using jenkins-plugin-cli
# Note: Using sudo -u jenkins to ensure file ownership
sudo -u jenkins jenkins-plugin-cli --plugins \
    workflow-aggregator \
    git \
    github-branch-source \
    docker-workflow \
    sonar \
    maven-plugin \
    eclipse-temurin-installer \
    credentials-binding \
    dependency-check-jenkins-plugin \
    aws-credentials \
    pipeline-utility-steps

# 11. Start Jenkins
echo "Starting Jenkins..."
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Restart Docker to apply group changes
sudo systemctl restart docker

echo "Jenkins Master installation complete!"
java -version
jenkins --version
ansible --version
docker --version
aws --version
