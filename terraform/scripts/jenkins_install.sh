#!/bin/bash
# Install Jenkins, Java 21, Git, and Docker on Amazon Linux 2023/AL2

set -e

# Update system packages
echo "Updating system packages..."
sudo yum update -y

# 1. Install Java 21 (Amazon Corretto)
echo "Installing Java 21..."
# Try dnf first (AL2023), fallback to yum
if command -v dnf &> /dev/null; then
    sudo dnf install java-21-amazon-corretto-headless -y
else
    # For AL2, we might need to enable a repo or use a direct rpm if not in default repos, 
    # but amazon-linux-extras doesn't have java 21 yet. 
    # Attempting direct install layout for AWS environment:
    sudo yum install java-21-amazon-corretto-headless -y || sudo yum install java-21-openjdk-headless -y
fi

# Verify Java version
java -version

# 2. Install Jenkins
echo "Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum upgrade -y
sudo yum install jenkins -y

# Enable and start Jenkins
sudo systemctl enable jenkins
sudo systemctl start jenkins

# 3. Install Git
echo "Installing Git..."
sudo yum install git -y

# 4. Install Docker (Useful for Jenkins pipelines)
echo "Installing Docker..."
sudo yum install docker -y
sudo systemctl enable docker
sudo systemctl start docker

# Add jenkins user to docker group so it can run docker commands
sudo usermod -aG docker jenkins

# Restart Jenkins to pick up group changes
sudo systemctl restart jenkins

echo "Jenkins installation complete!"
