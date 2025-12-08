#!/bin/bash
set -e

echo "=== Starting Kubernetes Agent 2 Server Setup ==="

# --- Configure Hostname ---
NEW_HOSTNAME="K8s-Agent-2-Server"
echo "Setting hostname to: ${NEW_HOSTNAME}"
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"

# --- Install Dependencies ---
echo "[Step 2] Installing Dependencies..."  
sudo dnf update 
sudo dnf upgrade -y

