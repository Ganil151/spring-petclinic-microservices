#!/bin/bash
#############################################
# K8s Cluster Diagnostic
# Quick health check for master and worker
#############################################

set -euo pipefail

echo "=========================================="
echo "K8s Cluster Diagnostic"
echo "=========================================="
echo ""

# Check kubectl
if ! kubectl version &>/dev/null; then
    echo "✗ kubectl not configured"
    echo "Run: bash setup-k8s-master.sh"
    exit 1
fi

# Nodes
echo "=== Nodes ==="
kubectl get nodes -o wide
NOT_READY=$(kubectl get nodes --no-headers | grep -c "NotReady" || true)
echo ""

# System Pods
echo "=== System Pods ==="
kubectl get pods -n kube-system
PENDING=$(kubectl get pods -n kube-system --field-selector=status.phase=Pending --no-headers | wc -l)
FAILED=$(kubectl get pods -n kube-system --no-headers | grep -cE "Error|CrashLoop" || true)
echo ""

# Application Pods
echo "=== Application Pods ==="
kubectl get pods
APP_CRASH=$(kubectl get pods --no-headers | grep -c "CrashLoop" || true)
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
ISSUES=$((NOT_READY + PENDING + FAILED + APP_CRASH))

if [ "$ISSUES" -eq 0 ]; then
    echo "✓ Cluster is healthy!"
else
    echo "⚠ Found $ISSUES issue(s):"
    [ "$NOT_READY" -gt 0 ] && echo "  - $NOT_READY node(s) NotReady"
    [ "$PENDING" -gt 0 ] && echo "  - $PENDING system pod(s) Pending"
    [ "$FAILED" -gt 0 ] && echo "  - $FAILED system pod(s) Failed"
    [ "$APP_CRASH" -gt 0 ] && echo "  - $APP_CRASH app pod(s) Crashing"
fi
echo ""
