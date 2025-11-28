#!/bin/bash

echo "=========================================="
echo "Auto-Fix: Creating Missing Services"
echo "=========================================="
echo ""

# Function to create service if it doesn't exist
create_service_if_missing() {
    local SERVICE_NAME=$1
    local PORT=$2
    local TARGET_PORT=$3
    
    if kubectl get service $SERVICE_NAME &>/dev/null; then
        echo "✓ Service $SERVICE_NAME already exists"
    else
        echo "Creating service: $SERVICE_NAME"
        kubectl expose deployment $SERVICE_NAME \
            --port=$PORT \
            --target-port=$TARGET_PORT \
            --name=$SERVICE_NAME \
            --type=ClusterIP
        
        if [ $? -eq 0 ]; then
            echo "✓ Successfully created $SERVICE_NAME service"
        else
            echo "✗ Failed to create $SERVICE_NAME service"
        fi
    fi
    echo ""
}

# Create all required services
echo "=== Creating Infrastructure Services ==="
create_service_if_missing "config-server" 8888 8080
create_service_if_missing "discovery-server" 8761 8761
create_service_if_missing "admin-server" 9090 9090

echo "=== Creating Microservices ==="
create_service_if_missing "customers-service" 8081 8080
create_service_if_missing "visits-service" 8082 8080
create_service_if_missing "vets-service" 8083 8080
create_service_if_missing "api-gateway" 8080 8080

echo "=== Creating Additional Services ==="
create_service_if_missing "genai-service" 8085 8080

echo ""
echo "=========================================="
echo "Verifying Services"
echo "=========================================="
kubectl get services

echo ""
echo "=========================================="
echo "Checking Pod Status"
echo "=========================================="
echo "Waiting 30 seconds for pods to restart..."
sleep 30

kubectl get pods

echo ""
echo "=========================================="
echo "Service Creation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Monitor pod status: kubectl get pods -w"
echo "2. Check logs: kubectl logs -f deployment/config-server"
echo "3. Wait for all pods to reach Running state (may take 2-5 minutes)"
echo ""
