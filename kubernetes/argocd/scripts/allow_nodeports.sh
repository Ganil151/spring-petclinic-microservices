#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MASTER_IP="13.222.201.118"

echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}      AWS Security Group Patcher              ${NC}"
echo -e "${YELLOW}==============================================${NC}"

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed or not in PATH.${NC}"
    echo "Please install it or open ports manually in AWS Console:"
    echo "- Security Group Inbound Rule: TCP 30000-32767 (0.0.0.0/0)"
    exit 1
fi

echo -e "${YELLOW}>> Finding Instance with IP $MASTER_IP...${NC}"

# Get Instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=ip-address,Values=$MASTER_IP" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text)

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo -e "${RED}✗ Could not find EC2 instance with IP $MASTER_IP${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found Instance: $INSTANCE_ID${NC}"

# Get Security Group ID
SG_ID=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].SecurityGroups[0].GroupId" \
    --output text)

echo -e "${GREEN}✓ Found Security Group: $SG_ID${NC}"
echo ""

# Authorize NodePorts
echo -e "${YELLOW}>> Authorizing NodePort Range (30000-32767)...${NC}"
if aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 30000-32767 \
    --cidr 0.0.0.0/0 &>/dev/null; then
    echo -e "${GREEN}✓ Successfully opened ports 30000-32767${NC}"
else
    echo -e "${YELLOW}⚠ Could not authorize ports (Rule might already exist)${NC}"
fi

# Authorize Kubernetes API (Just in case)
echo -e "${YELLOW}>> Authorizing Kubernetes API (6443)...${NC}"
if aws ec2 authorize-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 6443 \
    --cidr 0.0.0.0/0 &>/dev/null; then
    echo -e "${GREEN}✓ Successfully opened port 6443${NC}"
else
     echo -e "${YELLOW}⚠ Could not authorize port 6443 (Rule might already exist)${NC}"
fi

echo ""
echo -e "${YELLOW}==============================================${NC}"
echo -e "${GREEN}Security Group Updated!${NC}"
echo "You should now be able to access ArgoCD at:"
echo "https://${MASTER_IP}:<NODE_PORT>"
