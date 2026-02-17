#!/bin/bash
# Optimized Worker Node Bootstrap for AL2023
# Target: Spring Petclinic Microservices (Build/Deploy Agent)
set -e

# 1. Initialization
sudo hostnamectl set-hostname worker-node
echo "Stabilizing instance for 60 seconds..."
sleep 60



# 3. System Updates & Dependencies
echo "Installing Build Tools..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip git jq unzip wget fontconfig java-21-amazon-corretto-devel maven
sudo pip3 install ansible

# 4. Docker Configuration (With Mount Check)
echo "Installing Docker..."
sudo dnf install -y docker
sudo mkdir -p /etc/docker


sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
echo "Waiting 10 seconds for Docker to initialize..."
sleep 10

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
printf "Storage:         %s\n" "$(df -h / | tail -1)"
printf "Docker Root:     %s\n" "$(sudo docker info -f '{{.DockerRootDir}}')"
printf "Java:            %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Helm:            %s\n" "$(helm version --short)"
echo "------------------------------------------------"