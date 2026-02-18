#!/bin/bash
# Optimized Worker Node Bootstrap for AL2023
# Target: Spring Petclinic Microservices (Build/Deploy Agent)
set -e

# 1. Initialization
sudo hostnamectl set-hostname worker-node
echo "Stabilizing instance for 60 seconds..."
sleep 60

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

# 3. Update System & Install Application Dependencies
echo "Updating system and installing dependencies..."
sudo dnf update -y
sudo dnf install -y fontconfig java-21-amazon-corretto-devel git docker python3 python3-pip unzip jq maven

# 4. Install Ansible
echo "Installing Ansible..."
sudo pip3 install ansible

# 5. Configure Java Environment
echo "Configuring Java Environment..."
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /home/ec2-user/.bashrc
echo "export PATH=\$PATH:\$HOME/bin:\$JAVA_HOME/bin" | sudo tee -a /home/ec2-user/.bashrc
# Also apply to root for sudo operations if needed, though less critical
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /root/.bashrc

# 6. Docker Configuration
echo "Installing and Configuring Docker..."
# Only move Docker root if mount was successful
if mountpoint -q "$MOUNT_POINT"; then
sudo mkdir -p "$MOUNT_POINT/docker"
sudo mkdir -p /etc/docker
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
echo "Waiting 10 seconds for Docker to initialize..."
sleep 10

# 7. Tooling: AWS CLI v2, Kubectl, Helm
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

# 8. Final Verification
echo "------------------------------------------------"
echo "✅ Worker Node Setup Complete!"
echo "------------------------------------------------"
printf "Storage:         %s\n" "$(df -h $MOUNT_POINT 2>/dev/null || df -h / | tail -1)"
printf "Docker Root:     %s\n" "$(sudo docker info -f '{{.DockerRootDir}}')"
printf "Java:            %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Maven:           %s\n" "$(mvn -version | head -n 1)"
printf "Helm:            %s\n" "$(helm version --short)"
printf "Ansible:         %s\n" "$(ansible --version | head -n 1)"
echo "------------------------------------------------"