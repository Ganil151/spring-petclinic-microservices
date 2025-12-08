#!/bin/bash
set -e

# --- 1. Configure Hostname & Local DNS Resolution ---
echo "[Step 1] Configuring Hostname..."
NEW_HOSTNAME="K8s-Master-Server"
echo "Setting hostname to: ${NEW_HOSTNAME}"
sudo hostnamectl set-hostname "${NEW_HOSTNAME}"


# --- 2. Install Dependencies ---
echo "[Step 2] Installing Dependencies..."  
sudo dnf update 
sudo dnf upgrade -y

