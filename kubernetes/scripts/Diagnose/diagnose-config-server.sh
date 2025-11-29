#!/bin/bash

# Script to check config-server logs and health
# Config-server is the foundation - if it fails, everything fails

set -e

echo "=== Config Server Diagnostic ==="
echo ""

echo "Step 1: Config Server Pod Status"
echo "---------------------------------"
kubectl get pods -l app=config-server
echo ""

echo "Step 2: Getting Config Server Logs"
echo "-----------------------------------"
CONFIG_POD=$(kubectl get pods -l app=config-server --no-headers | head -1 | awk '{print $1}')

if [ -n "$CONFIG_POD" ]; then
    echo "Checking pod: $CONFIG_POD"
    echo ""
    echo "Last 50 lines of logs:"
    echo "----------------------"
    kubectl logs $CONFIG_POD --tail=50
    echo ""
    echo ""
    echo "Previous crash logs (if available):"
    echo "------------------------------------"
    kubectl logs $CONFIG_POD --previous --tail=50 2>/dev/null || echo "No previous logs available"
    echo ""
fi

echo "Step 3: Config Server Pod Description"
echo "--------------------------------------"
kubectl describe pod $CONFIG_POD | grep -A 30 "Events:"
echo ""

echo "Step 4: Checking Health Probe Configuration"
echo "--------------------------------------------"
kubectl get deployment config-server -o yaml | grep -A 10 "livenessProbe:\|readinessProbe:"
echo ""

echo "Step 5: Checking if Config Server Service is accessible"
echo "--------------------------------------------------------"
kubectl get svc config-server
echo ""

echo "=== Common Config Server Issues ==="
echo ""
echo "1. Git repository unreachable (check SPRING_CLOUD_CONFIG_SERVER_GIT_URI)"
echo "2. Health check timeout too short (needs more time to start)"
echo "3. Memory limits too low"
echo "4. Network connectivity issues"
echo ""
