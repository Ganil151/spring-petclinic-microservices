#!/bin/bash

# Complete Kubernetes cluster setup and deployment script
# This script will:
# 1. Validate Ansible configuration
# 2. Run the cluster setup playbook with roles
# 3. Deploy applications with correct DNS configuration

set -e

ANSIBLE_DIR="/home/ganil/spring-petclinic-microservices/ansible"
K8S_DIR="/home/ganil/spring-petclinic-microservices/kubernetes"

echo "==========================================="
echo "Kubernetes Cluster Setup & Deployment"
echo "==========================================="
echo ""

# Step 1: Validate Ansible configuration
echo "[Step 1/4] Validating Ansible configuration..."
cd "$ANSIBLE_DIR" || exit 1

if ansible-inventory -i inventory.ini --list &>/dev/null; then
  echo "  ✓ Inventory is valid"
else
  echo "  ✗ Inventory validation failed"
  exit 1
fi

# Check playbook syntax
if ansible-playbook playbooks/k8s-cluster-roles.yml --syntax-check &>/dev/null; then
  echo "  ✓ Playbook syntax is valid"
else
  echo "  ✗ Playbook syntax check failed"
  exit 1
fi

# Step 2: Run cluster setup playbook
echo ""
echo "[Step 2/4] Setting up Kubernetes cluster with roles..."
echo "  This may take 10-15 minutes..."
echo ""

ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v

# Step 3: Verify cluster health
echo ""
echo "[Step 3/4] Verifying cluster health..."
KUBECONFIG=/home/ec2-user/.kube/config

if ! kubectl cluster-info &>/dev/null; then
  echo "  ✗ Cluster is not responding"
  exit 1
fi

echo "  ✓ Cluster is online"

echo "  Checking node status..."
kubectl get nodes -o wide || true

echo ""
echo "  Checking pod status..."
kubectl get pods -A --no-headers | head -20 || true

# Step 4: Deploy applications
echo ""
echo "[Step 4/4] Deploying applications with correct DNS configuration..."
echo "  Deleting old deployments..."

cd "$K8S_DIR" || exit 1

for app in admin-server api-gateway customers-service discovery-server genai-service vets-service visits-service; do
  kubectl delete deployment "$app" -n default --ignore-not-found=true 2>/dev/null || true
done

sleep 20

echo "  Applying updated deployments..."
for app in admin-server api-gateway customers-service discovery-server genai-service vets-service visits-service; do
  kubectl apply -f "base/deployments/${app}.yaml" 2>/dev/null || true
done

echo ""
echo "==========================================="
echo "Setup and deployment complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "1. Monitor pod startup:"
echo "   kubectl get pods -w"
echo ""
echo "2. Check application logs:"
echo "   kubectl logs <pod-name>"
echo ""
echo "3. Verify services:"
echo "   kubectl get svc"
echo ""
echo "4. Access applications (after services are ready):"
echo "   kubectl port-forward svc/api-gateway 8080:8080"
