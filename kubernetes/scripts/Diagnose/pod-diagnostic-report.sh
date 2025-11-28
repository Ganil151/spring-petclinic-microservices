#!/bin/bash

echo "=========================================="
echo "Kubernetes Pods Diagnostic Report"
echo "=========================================="
echo ""
date
echo ""

# List of failing pods (excluding config-server which is now running)
FAILING_PODS=(
    "admin-server-58b55b488c-vj99r"
    "api-gateway-657589fc9-qjkcw"
    "customers-service-c9c77db4b-rgcxz"
    "discovery-server-5588c878b4-7ljcx"
    "genai-service-67d7bc9557-xsvjn"
    "vets-service-59cb5f6c95-r9cj6"
    "visits-service-dfbf9cdcd-gtwnf"
)

# Function to diagnose a single pod
diagnose_pod() {
    local POD_NAME=$1
    
    echo "=========================================="
    echo "POD: $POD_NAME"
    echo "=========================================="
    
    # Get pod status
    echo ""
    echo "--- Current Status ---"
    kubectl get pod $POD_NAME -o wide
    
    # Get last termination reason
    echo ""
    echo "--- Last Termination Reason ---"
    kubectl get pod $POD_NAME -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null
    echo ""
    kubectl get pod $POD_NAME -o jsonpath='{.status.containerStatuses[0].lastState.terminated.message}' 2>/dev/null
    echo ""
    
    # Check for OOMKilled
    echo ""
    echo "--- Checking for OOM (Out of Memory) ---"
    kubectl describe pod $POD_NAME | grep -i "oom\|killed" || echo "No OOM detected"
    
    # Get recent logs (last 50 lines)
    echo ""
    echo "--- Recent Logs (Last 50 lines) ---"
    kubectl logs $POD_NAME --tail=50 2>/dev/null || echo "No logs available yet"
    
    # Get previous logs if container restarted
    echo ""
    echo "--- Previous Container Logs (Last 50 lines) ---"
    kubectl logs $POD_NAME --previous --tail=50 2>/dev/null || echo "No previous logs available"
    
    # Get pod events
    echo ""
    echo "--- Recent Events ---"
    kubectl describe pod $POD_NAME | grep -A 15 "Events:" | tail -15
    
    # Get resource requests/limits
    echo ""
    echo "--- Resource Configuration ---"
    kubectl get pod $POD_NAME -o jsonpath='{.spec.containers[0].resources}' | jq '.' 2>/dev/null || kubectl get pod $POD_NAME -o jsonpath='{.spec.containers[0].resources}'
    echo ""
    
    # Get environment variables
    echo ""
    echo "--- Environment Variables ---"
    kubectl get pod $POD_NAME -o jsonpath='{.spec.containers[0].env[*].name}' 2>/dev/null
    echo ""
    
    echo ""
    echo "=========================================="
    echo ""
}

# Diagnose each failing pod
for pod in "${FAILING_PODS[@]}"; do
    diagnose_pod "$pod"
    echo ""
    echo ""
done

# Summary section
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""

echo "--- All Pod Statuses ---"
kubectl get pods -o wide

echo ""
echo "--- Node Resources ---"
kubectl describe nodes | grep -A 10 "Allocated resources"

echo ""
echo "--- Services ---"
kubectl get services

echo ""
echo "--- ConfigMaps ---"
kubectl get configmaps

echo ""
echo "--- Checking if config-server is accessible ---"
CONFIG_SERVER_IP=$(kubectl get service config-server -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$CONFIG_SERVER_IP" ]; then
    echo "Config Server Service IP: $CONFIG_SERVER_IP"
    kubectl run test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- curl -s http://config-server:8888/actuator/health 2>/dev/null || echo "Config server not reachable"
else
    echo "Config server service not found!"
fi

echo ""
echo "--- Checking if discovery-server is accessible ---"
DISCOVERY_SERVER_IP=$(kubectl get service discovery-server -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ -n "$DISCOVERY_SERVER_IP" ]; then
    echo "Discovery Server Service IP: $DISCOVERY_SERVER_IP"
else
    echo "Discovery server service not found!"
fi

echo ""
echo "=========================================="
echo "Diagnostic Report Complete"
echo "=========================================="