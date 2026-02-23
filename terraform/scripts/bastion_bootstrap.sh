 #!/bin/bash

              

set -e

# ─── 1. Set Hostname ─────────────────────────────────────────────
sudo hostnamectl set-hostname bastion-server

# ─── 2. Wait for Cloud-Init to Finish ────────────────────────────
echo "Waiting for instance stabilization..."
sleep 30

# ─── 3. System Update & SSH Dependencies ─────────────────────────
# Install only what's needed for Ansible to connect and gather facts
sudo yum update -y
sudo yum install -y git python3 python3-pip docker wget
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user