#!/bin/bash

# Script to fix kubeconfig permissions and redeploy applications

set -e

echo "==========================================="
echo "Fixing kubeconfig and Redeploying Apps"
echo "==========================================="
echo ""

# Step 1: Check and fix kubeconfig location
echo "[1/4] Checking kubeconfig..."
if [ -z "$KUBECONFIG" ]; then
  echo "  KUBECONFIG not set, checking default locations..."
  if [ -f "$HOME/.kube/config" ]; then
    export KUBECONFIG="$HOME/.kube/config"
    echo "  Found kubeconfig at: $KUBECONFIG"
  elif [ -f "/etc/kubernetes/admin.conf" ]; then
    export KUBECONFIG="/etc/kubernetes/admin.conf"
    echo "  Found kubeconfig at: $KUBECONFIG"
  else
    echo "  ERROR: Could not find kubeconfig!"
    exit 1
  fi
else
  echo "  Using KUBECONFIG: $KUBECONFIG"
fi

# Step 2: Verify kubeconfig is readable
echo ""
echo "[2/4] Verifying kubeconfig access..."
if [ ! -r "$KUBECONFIG" ]; then
  echo "  kubeconfig is not readable, attempting to fix permissions..."
  chmod 600 "$KUBECONFIG"
  echo "  Fixed kubeconfig permissions"
fi

# Step 3: Test kubectl connectivity
echo ""
echo "[3/4] Testing kubectl connectivity..."
if kubectl cluster-info &>/dev/null; then
  echo "  ✓ kubectl is working correctly"
  kubectl cluster-info
else
  echo "  ✗ kubectl connection failed!"
  echo "  Attempting to diagnose..."
  kubectl cluster-info || true
  exit 1
fi

# Step 4: Redeploy applications
echo ""
echo "[4/4] Redeploying applications..."

DEPLOYMENTS_DIR="$(dirname "$0")/../base/deployments"

DEPLOYMENTS=(
  "admin-server"
  "api-gateway"
  "customers-service"
  "discovery-server"
  "genai-service"
  "vets-service"
  "visits-service"
)

echo "  Deleting existing deployments..."
for deployment in "${DEPLOYMENTS[@]}"; do
  kubectl delete deployment "$deployment" -n default --ignore-not-found=true
done

echo "  Waiting 20 seconds for pods to terminate..."
sleep 20

echo "  Applying updated deployments..."
for deployment in "${DEPLOYMENTS[@]}"; do
  if [ -f "$DEPLOYMENTS_DIR/${deployment}.yaml" ]; then
    kubectl apply -f "$DEPLOYMENTS_DIR/${deployment}.yaml"
    echo "    ✓ Applied $deployment"
  else
    echo "    ✗ File not found: $DEPLOYMENTS_DIR/${deployment}.yaml"
  fi
done

echo ""
echo "==========================================="
echo "Redeployment complete!"
echo "==========================================="
echo ""
echo "Current pod status:"
kubectl get pods -n default | grep -E "admin-server|api-gateway|customers|discovery|genai|vets|visits" || echo "  (Pods still initializing...)"
echo ""
echo "Monitor pod startup with:"
echo "  kubectl get pods -w"
echo ""
echo "Check logs if pods fail:"
echo "  kubectl logs <pod-name>"
