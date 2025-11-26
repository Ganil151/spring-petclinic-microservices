#!/bin/bash
#############################################
# Check Config Server Logs
# Diagnoses why config-server keeps restarting
#############################################

set -euo pipefail

echo "=========================================="
echo "Config Server Diagnostic"
echo "=========================================="
echo ""

CONFIG_POD=$(kubectl get pods -l app=config-server --no-headers | awk '{print $1}')

if [ -z "$CONFIG_POD" ]; then
    echo "✗ Config server pod not found"
    exit 1
fi

echo "Config Server Pod: $CONFIG_POD"
echo ""

# Show pod status
echo "=== Pod Status ==="
kubectl get pod "$CONFIG_POD"
echo ""

# Show pod description
echo "=== Pod Events ==="
kubectl describe pod "$CONFIG_POD" | grep -A 20 "Events:"
echo ""

# Show logs
echo "=== Recent Logs ==="
kubectl logs "$CONFIG_POD" --tail=50 || echo "No logs available yet"
echo ""

# Check if it's a readiness/liveness probe issue
echo "=== Checking Probes ==="
kubectl get pod "$CONFIG_POD" -o jsonpath='{.spec.containers[0].livenessProbe}' | jq '.' 2>/dev/null || echo "No liveness probe"
echo ""
kubectl get pod "$CONFIG_POD" -o jsonpath='{.spec.containers[0].readinessProbe}' | jq '.' 2>/dev/null || echo "No readiness probe"
echo ""

# Suggested fixes
echo "=========================================="
echo "Common Issues & Fixes"
echo "=========================================="
echo ""
echo "1. If config-server can't find config repo:"
echo "   - Check SPRING_CLOUD_CONFIG_SERVER_GIT_URI env var"
echo "   - Ensure git repo is accessible"
echo ""
echo "2. If readiness probe failing:"
echo "   - Increase initialDelaySeconds"
echo "   - Check /actuator/health endpoint"
echo ""
echo "3. If memory issues:"
echo "   - Add resource limits to deployment"
echo ""
echo "Check full logs:"
echo "  kubectl logs $CONFIG_POD -f"
echo ""
