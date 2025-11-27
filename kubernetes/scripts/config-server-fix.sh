#!/bin/bash

# Script Name: fix_config_server.sh
# Description: A script to fix the Spring Petclinic Config Server in Kubernetes.
#              It deletes current pods, optionally updates the Git URI,
#              restarts the deployment, and verifies the rollout.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
DEPLOYMENT_NAME="config-server"
APP_LABEL="app=config-server"
DEFAULT_GIT_URI="https://github.com/spring-petclinic/spring-petclinic-microservices-config"
DEFAULT_GIT_LABEL="main"

# --- Helper Functions ---
print_header() {
    echo "========================================="
    echo " $1"
    echo "========================================="
}

# --- Main Fix Process ---
print_header "Starting Config Server Fix Process"

# 1. Check current pod status
print_header "1. Checking current pod status for $APP_LABEL"
kubectl get pods -l $APP_LABEL

# 2. Delete all config-server pods to force fresh start
print_header "2. Deleting all pods with label $APP_LABEL to force restart"
kubectl delete pods -l $APP_LABEL --grace-period=30 --timeout=60s || true # Continue even if no pods exist initially
echo "Deletion command sent. Waiting for pods to terminate..."
sleep 10 # Brief wait for termination to initiate

# 3. Check if deployment exists and get current Git URI
print_header "3. Checking deployment $DEPLOYMENT_NAME and its Git URI configuration"
if kubectl get deployment $DEPLOYMENT_NAME &> /dev/null; then
    echo "Deployment $DEPLOYMENT_NAME found."
    echo "Current environment variables (looking for Git URI/Label):"
    kubectl get deployment $DEPLOYMENT_NAME -o yaml | grep -A 10 "env:"
    echo ""
    # Prompt user if they want to update the Git URI
    read -p "Do you want to update the Git URI/Label? (y/N): " -n 1 -r REPLY
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter new Git URI (default: $DEFAULT_GIT_URI): " GIT_URI_INPUT
        GIT_URI=${GIT_URI_INPUT:-$DEFAULT_GIT_URI}
        read -p "Enter new Git Label (default: $DEFAULT_GIT_LABEL): " GIT_LABEL_INPUT
        GIT_LABEL=${GIT_LABEL_INPUT:-$DEFAULT_GIT_LABEL}

        echo "Setting SPRING_CLOUD_CONFIG_SERVER_GIT_URI=$GIT_URI and SPRING_CLOUD_CONFIG_SERVER_GIT_DEFAULT_LABEL=$GIT_LABEL"
        kubectl set env deployment/$DEPLOYMENT_NAME \
            SPRING_CLOUD_CONFIG_SERVER_GIT_URI=$GIT_URI \
            SPRING_CLOUD_CONFIG_SERVER_GIT_DEFAULT_LABEL=$GIT_LABEL
    else
        echo "Skipping Git URI/Label update."
    fi
else
    echo "ERROR: Deployment $DEPLOYMENT_NAME not found. Exiting."
    exit 1
fi

# 4. Restart the deployment
print_header "4. Restarting deployment $DEPLOYMENT_NAME"
kubectl rollout restart deployment $DEPLOYMENT_NAME

# 5. Watch the pod startup and rollout status
print_header "5. Watching pod startup and rollout status for $DEPLOYMENT_NAME (Press Ctrl+C to stop watching, but rollout continues)"
echo "Watching pods..."
kubectl get pods -l $APP_LABEL -w &
WATCH_PID=$!
echo "Watching rollout status..."
kubectl rollout status deployment $DEPLOYMENT_NAME --timeout=300s # Wait up to 5 minutes for rollout
echo "Rollout status check completed."

# 6. Kill the background pod watch
kill $WATCH_PID 2>/dev/null || true

# 7. Check logs of the new pod once rollout is complete
print_header "6. Checking logs of the new config-server pod"
NEW_POD_NAME=$(kubectl get pods -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$NEW_POD_NAME" ]; then
    echo "Fetching logs for pod: $NEW_POD_NAME"
    kubectl logs $NEW_POD_NAME --tail=50
else
    echo "WARNING: Could not find a new pod with label $APP_LABEL after rollout. Please check manually."
    kubectl get pods -l $APP_LABEL
fi

# 8. Final status check
print_header "7. Final status check for deployment $DEPLOYMENT_NAME"
kubectl get deployment $DEPLOYMENT_NAME
kubectl get pods -l $APP_LABEL

print_header "Config Server Fix Process Completed"
echo "Please verify the application is working as expected."
echo "Check Eureka Dashboard (http://<gateway-url>:8761) to confirm Config Server is registered and healthy."
