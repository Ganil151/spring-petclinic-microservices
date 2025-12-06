#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}      Kubernetes Auto-Fix Tool                ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo "Date: $(date)"
echo ""

# 1. Fix Calico CNI Issues
echo -e "${YELLOW}>> [1/3] Fixing Calico CNI Networking...${NC}"
echo "Restarting calico-node pods to refresh BGP peering..."
kubectl -n kube-system delete pods -l k8s-app=calico-node
echo -e "${GREEN}✓ Calico pods restarted. Waiting for them to stabilize...${NC}"
kubectl -n kube-system wait --for=condition=Ready pod -l k8s-app=calico-node --timeout=60s || true
echo ""

# 2. Fix Resource Constraints (Admin Server)
echo -e "${YELLOW}>> [2/3] Patching Resource Limits...${NC}"
if kubectl get deployment admin-server &>/dev/null; then
    echo "Patching admin-server to reduce CPU requests..."
    # Patch CPU request to 100m to allow scheduling on nodes with limited capacity
    kubectl patch deployment admin-server -p '{"spec":{"template":{"spec":{"containers":[{"name":"admin-server","resources":{"requests":{"cpu":"100m"}}}]}}}}'
    echo -e "${GREEN}✓ admin-server patched${NC}"
else
    echo "admin-server deployment not found, skipping."
fi
echo ""

# 3. Restart Applications to recover from network partition
echo -e "${YELLOW}>> [3/3] Restarting Applications...${NC}"

# ArgoCD
if kubectl get namespace argocd &>/dev/null; then
    echo "Restarting ArgoCD components..."
    kubectl -n argocd rollout restart deployment argocd-repo-server
    kubectl -n argocd rollout restart deployment argocd-server
fi

# Microservices
echo "Restarting Spring Petclinic Microservices..."
DEPLOYMENTS=$(kubectl get deployments -o jsonpath='{.items[*].metadata.name}')

for dep in $DEPLOYMENTS; do
    echo "Restarting $dep..."
    kubectl rollout restart deployment "$dep"
done

echo -e "${GREEN}✓ Rollout restarts triggered${NC}"
echo ""

echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}           Fixes Applied                      ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo "Please wait 1-2 minutes for pods to restart, then run k8s_diagnostic.sh again."
