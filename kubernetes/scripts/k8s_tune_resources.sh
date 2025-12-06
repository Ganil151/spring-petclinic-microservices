#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}      Kubernetes Resource Tuner               ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo "Date: $(date)"
echo ""

# Namespace to tune
NAMESPACE="default"

echo -e "${YELLOW}>> Reducing CPU Requests for all deployments in '${NAMESPACE}' namespace...${NC}"

# Get list of deployments
DEPLOYMENTS=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

if [ -z "$DEPLOYMENTS" ]; then
    echo -e "${RED}No deployments found in namespace $NAMESPACE${NC}"
    exit 1
fi

for dep in $DEPLOYMENTS; do
    echo -n "Tuning $dep... "
    # Set CPU request to 50m (0.05 vCPU) to fit many pods on limited nodes
    if kubectl set resources deployment "$dep" -n "$NAMESPACE" --requests=cpu=50m &>/dev/null; then
        echo -e "${GREEN}✓ Set cpu=50m${NC}"
    else
        echo -e "${RED}✗ Failed to update${NC}"
    fi
done

echo ""
echo -e "${YELLOW}>> Verifying rollout status...${NC}"
kubectl get pods -n "$NAMESPACE" | grep Pending || true

echo -e "\n${GREEN}Resource tuning complete. Pods should start scheduling shortly.${NC}"
echo -e "${YELLOW}Note: Applications may start slower due to reduced CPU.${NC}"
echo -e "${YELLOW}==============================================${NC}"
