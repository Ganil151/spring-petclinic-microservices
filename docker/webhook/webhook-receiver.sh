#!/bin/bash

# Docker Webhook Receiver Script
# This script receives webhook notifications from Docker Hub and updates Kubernetes deployments

# Configuration
WEBHOOK_PORT=9000
LOG_FILE="/var/log/docker-webhook.log"

echo "Starting Docker Webhook Receiver on port $WEBHOOK_PORT..."

# Function to update Kubernetes deployment
update_deployment() {
    local IMAGE_NAME=$1
    local IMAGE_TAG=$2
    
    echo "[$(date)] Received webhook for image: $IMAGE_NAME:$IMAGE_TAG" | tee -a $LOG_FILE
    
    # Extract service name from image name (e.g., ganil151/customers-service -> customers-service)
    SERVICE_NAME=$(echo $IMAGE_NAME | cut -d'/' -f2)
    
    echo "[$(date)] Updating deployment: $SERVICE_NAME" | tee -a $LOG_FILE
    
    # Update the Kubernetes deployment with new image
    kubectl set image deployment/$SERVICE_NAME $SERVICE_NAME=$IMAGE_NAME:$IMAGE_TAG
    
    if [ $? -eq 0 ]; then
        echo "[$(date)] Successfully updated $SERVICE_NAME to $IMAGE_TAG" | tee -a $LOG_FILE
        
        # Wait for rollout to complete
        kubectl rollout status deployment/$SERVICE_NAME
        
        echo "[$(date)] Rollout completed for $SERVICE_NAME" | tee -a $LOG_FILE
    else
        echo "[$(date)] ERROR: Failed to update $SERVICE_NAME" | tee -a $LOG_FILE
    fi
}

# Start a simple HTTP server using netcat to receive webhooks
while true; do
    # Listen for incoming webhook POST requests
    RESPONSE=$(echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{\"status\":\"received\"}" | nc -l -p $WEBHOOK_PORT)
    
    # Extract image information from webhook payload
    # Docker Hub sends JSON with repository info
    IMAGE_NAME=$(echo "$RESPONSE" | grep -oP '"repository":\s*"\K[^"]+')
    IMAGE_TAG=$(echo "$RESPONSE" | grep -oP '"tag":\s*"\K[^"]+' | head -1)
    
    if [ -n "$IMAGE_NAME" ] && [ -n "$IMAGE_TAG" ]; then
        # Run update in background to not block webhook receiver
        update_deployment "$IMAGE_NAME" "$IMAGE_TAG" &
    fi
done
