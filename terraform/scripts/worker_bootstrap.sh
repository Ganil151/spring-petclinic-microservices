#!/bin/bash
# Pure Bash Worker Node Bootstrap Script for Spring Petclinic Microservices
# Target OS: Amazon Linux 2023
# Path: terraform/scripts/worker_bootstrap.sh

set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname worker-node
echo "Waiting 60 seconds for instance to stabilize..."
sleep 60

# 2. Disk Management (Mount Extra Volume)
echo "Configuring Extra Storage..."
DISK_DEVICE="/dev/sdb"
MOUNT_POINT="/mnt/data"

if [ -b "$DISK_DEVICE" ]; then
    # Only format if it doesn't already have a filesystem
    if ! sudo blkid "$DISK_DEVICE" >/dev/null 2>&1; then
        sudo mkfs -t xfs "$DISK_DEVICE"
    fi
    sudo mkdir -p "$MOUNT_POINT"
    # Mount and add to fstab for persistence
    if ! grep -qs "$MOUNT_POINT" /proc/mounts; then
        sudo mount "$DISK_DEVICE" "$MOUNT_POINT"
        echo "$DISK_DEVICE $MOUNT_POINT xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
    fi
    sudo chown -R ec2-user:ec2-user "$MOUNT_POINT"
fi

# 3. System Updates & Core Dependencies
echo "Updating system packages..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip git jq unzip wget fontconfig java-21-amazon-corretto-devel maven

# 4. Install Docker & Configure Storage
echo "Installing Docker..."
sudo dnf install -y docker
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "data-root": "/mnt/data/docker"
}
EOF

sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# 5. AWS CLI v2 Installation
echo "Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

# 6. Kubernetes Tooling (Kubectl & Helm)
echo "Installing Kubernetes Tools..."
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 7. Final Verification
echo "------------------------------------------------"
echo "✅ Worker Node Pure Bash Setup Complete!"
echo "------------------------------------------------"
java -version 2>&1 | head -n 1
docker --version
sudo docker info | grep "Docker Root Dir"
kubectl version --client
helm version --short
echo "Extra Storage: $(df -h | grep /mnt/data)"
echo "------------------------------------------------"