#!/bin/bash

#############################################
# Deploy Spring Petclinic to K3s
#############################################

set -e

echo "=========================================="
echo "Deploying Spring Petclinic to K3s"
echo "=========================================="
echo ""
date
echo ""

# Configuration
NAMESPACE="petclinic"
KUBE_DIR="$HOME/spring-petclinic-microservices/kubernetes/deployments"

# Check if kubectl is configured
if ! kubectl cluster-info &>/dev/null; then
    echo "ERROR: kubectl is not configured"
    echo "Please run the k3s_server.sh script first"
    exit 1
fi

echo "✓ kubectl is configured"
echo ""

# Check if deployments directory exists
if [ ! -d "$KUBE_DIR" ]; then
    echo "ERROR: Deployments directory not found: $KUBE_DIR"
    echo "Please clone the repository first:"
    echo "  git clone https://github.com/spring-petclinic/spring-petclinic-microservices.git"
    exit 1
fi

echo "✓ Found deployments directory"
echo ""

# Create namespace if it doesn't exist
echo "=== Creating namespace ==="
kubectl create namespace $NAMESPACE 2>/dev/null || echo "Namespace $NAMESPACE already exists"
kubectl config set-context --current --namespace=$NAMESPACE

# Apply all deployments
echo ""
echo "=== Applying Kubernetes manifests ==="
kubectl apply -f "$KUBE_DIR/" -n $NAMESPACE

echo ""
echo "=== Waiting for deployments to be created ==="
sleep 5

# Check deployment status
echo ""
echo "=== Deployment Status ==="
kubectl get deployments -n $NAMESPACE

echo ""
echo "=== Service Status ==="
kubectl get services -n $NAMESPACE

echo ""
echo "=== Pod Status ==="
kubectl get pods -n $NAMESPACE

# Wait for config-server to be ready
echo ""
echo "=== Waiting for config-server to be ready ==="
kubectl wait --for=condition=available --timeout=300s deployment/config-server -n $NAMESPACE || true

# Wait for discovery-server to be ready
echo ""
echo "=== Waiting for discovery-server to be ready ==="
kubectl wait --for=condition=available --timeout=300s deployment/discovery-server -n $NAMESPACE || true

# Get API Gateway access information
echo ""
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""

# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

# Get API Gateway NodePort
API_GATEWAY_PORT=$(kubectl get service api-gateway -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")

echo "Cluster Node IP: $NODE_IP"
echo "API Gateway Port: $API_GATEWAY_PORT"
echo ""

if [ "$API_GATEWAY_PORT" != "N/A" ]; then
    echo "Access the application at:"
    echo "  http://$NODE_IP:$API_GATEWAY_PORT"
    echo ""
fi

echo "Monitor deployment:"
echo "  kubectl get pods -n $NAMESPACE -w"
echo ""
echo "Check logs:"
echo "  kubectl logs -f deployment/config-server -n $NAMESPACE"
echo "  kubectl logs -f deployment/api-gateway -n $NAMESPACE"
echo ""

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
