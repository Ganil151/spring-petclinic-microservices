#!/bin/bash
set -euo pipefail

echo "--- Updating system ---"
sudo yum update -y

echo "--- Installing required packages ---"
sudo yum install -y curl tar gzip unzip iproute util-linux

echo "--- Installing Docker (Amazon Linux 2023) ---"
sudo yum install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user || true

echo "--- Installing Kubernetes kubectl (latest stable) ---"
KUBE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
ARCH=$(uname -m)

if [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
  ARCH="amd64"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

curl -LO "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl"
curl -LO "https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/${ARCH}/kubectl.sha256"

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl kubectl.sha256

echo "--- Installing K3s (Kubernetes lightweight) ---"
curl -sfL https://get.k3s.io | sh -

echo "--- Copying kubeconfig to /home/ec2-user/.kube/config ---"
sudo mkdir -p /home/ec2-user/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config
sudo chmod 644 /home/ec2-user/.kube/config

echo "--- Installation completed successfully ---"
echo "Test Kubernetes: kubectl get nodes"
