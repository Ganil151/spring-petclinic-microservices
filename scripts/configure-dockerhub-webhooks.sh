#!/bin/bash

#############################################################
# Docker Hub Webhook Configuration Helper
#
# Purpose: Provides guidance and templates for configuring
#          Docker Hub webhooks for all microservices
#
# Usage: ./configure-dockerhub-webhooks.sh <WEBHOOK_SERVER_IP>
#############################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if webhook server IP is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Webhook server IP not provided${NC}"
    echo "Usage: $0 <WEBHOOK_SERVER_IP>"
    exit 1
fi

WEBHOOK_SERVER="$1"
WEBHOOK_PORT="9000"
WEBHOOK_URL="http://${WEBHOOK_SERVER}:${WEBHOOK_PORT}/webhook"

# List of repositories that need webhooks configured
REPOSITORIES=(
    "ganil151/api-gateway"
    "ganil151/customers-service"
    "ganil151/vets-service"
    "ganil151/visits-service"
    "ganil151/admin-server"
    "ganil151/config-server"
    "ganil151/discovery-server"
)

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Docker Hub Webhook Configuration Guide${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${CYAN}Webhook URL:${NC} ${GREEN}${WEBHOOK_URL}${NC}"
echo ""

echo -e "${YELLOW}Repositories to Configure:${NC}"
echo "----------------------------------------"
for repo in "${REPOSITORIES[@]}"; do
    echo -e "  • ${CYAN}${repo}${NC}"
done
echo ""

echo -e "${YELLOW}Manual Configuration Steps (Docker Hub UI):${NC}"
echo "----------------------------------------"
echo ""
echo "For EACH repository listed above:"
echo ""
echo "1. Go to Docker Hub: https://hub.docker.com/"
echo "2. Navigate to the repository (e.g., ganil151/customers-service)"
echo "3. Click on the 'Webhooks' tab"
echo "4. Click 'Create Webhook'"
echo "5. Enter the following details:"
echo -e "   ${CYAN}Webhook name:${NC} k8s-deployment-trigger"
echo -e "   ${CYAN}Webhook URL:${NC}  ${GREEN}${WEBHOOK_URL}${NC}"
echo "6. Click 'Create'"
echo ""
echo -e "${GREEN}Repeat for all ${#REPOSITORIES[@]} repositories${NC}"
echo ""

echo -e "${YELLOW}Testing the Webhook:${NC}"
echo "----------------------------------------"
echo ""
echo "After configuring webhooks, test by pushing a new image:"
echo ""
echo "  # Example: Push customers-service"
echo "  docker tag customers-service:latest ganil151/customers-service:latest"
echo "  docker push ganil151/customers-service:latest"
echo ""
echo "Then check the webhook logs:"
echo "  ssh ec2-user@${WEBHOOK_SERVER} 'sudo tail -f /var/log/webhook-receiver/webhook.log'"
echo ""

echo -e "${YELLOW}Verification Checklist:${NC}"
echo "----------------------------------------"
echo ""
echo "✓ Webhook server is running:"
echo "  curl ${WEBHOOK_URL%/webhook}/health"
echo ""
echo "✓ Webhooks are configured in Docker Hub for all repositories"
echo ""
echo "✓ Test webhook with simulated payload:"
echo "  ./scripts/test-webhook.sh ${WEBHOOK_SERVER}"
echo ""
echo "✓ Push a real image and verify deployment updates:"
echo "  kubectl get pods -w"
echo ""

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Advanced: API-Based Configuration${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} Docker Hub API for webhooks requires authentication"
echo "and is more complex. Manual UI configuration is recommended."
echo ""
echo "If you prefer API configuration, you'll need:"
echo "  • Docker Hub username and password/token"
echo "  • API endpoint: https://hub.docker.com/v2/repositories/{namespace}/{repo}/webhooks/"
echo ""

echo -e "${GREEN}Configuration guide complete!${NC}"
echo ""
