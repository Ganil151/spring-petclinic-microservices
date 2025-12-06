#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}      ArgoCD CrashLoop Fixer                  ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo "Date: $(date)"
echo ""

NAMESPACE="argocd"
DEPLOYMENT="argocd-repo-server"

echo -e "${YELLOW}>> [1/2] Patching Liveness/Readiness Probes for $DEPLOYMENT...${NC}"

# Patch to increase timeouts and initial delays
# - initialDelaySeconds: 30 (give it time to start up)
# - timeoutSeconds: 30 (allow slow response)
# - failureThreshold: 5 (allow a few failures before restarting)
if kubectl patch deployment "$DEPLOYMENT" -n "$NAMESPACE" -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "argocd-repo-server",
            "livenessProbe": {
              "initialDelaySeconds": 60,
              "timeoutSeconds": 30,
              "failureThreshold": 5,
              "periodSeconds": 10
            },
            "readinessProbe": {
              "initialDelaySeconds": 30,
              "timeoutSeconds": 30,
              "failureThreshold": 5,
              "periodSeconds": 10
            }
          }
        ]
      }
    }
  }
}'; then
    echo -e "${GREEN}✓ Probes patched successfully${NC}"
else
    echo -e "${RED}✗ Failed to patch probes. Check if deployment exists.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}>> [2/2] Restarting ArgoCD Repo Server...${NC}"
kubectl rollout restart deployment "$DEPLOYMENT" -n "$NAMESPACE"

echo -e "${GREEN}✓ Rollout triggered. Waiting for pod to run...${NC}"
kubectl wait --for=condition=Available deployment/"$DEPLOYMENT" -n "$NAMESPACE" --timeout=120s

echo ""
echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}           Fix Complete                       ${NC}"
echo -e "${YELLOW}==============================================${NC}"
