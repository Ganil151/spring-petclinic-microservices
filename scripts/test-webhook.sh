#!/bin/bash

#############################################################
# Webhook Receiver Testing Script
#
# Purpose: Test the webhook receiver by sending simulated
#          Docker Hub webhook payloads
#
# Usage: ./test-webhook.sh <WEBHOOK_SERVER_IP>
#############################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if webhook server IP is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Webhook server IP not provided${NC}"
    echo "Usage: $0 <WEBHOOK_SERVER_IP>"
    exit 1
fi

WEBHOOK_SERVER="$1"
WEBHOOK_PORT="9000"
WEBHOOK_URL="http://${WEBHOOK_SERVER}:${WEBHOOK_PORT}"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Webhook Receiver Test Suite${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "Target: ${YELLOW}${WEBHOOK_URL}${NC}"
echo ""

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
echo "----------------------------------------"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "${WEBHOOK_URL}/health")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$HEALTH_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "Response: $RESPONSE_BODY"
else
    echo -e "${RED}✗ Health check failed (HTTP $HTTP_CODE)${NC}"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi
echo ""

# Test 2: Service Info
echo -e "${YELLOW}Test 2: Service Information${NC}"
echo "----------------------------------------"
INFO_RESPONSE=$(curl -s "${WEBHOOK_URL}/")
echo "$INFO_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$INFO_RESPONSE"
echo ""

# Test 3: Simulated Webhook - Customers Service
echo -e "${YELLOW}Test 3: Simulated Webhook - Customers Service${NC}"
echo "----------------------------------------"

PAYLOAD='{
  "push_data": {
    "pushed_at": 1234567890,
    "pusher": "testuser",
    "tag": "latest"
  },
  "repository": {
    "repo_name": "ganil151/customers-service",
    "name": "customers-service",
    "namespace": "ganil151",
    "status": "Active"
  }
}'

echo "Sending payload:"
echo "$PAYLOAD" | python3 -m json.tool 2>/dev/null || echo "$PAYLOAD"
echo ""

WEBHOOK_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "${WEBHOOK_URL}/webhook")

HTTP_CODE=$(echo "$WEBHOOK_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$WEBHOOK_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Webhook processed successfully${NC}"
    echo "Response:"
    echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo -e "${RED}✗ Webhook failed (HTTP $HTTP_CODE)${NC}"
    echo "Response:"
    echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
fi
echo ""

# Test 4: Simulated Webhook - API Gateway
echo -e "${YELLOW}Test 4: Simulated Webhook - API Gateway${NC}"
echo "----------------------------------------"

PAYLOAD='{
  "push_data": {
    "pushed_at": 1234567890,
    "pusher": "testuser",
    "tag": "v1.0.0"
  },
  "repository": {
    "repo_name": "ganil151/api-gateway",
    "name": "api-gateway",
    "namespace": "ganil151",
    "status": "Active"
  }
}'

echo "Sending payload with tag: v1.0.0"
echo ""

WEBHOOK_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "${WEBHOOK_URL}/webhook")

HTTP_CODE=$(echo "$WEBHOOK_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$WEBHOOK_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Webhook processed successfully${NC}"
    echo "Response:"
    echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo -e "${RED}✗ Webhook failed (HTTP $HTTP_CODE)${NC}"
    echo "Response:"
    echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
fi
echo ""

# Test 5: Invalid Repository (should be ignored gracefully)
echo -e "${YELLOW}Test 5: Unknown Repository (Should Be Ignored)${NC}"
echo "----------------------------------------"

PAYLOAD='{
  "push_data": {
    "pushed_at": 1234567890,
    "pusher": "testuser",
    "tag": "latest"
  },
  "repository": {
    "repo_name": "ganil151/unknown-service",
    "name": "unknown-service",
    "namespace": "ganil151",
    "status": "Active"
  }
}'

WEBHOOK_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "${WEBHOOK_URL}/webhook")

HTTP_CODE=$(echo "$WEBHOOK_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$WEBHOOK_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Unknown repository handled gracefully${NC}"
    echo "Response:"
    echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo -e "${YELLOW}⚠ Unexpected response (HTTP $HTTP_CODE)${NC}"
    echo "Response:"
    echo "$RESPONSE_BODY" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE_BODY"
fi
echo ""

# Summary
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${GREEN}All tests completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Check webhook logs on the server:"
echo -e "   ${YELLOW}ssh ec2-user@${WEBHOOK_SERVER} 'sudo tail -f /var/log/webhook-receiver/webhook.log'${NC}"
echo ""
echo "2. Verify deployments were updated (if applicable):"
echo -e "   ${YELLOW}kubectl get deployments${NC}"
echo -e "   ${YELLOW}kubectl describe deployment customers-service${NC}"
echo ""
echo "3. Configure real Docker Hub webhooks:"
echo -e "   ${YELLOW}URL: http://${WEBHOOK_SERVER}:${WEBHOOK_PORT}/webhook${NC}"
echo ""
