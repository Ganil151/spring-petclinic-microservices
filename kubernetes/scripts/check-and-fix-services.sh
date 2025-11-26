#!/bin/bash

echo "=========================================="
echo "Kubernetes Services Diagnostic & Fix"
echo "=========================================="
echo ""

# Check if services exist
echo "=== Checking Current Services ==="
kubectl get services
echo ""

# Check specifically for config-server service
echo "=== Checking config-server Service ==="
if kubectl get service config-server &>/dev/null; then
    echo "✓ config-server service EXISTS"
    kubectl get service config-server -o wide
    echo ""
    echo "Service Details:"
    kubectl describe service config-server
else
    echo "✗ config-server service DOES NOT EXIST"
    echo ""
    echo "This is the root cause of all pod failures!"
fi

echo ""
echo "=== Checking discovery-server Service ==="
if kubectl get service discovery-server &>/dev/null; then
    echo "✓ discovery-server service EXISTS"
    kubectl get service discovery-server -o wide
else
    echo "✗ discovery-server service DOES NOT EXIST"
fi

echo ""
echo "=== Checking All Deployments ==="
kubectl get deployments

echo ""
echo "=== Checking if Service YAML files exist ==="
KUBE_DIR="/home/ec2-user/spring-petclinic-microservices/kubernetes"

if [ -d "$KUBE_DIR" ]; then
    echo "Kubernetes directory found: $KUBE_DIR"
    echo ""
    echo "Service files:"
    find "$KUBE_DIR" -name "*service*.yaml" -o -name "*svc*.yaml" 2>/dev/null
    echo ""
    echo "All YAML files:"
    ls -la "$KUBE_DIR"/*.yaml 2>/dev/null || echo "No YAML files found in $KUBE_DIR"
else
    echo "Kubernetes directory not found at $KUBE_DIR"
    echo "Please update KUBE_DIR variable in this script"
fi

echo ""
echo "=========================================="
echo "DIAGNOSIS COMPLETE"
echo "=========================================="
echo ""

# Provide recommendations
echo "=== RECOMMENDATIONS ==="
echo ""

if ! kubectl get service config-server &>/dev/null; then
    echo "1. CREATE config-server Service"
    echo "   The config-server service is missing. You need to create it."
    echo ""
    echo "   Quick fix - run this command:"
    echo "   kubectl expose deployment config-server --port=8888 --target-port=8080 --name=config-server"
    echo ""
fi

if ! kubectl get service discovery-server &>/dev/null; then
    echo "2. CREATE discovery-server Service"
    echo "   The discovery-server service is missing. You need to create it."
    echo ""
    echo "   Quick fix - run this command:"
    echo "   kubectl expose deployment discovery-server --port=8761 --target-port=8761 --name=discovery-server"
    echo ""
fi

echo "3. After creating services, pods should automatically restart and connect successfully"
echo ""
echo "4. To apply all service definitions from YAML files:"
echo "   kubectl apply -f /path/to/kubernetes/services/"
echo ""

echo "=========================================="
