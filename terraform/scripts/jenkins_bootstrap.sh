#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# Jenkins Master Bootstrap — User Data (First Boot Only)
# ───────────────────────────────────────────────────────────────────
# PURPOSE: Configure Jenkins-specific settings that MUST run at boot.
# NOTE:    Java, Docker, AWS CLI, Kubectl, Helm are installed by Ansible.
#          Do NOT duplicate those installations here.
# ───────────────────────────────────────────────────────────────────
set -e

# ─── 1. Initialization & Stabilization ───────────────────────────
sudo hostnamectl set-hostname jenkins-master
echo "Stabilizing instance for 60 seconds..."
sleep 60

# ─── 2. Minimal System Update ────────────────────────────────────
# Only install packages NOT handled by Ansible roles
echo "Updating system and installing base dependencies..."
sudo dnf update -y
sudo dnf install -y fontconfig git python3 python3-pip wget jq

# ─── 3. Install Jenkins ──────────────────────────────────────────
echo "Installing Jenkins..."
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install -y jenkins

# ─── 4. Configure Jenkins to Run as ec2-user ─────────────────────
echo "Configuring Jenkins service override for ec2-user..."
sudo mkdir -p /etc/systemd/system/jenkins.service.d/
cat <<EOF | sudo tee /etc/systemd/system/jenkins.service.d/override.conf
[Service]
User=ec2-user
Group=ec2-user
Environment="JENKINS_HOME=/var/lib/jenkins"
ExecStart=
ExecStart=/usr/bin/jenkins
EOF

# ─── 5. Prepare Jenkins Directories & Permissions ────────────────
echo "Preparing Jenkins directories for ec2-user..."
sudo mkdir -p /var/lib/jenkins/plugins /var/cache/jenkins /var/log/jenkins
sudo chown -R ec2-user:ec2-user /var/lib/jenkins
sudo chown -R ec2-user:ec2-user /var/cache/jenkins
sudo chown -R ec2-user:ec2-user /var/log/jenkins

sudo systemctl daemon-reload

# ─── 6. Install Jenkins Plugins (before starting service) ────────
echo "Installing Jenkins Plugins..."
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

# ─── 7. Generate SSH Key for ec2-user ────────────────────────────
echo "Generating SSH key for ec2-user..."
sudo -u ec2-user mkdir -p /home/ec2-user/.ssh
sudo -u ec2-user chmod 700 /home/ec2-user/.ssh
if [ ! -f /home/ec2-user/.ssh/id_rsa ]; then
    sudo -u ec2-user ssh-keygen -t rsa -b 4096 -f /home/ec2-user/.ssh/id_rsa -N "" -q
fi
sudo -u ec2-user touch /home/ec2-user/.ssh/known_hosts
sudo -u ec2-user chmod 600 /home/ec2-user/.ssh/known_hosts

# ─── 8. Start Jenkins ────────────────────────────────────────────
echo "Starting Jenkins..."
# Increase /tmp size for large builds
echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
sudo mount -o remount /tmp

sudo systemctl enable jenkins
sudo systemctl start jenkins

echo "Waiting 30 seconds for Jenkins to initialize..."
sleep 30

# ─── 9. Verification (Bootstrap-only Tools) ──────────────────────
echo "────────────────────────────────────────────────"
echo "✅ Jenkins Master Bootstrap Complete!"
echo "────────────────────────────────────────────────"
echo "NOTE: Java, Docker, AWS CLI, Kubectl, Helm will"
echo "      be installed by Ansible in the next phase."
echo "────────────────────────────────────────────────"
printf "Jenkins Version: %s\n" "$(jenkins --version 2>/dev/null || echo 'pending')"
printf "Admin Password:  %s\n" "$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'pending')"
printf "SSH Public Key:  %s\n" "$(sudo cat /home/ec2-user/.ssh/id_rsa.pub 2>/dev/null || echo 'pending')"
echo "────────────────────────────────────────────────"