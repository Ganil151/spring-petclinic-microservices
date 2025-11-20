#!/usr/bin/env bash
# install_k3s_worker_amzlinux2023.sh
# Usage: ./install_k3s_worker_amzlinux2023.sh <K3S_SERVER_ENDPOINT> <NODE_TOKEN>
# Example: ./install_k3s_worker_amzlinux2023.sh https://10.0.3.10:6443 K107...token...

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <K3S_SERVER_URL> <NODE_TOKEN>"
  echo " e.g. $0 https://10.0.3.10:6443 K10xxxx"
  exit 2
fi

K3S_SERVER_URL="$1"
K3S_NODE_TOKEN="$2"

sudo dnf -y upgrade
sudo dnf -y install curl jq iproute iptables

sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab || true

sudo tee /etc/sysctl.d/99-k3s.conf > /dev/null <<'EOF'
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sudo sysctl --system

# Install k3s agent joining the provided server and using token
curl -sfL https://get.k3s.io | K3S_URL="${K3S_SERVER_URL}" K3S_TOKEN="${K3S_NODE_TOKEN}" sh -
sudo systemctl status k3s-agent --no-pager

echo "k3s agent installed and joining ${K3S_SERVER_URL}"

