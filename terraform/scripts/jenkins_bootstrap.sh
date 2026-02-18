#!/bin/bash
# ───────────────────────────────────────────────────────────────────
# Jenkins Master Bootstrap — User Data (Bare Minimum)
# ───────────────────────────────────────────────────────────────────
# PURPOSE: OS-level prep that MUST happen at first boot before
#          Ansible can connect via SSH.
# ALL tool installations & Jenkins config are handled by Ansible.
# ───────────────────────────────────────────────────────────────────
set -e

# ─── 1. Set Hostname ─────────────────────────────────────────────
sudo hostnamectl set-hostname jenkins-master

# ─── 2. Wait for Cloud-Init to Finish ────────────────────────────
echo "Waiting for instance stabilization..."
sleep 30

# ─── 3. System Update & SSH Dependencies ─────────────────────────
# Install only what's needed for Ansible to connect and gather facts
sudo yum update -y
sudo yum install -y git python3 python3-pip

echo "✅ Bootstrap complete. Ready for Ansible configuration."