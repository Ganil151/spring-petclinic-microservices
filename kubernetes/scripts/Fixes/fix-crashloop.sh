#!/bin/bash

# Script to fix CrashLoopBackOff issues
# Strategy: Clean up, restart in dependency order

set -e

echo "=== Fixing CrashLoopBackOff Issues ==="
echo ""

echo "Step 1: Cleaning up old/failed pods..."
echo "---------------------------------------"

# Delete all crashlooping pods to get fresh starts
echo "Deleting failed pods for clean restart..."

# Scale down all services first
echo "Scaling down all services..."
kubectl scale deployment --all --replicas=0

echo "Waiting for pods to terminate..."
sleep 30

echo "✓ All pods scaled down"
echo ""

echo "Step 2: Starting services in dependency order..."
echo "-------------------------------------------------"

# Order: config-server → discovery-server → business services → gateway/admin

echo "Starting Config Server (1/5)..."
kubectl scale deployment config-server --replicas=2
echo "Waiting for config-server to be ready..."
kubectl wait --for=condition=ready pod -l app=config-server --timeout=300s || echo "Config server may still be starting..."
sleep 30

echo ""
echo "Starting Discovery Server (2/5)..."
kubectl scale deployment discovery-server --replicas=2
echo "Waiting for discovery-server to be ready..."
kubectl wait --for=condition=ready pod -l app=discovery-server --timeout=300s || echo "Discovery server may still be starting..."
sleep 30

echo ""
echo "Starting Business Services (3/5)..."
kubectl scale deployment customers-service --replicas=2
kubectl scale deployment vets-service --replicas=2
kubectl scale deployment visits-service --replicas=2
echo "Waiting for business services to start..."
sleep 45

echo ""
echo "Starting API Gateway (4/5)..."
kubectl scale deployment api-gateway --replicas=2
sleep 30

echo ""
echo "Starting Admin & Optional Services (5/5)..."
kubectl scale deployment admin-server --replicas=2
kubectl scale deployment genai-service --replicas=1
sleep 20

echo ""
echo "=== Deployment Status ==="
kubectl get deployments
echo ""

echo "=== Pod Status ==="
kubectl get pods
echo ""

echo "=== Checking for Issues ==="
echo ""
CRASH_COUNT=$(kubectl get pods | grep -c "CrashLoopBackOff" || true)
echo "Pods still crashing: $CRASH_COUNT"

if [ "$CRASH_COUNT" -gt 0 ]; then
    echo ""
    echo "⚠ Some pods are still crashing. Run diagnose-crashloop.sh for details"
    echo "  ./kubernetes/scripts/diagnose-crashloop.sh"
else
    echo ""
    echo "✓ All pods appear to be starting successfully!"
fi

echo ""
echo "Monitor status with:"
echo "  kubectl get pods -w"
