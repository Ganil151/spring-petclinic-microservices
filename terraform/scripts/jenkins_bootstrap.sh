#!/bin/bash
# Install Jenkins (as ec2-user), Java 21, Git, and Docker on AL2023
set -e

# 1. Initialization & Stabilization
sudo hostnamectl set-hostname jenkins-master 
echo "Stabilizing instance for 60 seconds..."
sleep 60

# 2. Update System & Install Java 21
echo "Updating system and installing Java 21..."
sudo dnf update -y
sudo dnf install fontconfig java-21-amazon-corretto-devel -y

# 3. Install Jenkins
echo "Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install jenkins -y

echo "Configure Java"
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a ~/.bashrc
echo "export PATH=$PATH:$HOME/bin:$JAVA_HOME" | sudo tee -a ~/.bashrc

# 4. Install Component Tools
echo "Installing Git, Docker, Python3, Ansible, jq..."
sudo dnf install git docker python3 python3-pip unzip jq -y
sudo systemctl enable --now docker
sudo pip3 install ansible

# 5. Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

# 6. Install Kubectl & Helm
echo "Installing Kubectl & Helm..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 7. Install Terraform
echo "Installing Terraform..."
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo dnf -y install terraform

# 8. Configure Jenkins to run as ec2-user (Fixes Permission Denied errors)
echo "Configuring Jenkins service override for ec2-user..."
sudo mkdir -p /etc/systemd/system/jenkins.service.d/
cat <<EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
[Service]
User=ec2-user
Group=ec2-user
Environment="JENKINS_HOME=/var/lib/jenkins"
EOF
sudo systemctl daemon-reload

# 9. Configure Permissions and SSH
echo "Configuring permissions and SSH..."
sudo usermod -aG docker ec2-user

# Generate SSH key for ec2-user (RSA 4096)
echo "Generating SSH key for ec2-user..."
sudo -u ec2-user mkdir -p /home/ec2-user/.ssh
sudo -u ec2-user chmod 700 /home/ec2-user/.ssh
if [ ! -f /home/ec2-user/.ssh/id_rsa ]; then
    sudo -u ec2-user ssh-keygen -t rsa -b 4096 -f /home/ec2-user/.ssh/id_rsa -N "" -q
fi

# 10. Prepare Jenkins Directories & Clear Cache
echo "Preparing Jenkins directories for ec2-user..."
sudo mkdir -p /var/lib/jenkins/plugins /var/cache/jenkins /var/log/jenkins
# CRITICAL: Re-chown everything to ec2-user
sudo chown -R ec2-user:ec2-user /var/lib/jenkins
sudo chown -R ec2-user:ec2-user /var/cache/jenkins
sudo chown -R ec2-user:ec2-user /var/log/jenkins
# Clear specific cache that often fails
sudo rm -rf /var/cache/jenkins/war/*



# 11. Install Jenkins Plugins as ec2-user
echo "Installing Jenkins Plugins..."
# Download plugin-cli if not present (AL2023 jenkins package doesn't always have it)
sudo -u ec2-user jenkins-plugin-cli --plugins \
    workflow-aggregator \
    git \
    github-branch-source \
    docker-workflow \
    sonar \
    maven-plugin \
    temurin-installer \
    credentials-binding \
    dependency-check-jenkins-plugin \
    aws-credentials \
    pipeline-utility-steps

# 12. Final Permission Audit & Start
sudo chown -R ec2-user:ec2-user /var/lib/jenkins
sudo chown -R ec2-user:ec2-user /var/cache/jenkins
sudo chown -R ec2-user:ec2-user /var/log/jenkins

echo "Starting Jenkins..."
sudo systemctl enable jenkins
sudo systemctl start jenkins
echo "Waiting 30 seconds for Jenkins to initialize..."
sleep 30



# Restart Docker to apply group changes
sudo systemctl restart docker
echo "Waiting 10 seconds for Docker to restart..."
sleep 10

echo "✅ Jenkins Master installation complete!"
java -version
jenkins --version
ansible --version
docker --version
aws --version
printf "Admin Password:  %s\n" "$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
printf "Jenkins Public SSH Key: %s\n" "$(sudo cat /home/ec2-user/.ssh/id_rsa.pub)"
