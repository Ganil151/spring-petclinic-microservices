#!/bin/bash
#############################################
# EKS Networking & Config Server Diagnostic
# Checks CNI status and Config Server health
#############################################

set -e

echo "=========================================="
echo "EKS Diagnostic: CNI & Config Server"
echo "=========================================="
echo ""

# 1. Check CNI (Amazon VPC CNI)
echo "=== 1. Checking Amazon VPC CNI ==="
echo ""
VPC_CNI_PODS=$(kubectl get pods -n kube-system -l k8s-app=aws-node --no-headers 2>/dev/null | wc -l)
VPC_CNI_READY=$(kubectl get pods -n kube-system -l k8s-app=aws-node --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

if [ "$VPC_CNI_PODS" -gt 0 ]; then
    echo "✓ Amazon VPC CNI found ($VPC_CNI_READY/$VPC_CNI_PODS running)"
    kubectl get pods -n kube-system -l k8s-app=aws-node -o wide
else
    echo "✗ Amazon VPC CNI NOT found"
fi
echo ""

# 2. Check CoreDNS
echo "=== 2. Checking CoreDNS ==="
echo ""
kubectl get pods -n kube-system -l k8s-app=kube-dns
echo ""

# 3. Check Config Server Pod Details
echo "=== 3. Config Server Diagnostics ==="
echo ""
CONFIG_POD=$(kubectl get pods -l app=config-server --no-headers | awk '{print $1}')

if [ -n "$CONFIG_POD" ]; then
    echo "Pod: $CONFIG_POD"
    echo "Status: $(kubectl get pod $CONFIG_POD -o jsonpath='{.status.phase}')"
    echo "Ready: $(kubectl get pod $CONFIG_POD -o jsonpath='{.status.containerStatuses[0].ready}')"
    echo "Restarts: $(kubectl get pod $CONFIG_POD -o jsonpath='{.status.containerStatuses[0].restartCount}')"
    echo ""
    
    echo "--- Recent Events ---"
    kubectl get events --field-selector involvedObject.name=$CONFIG_POD --sort-by='.lastTimestamp' | tail -5
    echo ""
    
    echo "--- Last 20 Log Lines ---"
    kubectl logs $CONFIG_POD --tail=20
    echo ""
    
    echo "--- Previous Logs (if restarted) ---"
    kubectl logs $CONFIG_POD --previous --tail=20 2>/dev/null || echo "No previous logs"
else
    echo "✗ Config Server pod not found"
fi

echo ""
echo "=========================================="
