#!/bin/bash

#############################################
# Fix Spring Petclinic CrashLoopBackOff
# Ensures services start in correct order
#############################################

set -e

echo "=========================================="
echo "Fixing Spring Petclinic CrashLoopBackOff"
echo "=========================================="
echo ""
date
echo ""

#############################################
# Step 1: Check Current Pod Status
#############################################

echo "=== Current Pod Status ==="
echo ""
kubectl get pods
echo ""

#############################################
# Step 2: Check Service Dependencies
#############################################

echo "=== Checking Service Dependencies ==="
echo ""

echo "Services:"
kubectl get services
echo ""

# Check if config-server service exists
if kubectl get service config-server &>/dev/null; then
    echo "✓ config-server service exists"
else
    echo "✗ config-server service is MISSING"
    echo "  This is why pods are crashing!"
fi

# Check if discovery-server service exists
if kubectl get service discovery-server &>/dev/null; then
    echo "✓ discovery-server service exists"
else
    echo "✗ discovery-server service is MISSING"
fi

echo ""

#############################################
# Step 3: Check Config Server Pod
#############################################

echo "=== Checking Config Server ==="
echo ""

CONFIG_POD=$(kubectl get pods -l app=config-server --no-headers 2>/dev/null | head -1 | awk '{print $1}')

if [ -n "$CONFIG_POD" ]; then
    CONFIG_STATUS=$(kubectl get pod "$CONFIG_POD" --no-headers | awk '{print $3}')
    echo "Config Server Pod: $CONFIG_POD"
    echo "Status: $CONFIG_STATUS"
    
    if [ "$CONFIG_STATUS" != "Running" ]; then
        echo ""
        echo "⚠ Config server is not running yet"
        echo "Checking logs..."
        kubectl logs "$CONFIG_POD" --tail=20 || echo "No logs available yet"
    fi
else
    echo "✗ Config server pod not found"
fi

echo ""

#############################################
# Step 4: Restart Deployment Order
#############################################

echo "=== Restarting in Correct Order ==="
echo ""

echo "Spring Petclinic services must start in this order:"
echo "  1. config-server (provides configuration)"
echo "  2. discovery-server (service registry)"
echo "  3. All other services"
echo ""

# Delete all pods to force restart in order
echo "Deleting all application pods..."
kubectl delete pods --all --grace-period=0 --force 2>/dev/null || true

echo ""
echo "Waiting 10 seconds..."
sleep 10

echo ""
echo "New pods starting:"
kubectl get pods
echo ""

#############################################
# Step 5: Wait for Config Server
#############################################

echo "=== Waiting for Config Server ==="
echo ""

for i in {1..30}; do
    CONFIG_POD=$(kubectl get pods -l app=config-server --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -n "$CONFIG_POD" ]; then
        CONFIG_STATUS=$(kubectl get pod "$CONFIG_POD" --no-headers | awk '{print $3}')
        
        if [ "$CONFIG_STATUS" = "Running" ]; then
            echo "✓ Config server is running!"
            break
        fi
        
        echo "[$i/30] Config server status: $CONFIG_STATUS, waiting..."
    else
        echo "[$i/30] Waiting for config server pod to be created..."
    fi
    
    sleep 5
done

echo ""

#############################################
# Step 6: Wait for Discovery Server
#############################################

echo "=== Waiting for Discovery Server ==="
echo ""

for i in {1..30}; do
    DISCOVERY_POD=$(kubectl get pods -l app=discovery-server --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    
    if [ -n "$DISCOVERY_POD" ]; then
        DISCOVERY_STATUS=$(kubectl get pod "$DISCOVERY_POD" --no-headers | awk '{print $3}')
        
        if [ "$DISCOVERY_STATUS" = "Running" ]; then
            echo "✓ Discovery server is running!"
            break
        fi
        
        echo "[$i/30] Discovery server status: $DISCOVERY_STATUS, waiting..."
    else
        echo "[$i/30] Waiting for discovery server pod to be created..."
    fi
    
    sleep 5
done

echo ""

#############################################
# Step 7: Monitor All Pods
#############################################

echo "=== Monitoring All Pods ==="
echo ""

echo "Waiting for all pods to be running (this may take 5-10 minutes)..."
echo ""

for i in {1..60}; do
    TOTAL_PODS=$(kubectl get pods --no-headers 2>/dev/null | wc -l)
    RUNNING_PODS=$(kubectl get pods --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    CRASH_PODS=$(kubectl get pods --no-headers 2>/dev/null | grep -c "CrashLoopBackOff" || true)
    
    echo "[$i/60] Pods: $RUNNING_PODS/$TOTAL_PODS running, $CRASH_PODS crashing"
    
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$CRASH_PODS" -eq 0 ]; then
        echo ""
        echo "✓ All pods are running!"
        break
    fi
    
    sleep 10
done

echo ""
kubectl get pods
echo ""

#############################################
# Summary
#############################################

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

CRASH_PODS=$(kubectl get pods --no-headers 2>/dev/null | grep -c "CrashLoopBackOff" || true)
RUNNING_PODS=$(kubectl get pods --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
TOTAL_PODS=$(kubectl get pods --no-headers 2>/dev/null | wc -l)

if [ "$CRASH_PODS" -eq 0 ] && [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
    echo "✓ All pods are healthy!"
    echo ""
    echo "Access your application:"
    echo "  kubectl get services"
    echo "  kubectl port-forward service/api-gateway 8080:8080"
else
    echo "⚠ Some pods still have issues:"
    echo "  Running: $RUNNING_PODS/$TOTAL_PODS"
    echo "  Crashing: $CRASH_PODS"
    echo ""
    echo "Check logs of failing pods:"
    kubectl get pods | grep -E "CrashLoop|Error" | awk '{print $1}' | while read pod; do
        echo "  kubectl logs $pod"
    done
    echo ""
    echo "Common issues:"
    echo "  1. Config server not ready - wait longer"
    echo "  2. Missing services - check: kubectl get services"
    echo "  3. Resource limits - check: kubectl describe pod <pod-name>"
fi

echo ""
echo "=========================================="
