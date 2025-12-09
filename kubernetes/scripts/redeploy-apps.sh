#!/bin/bash

# Script to redeploy all Spring Petclinic microservices with updated DNS configurations
# This fixes the discovery-server FQDN issue and adds resource limits

set -e

echo "==========================================="
echo "Redeploying Spring Petclinic Applications"
echo "==========================================="
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOYMENTS_DIR="$(dirname "$SCRIPT_DIR")/base/deployments"

# List of deployments to redeploy
DEPLOYMENTS=(
  "admin-server"
  "api-gateway"
  "customers-service"
  "discovery-server"
  "genai-service"
  "vets-service"
  "visits-service"
)

# Delete existing deployments and wait for pods to terminate
echo "[1/3] Deleting existing deployments..."
for deployment in "${DEPLOYMENTS[@]}"; do
  echo "  - Deleting $deployment..."
  kubectl delete deployment "$deployment" -n default --ignore-not-found=true
done

# Wait for pods to fully terminate
echo ""
echo "[2/3] Waiting for pods to terminate (30 seconds)..."
sleep 30

# Reapply deployments from the updated manifests
echo ""
echo "[3/3] Applying updated deployments..."
for deployment in "${DEPLOYMENTS[@]}"; do
  echo "  - Applying $deployment..."
  kubectl apply -f "$DEPLOYMENTS_DIR/${deployment}.yaml"
done

echo ""
echo "==========================================="
echo "Redeployment initiated!"
echo "==========================================="
echo ""
echo "Checking pod status..."
kubectl get pods -n default | grep -E "admin-server|api-gateway|customers|discovery|genai|vets|visits"
echo ""
echo "Next steps:"
echo "1. Monitor pod startup: kubectl get pods -w"
echo "2. Check logs if pods fail: kubectl logs <pod-name>"
echo "3. Verify services are healthy: kubectl get svc"
