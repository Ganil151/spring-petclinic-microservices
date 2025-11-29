#!/bin/bash

# Script to check current cluster health status
# Provides comprehensive view of all pods and their states

set -e

echo "=== Kubernetes Cluster Health Check ==="
echo ""

echo "Step 1: Overall Pod Status"
echo "--------------------------"
kubectl get pods
echo ""

echo "Step 2: Pod Status Summary"
echo "--------------------------"
echo "Running pods:"
kubectl get pods --field-selector=status.phase=Running --no-headers | wc -l

echo "Pending pods:"
kubectl get pods --field-selector=status.phase=Pending --no-headers | wc -l

echo "Failed pods:"
kubectl get pods --field-selector=status.phase=Failed --no-headers | wc -l

echo "CrashLoopBackOff pods:"
kubectl get pods | grep -c "CrashLoopBackOff" || echo "0"

echo ""

echo "Step 3: Deployment Status"
echo "-------------------------"
kubectl get deployments
echo ""

echo "Step 4: Pods by Node Distribution"
echo "----------------------------------"
echo ""
echo "Frontend Node (k8s-ap-server):"
kubectl get pods -o wide --field-selector spec.nodeName=k8s-ap-server --no-headers | wc -l | xargs echo "Pod count:"
kubectl get pods -o wide --field-selector spec.nodeName=k8s-ap-server

echo ""
echo "Backend Node (k8s-as-server):"
kubectl get pods -o wide --field-selector spec.nodeName=k8s-as-server --no-headers | wc -l | xargs echo "Pod count:"
kubectl get pods -o wide --field-selector spec.nodeName=k8s-as-server

echo ""
echo "Step 5: Service Status"
echo "----------------------"
kubectl get services
echo ""

echo "Step 6: Recent Events (last 15)"
echo "--------------------------------"
kubectl get events --sort-by='.lastTimestamp' | tail -15
echo ""

echo "=== Health Summary ==="
echo ""
RUNNING=$(kubectl get pods --field-selector=status.phase=Running --no-headers | wc -l)
TOTAL=$(kubectl get pods --no-headers | wc -l)
echo "Pods Running: $RUNNING / $TOTAL"

READY=$(kubectl get pods --no-headers | grep -E "Running.*1/1|Running.*2/2" | wc -l)
echo "Pods Ready: $READY / $TOTAL"

if [ "$RUNNING" -eq "$TOTAL" ] && [ "$READY" -eq "$TOTAL" ]; then
    echo ""
    echo "✅ Cluster is healthy! All pods are running and ready."
else
    echo ""
    echo "⚠️ Some pods may still have issues. Check details above."
fi
