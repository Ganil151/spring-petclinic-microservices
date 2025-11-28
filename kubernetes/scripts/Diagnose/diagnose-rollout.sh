#!/bin/bash

# Script to diagnose stuck rollout issues
# Run this to see why pods aren't starting

set -e

echo "=== Diagnosing Stuck Rollout Issues ==="
echo ""

echo "1. Current Deployment Status:"
echo "-----------------------------"
kubectl get deployments
echo ""

echo "2. Pod Status (including pending/error):"
echo "----------------------------------------"
kubectl get pods -o wide
echo ""

echo "3. Recent Events (last 20):"
echo "--------------------------"
kubectl get events --sort-by='.lastTimestamp' | tail -20
echo ""

echo "4. Checking API Gateway Pods Specifically:"
echo "-----------------------------------------"
API_GATEWAY_PODS=$(kubectl get pods -l app=api-gateway --no-headers | awk '{print $1}')

for pod in $API_GATEWAY_PODS; do
    echo ""
    echo "Pod: $pod"
    echo "Status:"
    kubectl get pod $pod -o wide
    echo ""
    echo "Describe (last 15 lines):"
    kubectl describe pod $pod | tail -15
    echo ""
done

echo ""
echo "5. Checking Node Resources:"
echo "--------------------------"
kubectl top nodes || echo "Metrics server not available"
echo ""

echo "6. Node Labels (checking nodeSelector compatibility):"
echo "-----------------------------------------------------"
kubectl get nodes --show-labels
echo ""

echo "7. Checking if pods are pending:"
echo "-------------------------------"
PENDING_PODS=$(kubectl get pods --field-selector=status.phase=Pending --no-headers 2>/dev/null)
if [ -n "$PENDING_PODS" ]; then
    echo "Found pending pods:"
    echo "$PENDING_PODS"
    echo ""
    echo "Describing first pending pod:"
    FIRST_PENDING=$(echo "$PENDING_PODS" | head -1 | awk '{print $1}')
    kubectl describe pod $FIRST_PENDING | grep -A 10 "Events:"
else
    echo "No pending pods found"
fi

echo ""
echo "=== Common Issues to Check ==="
echo ""
echo "If you see 'FailedScheduling' errors:"
echo "  → Check if nodeSelector labels match node labels"
echo "  → Verify nodes have enough resources"
echo ""
echo "If you see 'ImagePullBackOff' errors:"
echo "  → Check image names and tags"
echo "  → Verify internet connectivity from nodes"
echo ""
echo "If you see 'CrashLoopBackOff' errors:"
echo "  → Check pod logs: kubectl logs <pod-name>"
echo "  → Check resource limits"
echo ""
echo "To cancel the stuck rollout and rollback:"
echo "  kubectl rollout undo deployment/api-gateway"
