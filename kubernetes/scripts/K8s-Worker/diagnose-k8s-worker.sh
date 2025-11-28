#!/bin/bash

#############################################
# Kubernetes Worker Diagnostic Script
# Comprehensive pre-deployment checks
#############################################

set -e

echo "=========================================="
echo "Kubernetes Worker Diagnostic"
echo "=========================================="
echo ""
date
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ISSUES_FOUND=0

#############################################
# Check 1: Kubelet Service
#############################################

echo "=== Check 1: Kubelet Service ==="
echo ""

if systemctl is-active --quiet kubelet; then
    echo -e "${GREEN}✓ kubelet is running${NC}"
    
    # Show kubelet status
    sudo systemctl status kubelet --no-pager | head -10
else
    echo -e "${RED}✗ kubelet is not running${NC}"
    echo "  Fix: sudo systemctl start kubelet"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

#############################################
# Check 2: Node Registration
#############################################

echo "=== Check 2: Node Registration ==="
echo ""

# Check if node is registered with cluster
NODE_NAME=$(hostname)

if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo -e "${GREEN}✓ kubelet.conf exists${NC}"
    
    # Try to check node status (requires kubectl on worker - optional)
    if command -v kubectl &>/dev/null; then
        if kubectl --kubeconfig=/etc/kubernetes/kubelet.conf get node "$NODE_NAME" &>/dev/null; then
            echo -e "${GREEN}✓ Node is registered with cluster${NC}"
        else
            echo -e "${YELLOW}⚠ Cannot verify node registration${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ kubectl not installed (optional on worker)${NC}"
    fi
else
    echo -e "${RED}✗ kubelet.conf not found${NC}"
    echo "  Worker may not have joined the cluster yet"
    echo "  Run join command from master"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

#############################################
# Check 3: Container Runtime
#############################################

echo "=== Check 3: Container Runtime ==="
echo ""

if systemctl is-active --quiet containerd; then
    echo -e "${GREEN}✓ containerd is running${NC}"
elif systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ docker is running${NC}"
else
    echo -e "${RED}✗ No container runtime is running${NC}"
    echo "  Fix: sudo systemctl start containerd"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

#############################################
# Check 4: CNI Configuration
#############################################

echo "=== Check 4: CNI Configuration ==="
echo ""

if [ -d /etc/cni/net.d ] && [ "$(ls -A /etc/cni/net.d 2>/dev/null)" ]; then
    echo -e "${GREEN}✓ CNI configuration exists${NC}"
    ls -la /etc/cni/net.d/
else
    echo -e "${YELLOW}⚠ CNI configuration not found${NC}"
    echo "  This is normal if CNI hasn't been deployed yet"
fi

echo ""

#############################################
# Check 5: System Pods
#############################################

echo "=== Check 5: System Pods on Worker ==="
echo ""

# Check if crictl is available
if command -v crictl &>/dev/null; then
    PODS_COUNT=$(sudo crictl pods 2>/dev/null | grep -c "Ready" || true)
    
    if [ "$PODS_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ $PODS_COUNT pod(s) running on this worker${NC}"
        sudo crictl pods
    else
        echo -e "${YELLOW}⚠ No pods running on this worker yet${NC}"
    fi
else
    echo -e "${YELLOW}⚠ crictl not available${NC}"
fi

echo ""

#############################################
# Check 6: Network Connectivity
#############################################

echo "=== Check 6: Network Connectivity ==="
echo ""

# Check if we can reach the API server
if [ -f /etc/kubernetes/kubelet.conf ]; then
    API_SERVER=$(grep "server:" /etc/kubernetes/kubelet.conf | awk '{print $2}')
    API_HOST=$(echo "$API_SERVER" | sed 's|https://||' | cut -d: -f1)
    API_PORT=$(echo "$API_SERVER" | sed 's|https://||' | cut -d: -f2)
    
    echo "API Server: $API_SERVER"
    
    if timeout 5 bash -c "echo > /dev/tcp/$API_HOST/$API_PORT" 2>/dev/null; then
        echo -e "${GREEN}✓ Can reach API server${NC}"
    else
        echo -e "${RED}✗ Cannot reach API server${NC}"
        echo "  Check network connectivity and security groups"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo -e "${YELLOW}⚠ Cannot determine API server address${NC}"
fi

echo ""

#############################################
# Check 7: Disk Space
#############################################

echo "=== Check 7: Disk Space ==="
echo ""

DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

echo "Root disk usage: ${DISK_USAGE}%"

if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✓ Sufficient disk space${NC}"
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}⚠ Disk usage is high${NC}"
else
    echo -e "${RED}✗ Disk space critical${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""
df -h

echo ""

#############################################
# Check 8: Memory
#############################################

echo "=== Check 8: Memory ==="
echo ""

TOTAL_MEM=$(free -g | grep Mem | awk '{print $2}')
USED_MEM=$(free -g | grep Mem | awk '{print $3}')
FREE_MEM=$(free -g | grep Mem | awk '{print $4}')

echo "Total Memory: ${TOTAL_MEM}GB"
echo "Used Memory: ${USED_MEM}GB"
echo "Free Memory: ${FREE_MEM}GB"

if [ "$FREE_MEM" -gt 1 ]; then
    echo -e "${GREEN}✓ Sufficient memory available${NC}"
else
    echo -e "${YELLOW}⚠ Low memory${NC}"
fi

echo ""

#############################################
# Check 9: Swap
#############################################

echo "=== Check 9: Swap ==="
echo ""

SWAP_TOTAL=$(free -g | grep Swap | awk '{print $2}')

if [ "$SWAP_TOTAL" -eq 0 ]; then
    echo -e "${GREEN}✓ Swap is disabled${NC}"
else
    echo -e "${RED}✗ Swap is enabled (${SWAP_TOTAL}GB)${NC}"
    echo "  Kubernetes requires swap to be disabled"
    echo "  Fix: sudo swapoff -a"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

#############################################
# Check 10: Firewall
#############################################

echo "=== Check 10: Firewall ==="
echo ""

if systemctl is-active --quiet firewalld; then
    echo -e "${YELLOW}⚠ firewalld is running${NC}"
    echo "  Ensure required ports are open:"
    echo "  - 10250 (kubelet API)"
    echo "  - 30000-32767 (NodePort services)"
else
    echo -e "${GREEN}✓ firewalld is not running${NC}"
fi

echo ""

#############################################
# Summary
#############################################

echo "=========================================="
echo "Diagnostic Summary"
echo "=========================================="
echo ""

if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
    echo ""
    echo "Worker node is healthy!"
    echo ""
    echo "Verify on master:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods -A -o wide"
    echo ""
    exit 0
else
    echo -e "${RED}✗ FOUND $ISSUES_FOUND ISSUE(S)${NC}"
    echo ""
    echo "Please fix the issues above."
    echo ""
    echo "Common fixes:"
    echo "  - Start kubelet: sudo systemctl start kubelet"
    echo "  - Join cluster: Run join command from master"
    echo "  - Disable swap: sudo swapoff -a"
    echo "  - Check logs: sudo journalctl -u kubelet -f"
    echo ""
    exit 1
fi
