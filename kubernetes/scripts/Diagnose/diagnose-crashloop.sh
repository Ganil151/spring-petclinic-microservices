#!/bin/bash

# Script to diagnose CrashLoopBackOff issues
# Checks pod logs and common failure patterns

set -e

echo "=== Diagnosing CrashLoopBackOff Issues ==="
echo ""

# Get all crashing pods (including CrashLoopBackOff)
echo "Step 1: Identifying crashing pods..."
echo "-------------------------------------"

# CrashLoopBackOff pods still show as Running phase, so check STATUS column instead
CRASHING_PODS=$(kubectl get pods --no-headers 2>/dev/null | grep -E "CrashLoopBackOff|Error|ImagePullBackOff|ErrImagePull|Pending" | awk '{print $1}')

if [ -z "$CRASHING_PODS" ]; then
    echo "No crashing pods found!"
    echo ""
    echo "Current pod status:"
    kubectl get pods
    exit 0
fi

echo "Found crashing pods:"
kubectl get pods | grep -E "CrashLoopBackOff|Error|ImagePullBackOff"
echo ""

# Check config-server first (it's the foundation)
echo "Step 2: Checking Config Server (foundation service)..."
echo "-------------------------------------------------------"
CONFIG_PODS=$(kubectl get pods -l app=config-server --no-headers | awk '{print $1}' | head -1)
if [ -n "$CONFIG_PODS" ]; then
    echo "Config Server Pod: $CONFIG_PODS"
    echo ""
    echo "Last 30 log lines:"
    kubectl logs $CONFIG_PODS --tail=30 2>&1 || echo "Could not get logs"
    echo ""
    echo "Pod describe (Events):"
    kubectl describe pod $CONFIG_PODS | grep -A 20 "Events:"
fi
echo ""

# Check discovery-server
echo "Step 3: Checking Discovery Server..."
echo "-------------------------------------"
DISCOVERY_PODS=$(kubectl get pods -l app=discovery-server --no-headers | awk '{print $1}' | head -1)
if [ -n "$DISCOVERY_PODS" ]; then
    echo "Discovery Server Pod: $DISCOVERY_PODS"
    echo ""
    echo "Last 30 log lines:"
    kubectl logs $DISCOVERY_PODS --tail=30 2>&1 || echo "Could not get logs"
    echo ""
fi

# Check one business service
echo "Step 4: Checking Sample Business Service (customers)..."
echo "--------------------------------------------------------"
CUSTOMER_PODS=$(kubectl get pods -l app=customers-service --no-headers | awk '{print $1}' | head -1)
if [ -n "$CUSTOMER_PODS" ]; then
    echo "Customers Service Pod: $CUSTOMER_PODS"
    echo ""
    echo "Last 30 log lines:"
    kubectl logs $CUSTOMER_PODS --tail=30 2>&1 || echo "Could not get logs"
    echo ""
fi

# Check API Gateway
echo "Step 5: Checking API Gateway..."
echo "-------------------------------"
GATEWAY_PODS=$(kubectl get pods -l app=api-gateway --no-headers | awk '{print $1}' | head -1)
if [ -n "$GATEWAY_PODS" ]; then
    echo "API Gateway Pod: $GATEWAY_PODS"
    echo ""
    echo "Last 30 log lines:"
    kubectl logs $GATEWAY_PODS --tail=30 2>&1 || echo "Could not get logs"
    echo ""
fi

# Check for common issues
echo "Step 6: Checking for Common Issues..."
echo "--------------------------------------"
echo ""

echo "Resource usage on nodes:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
echo ""

echo "Pending pods (scheduling issues):"
kubectl get pods --field-selector=status.phase=Pending --no-headers | wc -l | xargs echo "Count:"
echo ""

echo "Node status:"
kubectl get nodes
echo ""

echo "=== Common CrashLoopBackOff Causes ==="
echo ""
echo "1. Config Server not ready → All services fail"
echo "2. Wrong environment variables (SPRING_CONFIG_IMPORT)"
echo "3. Resource limits too low (OOMKilled)"
echo "4. Network connectivity issues"
echo "5. Image pull errors"
echo ""
echo "=== Recommended Actions ==="
echo ""
echo "1. Check logs above for Java exceptions"
echo "2. Look for 'Connection refused' errors (config/discovery server not ready)"
echo "3. Check for 'OOMKilled' (increase memory limits)"
echo "4. Verify nodeSelector matches node labels"
echo ""
echo "To get detailed logs for a specific pod:"
echo "  kubectl logs <pod-name>"
echo "  kubectl logs <pod-name> --previous  # For previous crash"
echo "  kubectl describe pod <pod-name>"
