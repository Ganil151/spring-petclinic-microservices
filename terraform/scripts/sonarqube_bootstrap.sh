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

echo "✅ Bootstrap complete. Ready for Ansible configuration."