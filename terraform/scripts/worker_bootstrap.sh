#!/bin/bash
# Optimized Worker Node Bootstrap for AL2023
# Target: Spring Petclinic Microservices (Build/Deploy Agent)
set -e

# 1. Initialization
sudo hostnamectl set-hostname worker-node
echo "Stabilizing instance..."
sleep 30

# 2. Advanced Disk Management (AL2023 / NVMe Aware)
echo "Configuring Extra Storage..."
# Modern AWS instances use NVMe; /dev/sdb is often /dev/nvme1n1
DISK_DEVICE=$(lsblk -dpno NAME | grep -E 'nvme[1-9]n1|sdb' | head -n 1)
MOUNT_POINT="/mnt/data"

if [ -n "$DISK_DEVICE" ]; then
    echo "Found device: $DISK_DEVICE"
    # Format if no filesystem exists
    if ! sudo blkid "$DISK_DEVICE" >/dev/null 2>&1; then
        sudo mkfs -t xfs "$DISK_DEVICE"
    fi
    
    sudo mkdir -p "$MOUNT_POINT"
    
    # Get UUID for stable fstab (Best Practice)
    UUID=$(sudo blkid -s UUID -o value "$DISK_DEVICE")
    
    if ! grep -qs "$MOUNT_POINT" /proc/mounts; then
        echo "UUID=$UUID $MOUNT_POINT xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
        sudo mount -a
    fi
    sudo chown -R ec2-user:ec2-user "$MOUNT_POINT"
else
    echo "WARNING: No extra disk found. Proceeding with root partition (Not recommended for Prod)."
fi

# 3. System Updates & Dependencies
echo "Installing Build Tools..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip git jq unzip wget fontconfig java-21-amazon-corretto-devel maven

# 4. Docker Configuration (With Mount Check)
echo "Installing Docker..."
sudo dnf install -y docker
sudo mkdir -p /etc/docker

# Only move Docker root if mount was successful
if mountpoint -q "$MOUNT_POINT"; then
    sudo mkdir -p "$MOUNT_POINT/docker"
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "data-root": "$MOUNT_POINT/docker",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
fi

sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# 5. Tooling: AWS CLI v2, Kubectl, Helm
echo "Installing AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip

echo "Installing Kubectl..."
K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "Installing Helm..."
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 6. Final Verification
echo "------------------------------------------------"
echo "✅ Worker Node Setup Complete!"
echo "------------------------------------------------"
printf "Storage:         %s\n" "$(df -h $MOUNT_POINT | tail -1)"
printf "Docker Root:     %s\n" "$(sudo docker info -f '{{.DockerRootDir}}')"
printf "Java:            %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Helm:            %s\n" "$(helm version --short)"
echo "------------------------------------------------"