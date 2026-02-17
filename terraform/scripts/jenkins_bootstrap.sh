#!/bin/bash
# Install Jenkins (as ec2-user), Java 21, Git, and Docker on AL2023
set -e

# 1. Initialization & Stabilization
sudo hostnamectl set-hostname jenkins-master 
echo "Stabilizing instance for 60 seconds..."
sleep 60

# 2. Update System & Install Application Dependencies
echo "Updating system and installing dependencies..."
sudo dnf update -y
sudo dnf install -y fontconfig java-21-amazon-corretto-devel git docker python3 python3-pip unzip jq
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
sudo pip3 install ansible

# 3. Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

# 4. Install Jenkins
echo "Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install -y jenkins

# 5. Configure Jenkins to run as ec2-user (Critical for Permissions)
echo "Configuring Jenkins service override for ec2-user..."
# Force cleanup of old service state
sudo systemctl stop jenkins || true

# Re-create the override carefully
sudo mkdir -p /etc/systemd/system/jenkins.service.d/
cat <<EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
[Service]
User=ec2-user
Group=ec2-user
Environment="JENKINS_HOME=/var/lib/jenkins"
# This ensures Java is found even if PATH is weird
ExecStart=
ExecStart=/usr/bin/jenkins
EOF

# Wipe any lingering permissions from the default install
sudo chown -R ec2-user:ec2-user /var/lib/jenkins /var/log/jenkins /var/cache/jenkins

sudo systemctl daemon-reload

# 6. Configure Java Environment for ec2-user & Jenkins
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /home/ec2-user/.bashrc
echo "export PATH=\$PATH:\$HOME/bin:\$JAVA_HOME/bin" | sudo tee -a /home/ec2-user/.bashrc

# 7. Prepare Jenkins Directories & Permissions
echo "Preparing Jenkins directories for ec2-user..."
sudo mkdir -p /var/lib/jenkins/plugins /var/cache/jenkins /var/log/jenkins
# Ownership must match the Service User (ec2-user)
sudo chown -R ec2-user:ec2-user /var/lib/jenkins
sudo chown -R ec2-user:ec2-user /var/cache/jenkins
sudo chown -R ec2-user:ec2-user /var/log/jenkins

# 8. Install Jenkins Plugins (before starting service)
echo "Installing Jenkins Plugins..."
# Install using the CLI tool as the service user
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

# 9. Install Kubectl & Helm
echo "Installing Kubectl & Helm..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 10. Generate SSH key for ec2-user
echo "Generating SSH key for ec2-user..."
sudo -u ec2-user mkdir -p /home/ec2-user/.ssh
sudo -u ec2-user chmod 700 /home/ec2-user/.ssh
if [ ! -f /home/ec2-user/.ssh/id_rsa ]; then
    sudo -u ec2-user ssh-keygen -t rsa -b 4096 -f /home/ec2-user/.ssh/id_rsa -N "" -q
fi
# Ensure known_hosts exists
sudo -u ec2-user touch /home/ec2-user/.ssh/known_hosts
sudo -u ec2-user chmod 600 /home/ec2-user/.ssh/known_hosts

# 11. Final Start & Optimization
echo "Starting Jenkins..."
# Increase /tmp size (useful for large builds)
echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
sudo mount -o remount /tmp

# Start Service
sudo systemctl enable jenkins
sudo systemctl start jenkins

echo "Waiting 30 seconds for Jenkins to initialize..."
sleep 30

# Restart Docker to ensure group permissions apply
sudo systemctl restart docker

echo "✅ Jenkins Master installation complete!"
java -version
jenkins --version
docker --version
aws --version
printf "Admin Password:  %s\n" "$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
printf "Jenkins Public SSH Key: %s\n" "$(sudo cat /home/ec2-user/.ssh/id_rsa.pub)"