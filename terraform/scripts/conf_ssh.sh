#!/bin/bash

set -e

# Generate SSH key for ec2-user
echo "Generating SSH key for ec2-user..."
if id "ec2-user" &>/dev/null; then
 sudo -u ec2-user mkdir -p /home/ec2-user/.ssh
 sudo -u ec2-user chmod 700 /home/ec2-user/.ssh
 if [ ! -f /home/ec2-user/.ssh/id_rsa ]; then
 sudo -u ec2-user ssh-keygen -t rsa -b 4096 -f /home/ec2-user/.ssh/id_rsa -N "" -q
 fi
 sudo -u ec2-user touch /home/ec2-user/.ssh/known_hosts
 sudo -u ec2-user chmod 600 /home/ec2-user/.ssh/known_hosts
else
 echo "Warning: ec2-user does not exist. Skipping SSH key generation."
fi

# 11. Final Start & Optimization
echo "Starting Jenkins..."
# Increase /tmp size (useful for large builds) - Idempotent check
if ! grep -q "/tmp tmpfs" /etc/fstab; then
 echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
 sudo mount -o remount /tmp
else
 echo "/tmp already configured in fstab."
fi

echo "Installing Jenkins Plugins..."
if command -v jenkins-plugin-cli &> /dev/null; then
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
else
 echo "Warning: jenkins-plugin-cli not found."
fi

# Start Jenkins Service
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Security: Do not print secrets to stdout
echo "Jenkins setup complete. Retrieve admin password securely via: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
