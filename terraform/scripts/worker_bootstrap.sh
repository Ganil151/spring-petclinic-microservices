#!/bin/bash
# Optimized Worker Node Bootstrap for AL2023
# Target: Spring Petclinic Microservices (Build/Deploy Agent)
set -e

# 1. Initialization
sudo hostnamectl set-hostname worker-node
echo "Stabilizing instance for 60 seconds..."
sleep 60

# 2. Update System & Install Application Dependencies
echo "Updating system and installing dependencies..."
sudo dnf update -y
sudo dnf install -y fontconfig java-21-amazon-corretto-devel git docker python3 python3-pip unzip jq maven

# 3. Install Ansible
echo "Installing Ansible..."
sudo pip3 install ansible

# 4. Configure Java Environment
echo "Configuring Java Environment..."
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /home/ec2-user/.bashrc
echo "export PATH=\$PATH:\$HOME/bin:\$JAVA_HOME/bin" | sudo tee -a /home/ec2-user/.bashrc
# Also apply to root for sudo operations if needed, though less critical
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a /root/.bashrc

# 5. Docker Configuration
echo "Installing and Configuring Docker..."
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
echo "Waiting 10 seconds for Docker to initialize..."
sleep 10

# 6. Tooling: AWS CLI v2, Kubectl, Helm
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
printf "Maven:           %s\n" "$(mvn -version | head -n 1)"
printf "Helm:            %s\n" "$(helm version --short)"
printf "Ansible:         %s\n" "$(ansible --version | head -n 1)"
echo "------------------------------------------------"