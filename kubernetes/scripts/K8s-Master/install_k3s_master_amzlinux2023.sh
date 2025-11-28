#!/usr/bin/env bash
# install_k3s_master_amzlinux2023.sh
# Run on the instance you want to be the k3s control plane (Amazon Linux 2023)

set -euo pipefail

# 1) Basic system updates & tools
sudo dnf -y upgrade
sudo dnf -y install curl jq git iproute iptables

# 2) Ensure swap off (kube prefers swap disabled)
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab || true

# 3) Open required sysctl (recommended)
sudo tee /etc/sysctl.d/99-k3s.conf > /dev/null <<'EOF'
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sudo sysctl --system

# 4) Install k3s (server)
# Optionally set agent token path or specify node-ip
INSTALL_K3S_VERSION="v1.29.15+k3s1"   # optional: lock to a stable version or leave empty for latest
# If you want a specific CNI or disable traefik, set extra env vars below
export K3S_KUBECONFIG_MODE="644"  # allow read access to kubeconfig (so Jenkins can fetch it)
# Example: disable Traefik if you plan to install a different ingress
# export INSTALL_K3S_EXEC="--no-deploy=traefik"

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="${INSTALL_K3S_VERSION}" sh -s -

# 5) Wait a moment and verify
sleep 5
sudo systemctl status k3s --no-pager

# 6) Copy kubeconfig for admin use
KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
echo "kubeconfig: ${KUBECONFIG_PATH}"
# Optionally copy to /home/ec2-user/.kube/config for convenience
sudo mkdir -p /home/ec2-user/.kube
sudo cp "${KUBECONFIG_PATH}" /home/ec2-user/.kube/config
sudo chown ec2-user:ec2-user /home/ec2-user/.kube/config
chmod 600 /home/ec2-user/.kube/config

# 7) Print join token (used by workers)
echo "K3S_NODE_TOKEN:"
sudo cat /var/lib/rancher/k3s/server/node-token

echo "k3s master installed. Run 'kubectl get nodes' from the master or from a host with kubeconfig."

