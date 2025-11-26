#!/bin/bash
#############################################
# K8s Master Complete Setup
# One script to configure everything
#############################################

set -euo pipefail

echo "=========================================="
echo "K8s Master Complete Setup"
echo "=========================================="
echo ""
date
echo ""

# Configure kubectl
echo "=== Configuring kubectl ==="
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config 2>/dev/null || { echo "K8s not installed yet"; exit 1; }
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Add completion
if ! grep -q "kubectl completion" ~/.bashrc 2>/dev/null; then
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    echo 'alias k=kubectl' >> ~/.bashrc
fi

echo "✓ kubectl configured"
echo ""

# Install Calico CNI
echo "=== Installing Calico CNI ==="
if [ $(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l) -eq 0 ]; then
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
    sleep 10
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
    echo "✓ Calico installation initiated"
else
    echo "✓ Calico already installed"
fi

echo ""

# Wait for nodes to be Ready
echo "=== Waiting for nodes (max 5 min) ==="
for i in {1..60}; do
    if [ $(kubectl get nodes --no-headers 2>/dev/null | grep -c "NotReady" || true) -eq 0 ]; then
        echo "✓ All nodes Ready!"
        break
    fi
    echo "[$i/60] Waiting for nodes..."
    sleep 5
done

echo ""
kubectl get nodes -o wide
echo ""

# Summary
READY=$(kubectl get nodes --no-headers | grep -c " Ready " || true)
TOTAL=$(kubectl get nodes --no-headers | wc -l)

if [ "$READY" -eq "$TOTAL" ]; then
    echo "=========================================="
    echo "✓ SUCCESS - Cluster Ready!"
    echo "=========================================="
    echo ""
    echo "Deploy applications:"
    echo "  kubectl apply -f ~/spring-petclinic-microservices/kubernetes/deployments/"
else
    echo "⚠ Wait 2-3 more minutes, then run: bash $0"
fi
echo ""
