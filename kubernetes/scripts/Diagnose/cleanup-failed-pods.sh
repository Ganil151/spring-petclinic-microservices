#!/bin/bash

# Script to clean up old/failed pods and deployments
# Helps resolve stuck CrashLoopBackOff issues

set -e

echo "=== Cleaning Up Failed Pods ==="
echo ""

echo "Current pod status:"
kubectl get pods
echo ""

read -p "Do you want to delete all CrashLoopBackOff pods? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Step 1: Deleting CrashLoopBackOff pods..."
echo "-----------------------------------------"

CRASH_PODS=$(kubectl get pods --no-headers | grep "CrashLoopBackOff" | awk '{print $1}')

if [ -z "$CRASH_PODS" ]; then
    echo "No CrashLoopBackOff pods found."
else
    for pod in $CRASH_PODS; do
        echo "Deleting $pod..."
        kubectl delete pod $pod --grace-period=0 --force 2>/dev/null || kubectl delete pod $pod
    done
    echo "✓ Deleted all CrashLoopBackOff pods"
fi

echo ""
echo "Step 2: Waiting for new pods to start..."
echo "-----------------------------------------"
sleep 10

echo ""
echo "Current pod status:"
kubectl get pods
echo ""

echo "Step 3: Checking for remaining issues..."
echo "-----------------------------------------"
CRASH_COUNT=$(kubectl get pods | grep -c "CrashLoopBackOff" || true)

if [ "$CRASH_COUNT" -gt 0 ]; then
    echo "⚠️ Still have $CRASH_COUNT pods crashing"
    echo ""
    echo "Next steps:"
    echo "1. Check logs: kubectl logs <pod-name>"
    echo "2. Run full restart: ./fix-crashloop.sh"
else
    echo "✓ No CrashLoopBackOff pods detected!"
fi

echo ""
echo "Monitor with: kubectl get pods -w"
