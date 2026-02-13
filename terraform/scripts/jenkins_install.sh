#!/bin/bash
# Install Jenkins, Java 21, Git, and Docker on Amazon Linux 2023/AL2

set -e

# Hostname
sudo hostnamectl set-hostname jenkins-master 

# Sleep for 60 seconds as requested to ensure instance is fully ready
echo "Sleeping for 60 seconds..."
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

# 6. Configure Permissions
echo "Configuring permissions..."
# Add jenkins and ec2-user to docker group
sudo usermod -aG docker jenkins
sudo usermod -aG docker ec2-user

# Restart Docker to apply group changes
sudo systemctl restart docker

# 7. Start Jenkins
echo "Starting Jenkins..."
sudo systemctl enable jenkins
sudo systemctl start jenkins

# 8. Generate SSH Key for Ansible Communication
echo "Generating SSH key for ec2-user..."
sudo -u ec2-user mkdir -p /home/ec2-user/.ssh
if [ ! -f /home/ec2-user/.ssh/id_rsa ]; then
    sudo -u ec2-user ssh-keygen -t rsa -b 4096 -f /home/ec2-user/.ssh/id_rsa -N "" -q
fi
sudo chmod 700 /home/ec2-user/.ssh
sudo chmod 600 /home/ec2-user/.ssh/id_rsa
sudo chmod 644 /home/ec2-user/.ssh/id_rsa.pub

echo "Jenkins Master installation complete!"
java -version
jenkins --version
ansible --version
docker --version
aws --version
