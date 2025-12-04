#!/bin/bash
# spring-petclinic-diagnostic.sh

set -e

REGION="us-east-1"
KEY_FILE="~/.ssh/master_key.pem"

echo "=== Spring Petclinic Diagnostic ==="
echo ""

# Get Docker-Server details
echo "Getting Docker-Server information..."
DOCKER_INFO=$(aws ec2 describe-instances \
  --region $REGION \
  --filters "Name=tag:Name,Values=Spring-Petclinic-Docker" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].[PublicIpAddress,PrivateIpAddress,SecurityGroups[0].GroupId,State.Name]" \
  --output text)

if [ -z "$DOCKER_INFO" ]; then
  echo "ERROR: Docker-Server instance not found or not running"
  exit 1
fi

PUBLIC_IP=$(echo $DOCKER_INFO | awk '{print $1}')
PRIVATE_IP=$(echo $DOCKER_INFO | awk '{print $2}')
SG_ID=$(echo $DOCKER_INFO | awk '{print $3}')
STATE=$(echo $DOCKER_INFO | awk '{print $4}')

echo "✓ Docker-Server Found"
echo "  Public IP: $PUBLIC_IP"
echo "  Private IP: $PRIVATE_IP"
echo "  Security Group: $SG_ID"
echo "  State: $STATE"
echo ""

# Check Security Group
echo "Checking Security Group rules..."
SG_RULES=$(aws ec2 describe-security-groups \
  --region $REGION \
  --group-ids $SG_ID \
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`8080\`]" \
  --output text)

if [ -z "$SG_RULES" ]; then
  echo "⚠ Port 8080 NOT open in security group"
  echo "  Run this to fix:"
  echo "  aws ec2 authorize-security-group-ingress --region $REGION --group-id $SG_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0"
else
  echo "✓ Port 8080 is open"
fi
echo ""

# Test connectivity
echo "Testing connectivity..."
if nc -zv -w5 $PUBLIC_IP 8080 2>&1 | grep -q succeeded; then
  echo "✓ Port 8080 is reachable"
else
  echo "✗ Port 8080 is NOT reachable"
  echo "  Possible issues:"
  echo "  1. Application not running"
  echo "  2. Security group not configured"
  echo "  3. Firewall blocking"
fi
echo ""

# Test HTTP
echo "Testing HTTP endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://$PUBLIC_IP:8080/ || echo "000")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "404" ]; then
  echo "✓ Application is responding (HTTP $HTTP_CODE)"
else
  echo "✗ Application not responding (HTTP $HTTP_CODE)"
fi
echo ""

# Display URLs
echo "=== Access URLs ==="
echo "Main Application: http://$PUBLIC_IP:8080/"
echo "Discovery Server: http://$PUBLIC_IP:8761/"
echo "Grafana:          http://$PUBLIC_IP:3000/"
echo "Prometheus:       http://$PUBLIC_IP:9091/"
echo "Zipkin:           http://$PUBLIC_IP:9411/"
echo ""

echo "To check container status, SSH to server:"
echo "ssh -i $KEY_FILE ec2-user@$PUBLIC_IP"
echo "docker ps"
