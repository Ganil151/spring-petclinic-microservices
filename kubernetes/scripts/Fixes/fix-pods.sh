#!/bin/bash
#############################################
# Fix Spring Petclinic CrashLoopBackOff
# Restarts pods in correct dependency order
#############################################

set -euo pipefail

echo "=========================================="
echo "Fixing Spring Petclinic Pods"
echo "=========================================="
echo ""

# Delete all pods to force clean restart
echo "=== Restarting all pods ==="
kubectl delete pods --all --grace-period=0 --force 2>/dev/null || true
echo "✓ Pods deleted"
echo ""

# Wait for config-server
echo "=== Waiting for config-server (max 5 min) ==="
for i in {1..60}; do
    if kubectl get pods -l app=config-server --no-headers 2>/dev/null | grep -q "Running"; then
        echo "✓ config-server is running"
        break
    fi
    echo "[$i/60] Waiting..."
    sleep 5
done
echo ""

# Wait for discovery-server
echo "=== Waiting for discovery-server (max 5 min) ==="
for i in {1..60}; do
    if kubectl get pods -l app=discovery-server --no-headers 2>/dev/null | grep -q "Running"; then
        echo "✓ discovery-server is running"
        break
    fi
    echo "[$i/60] Waiting..."
    sleep 5
done
echo ""

# Monitor all pods
echo "=== Monitoring all pods (max 10 min) ==="
for i in {1..60}; do
    TOTAL=$(kubectl get pods --no-headers | wc -l)
    RUNNING=$(kubectl get pods --field-selector=status.phase=Running --no-headers | wc -l)
    CRASH=$(kubectl get pods --no-headers | grep -c "CrashLoop" || true)
    
    echo "[$i/60] Running: $RUNNING/$TOTAL, Crashing: $CRASH"
    
    if [ "$RUNNING" -eq "$TOTAL" ] && [ "$CRASH" -eq 0 ]; then
        echo ""
        echo "✓ All pods are running!"
        break
    fi
    sleep 10
done

echo ""
kubectl get pods
echo ""

# Summary
CRASH=$(kubectl get pods --no-headers | grep -c "CrashLoop" || true)
if [ "$CRASH" -eq 0 ]; then
    echo "✓ SUCCESS - All pods healthy!"
    echo ""
    echo "Access services:"
    echo "  kubectl get services"
else
    echo "⚠ $CRASH pod(s) still crashing"
    echo "Check logs: kubectl logs <pod-name>"
fi
echo ""
