#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

MASTER_IP="13.222.201.118"
KUBE_CONFIG="${HOME}/.kube/config"

echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}      Kubernetes Connection Debugger          ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo "Master IP: $MASTER_IP"
echo ""

# 1. Check Kube Config
echo -e "${YELLOW}>> [1/4] Checking Kube Config...${NC}"
if [ -f "$KUBE_CONFIG" ]; then
    echo -e "${GREEN}✓ Found config at $KUBE_CONFIG${NC}"
    
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "None")
    echo "Current Context: $CURRENT_CONTEXT"
    
    SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "Unknown")
    echo "Cluster Server URL: $SERVER"
    
    if [[ "$SERVER" != *"$MASTER_IP"* ]]; then
        echo -e "${RED}WARNING: Cluster server URL does not match known Master IP ($MASTER_IP)!${NC}"
    else
        echo -e "${GREEN}✓ Server URL matches Master IP${NC}"
    fi
else
    echo -e "${RED}✗ Config file not found at $KUBE_CONFIG${NC}"
fi
echo ""

# 2. Check Network Reachability (Ping)
echo -e "${YELLOW}>> [2/4] Checking Network Reachability (Ping)...${NC}"
if ping -c 3 -W 2 "$MASTER_IP" &> /dev/null; then
    echo -e "${GREEN}✓ Master Node is reachable via Ping${NC}"
else
    echo -e "${RED}✗ Cannot ping Master Node ($MASTER_IP)${NC}"
    echo "  (Note: ICMP might be blocked by security groups)"
fi
echo ""

# 3. Check API Server Port (Curl)
echo -e "${YELLOW}>> [3/4] Checking API Server Reachability (Port 6443)...${NC}"
if curl --connect-timeout 5 -k "https://${MASTER_IP}:6443/livez" &> /dev/null; then
    echo -e "${GREEN}✓ API Server is listening on port 6443${NC}"
elif curl --connect-timeout 5 -k "https://${MASTER_IP}:6443" &> /dev/null; then
     echo -e "${GREEN}✓ API Server port is open (responded to root path)${NC}"
else
    echo -e "${RED}✗ Cannot reach API Server on port 6443${NC}"
    echo "  - Check Security Groups (Allow TCP 6443 from your IP)"
    echo "  - Check if kube-apiserver is running on the master"
fi
echo ""

# 4. Check SSH Access
echo -e "${YELLOW}>> [4/4] Checking SSH Access...${NC}"
if ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 "ec2-user@${MASTER_IP}" "echo 'SSH Success'" &> /dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${YELLOW}⚠ SSH connection failed (or requires unused key)${NC}"
    echo "  Try manually: ssh -i <key.pem> ec2-user@${MASTER_IP}"
fi

echo -e "\n${YELLOW}==============================================${NC}"
