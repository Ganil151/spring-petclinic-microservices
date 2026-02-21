#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# SonarQube Server Bootstrap — User Data (Bare Minimum)
# ───────────────────────────────────────────────────────────────────
# PURPOSE: Hostname only. Kernel tuning, Docker, and the SonarQube
#          stack are ALL handled by the Ansible sonarqube role.
# ───────────────────────────────────────────────────────────────────
set -e

# ─── 1. Set Hostname ─────────────────────────────────────────────
sudo hostnamectl set-hostname sonarqube-server

# ─── 2. Wait for Cloud-Init to Finish ────────────────────────────
echo "Waiting for instance stabilization..."
sleep 30

# ─── 3. System Update & SSH Dependencies ─────────────────────────
sudo yum update -y
sudo yum install -y git python3 python3-pip

# ─── 4. Configure Custom .bashrc ─────────────────────────────────
echo "Configuring custom .bashrc for ec2-user..."
sudo curl -s -o /home/ec2-user/.bashrc https://raw.githubusercontent.com/Ganil151/spring-petclinic-microservices/main/docs/.bashrc
sudo chown ec2-user:ec2-user /home/ec2-user/.bashrc
sudo chmod 644 /home/ec2-user/.bashrc

echo "✅ Bootstrap complete. Ready for Ansible configuration."