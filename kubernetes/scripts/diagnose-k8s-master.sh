#!/bin/bash

#############################################
# Kubernetes Master Diagnostic Script
# Comprehensive pre-deployment checks
#############################################

set -e

echo "=========================================="
echo "Kubernetes Master Diagnostic"
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
# Check 1: kubectl Configuration
#############################################

echo "=== Check 1: kubectl Configuration ==="
echo ""

if [ ! -f ~/.kube/config ]; then
    echo -e "${RED}✗ kubectl config not found${NC}"
    echo "  Fix: mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown \$(id -u):\$(id -g) ~/.kube/config"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}✓ kubectl config exists${NC}"
    
    if kubectl version --short &>/dev/null || kubectl version &>/dev/null; then
        echo -e "${GREEN}✓ kubectl is working${NC}"
    else
        echo -e "${RED}✗ kubectl command failed${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

echo ""

#############################################
# Check 2: Node Status
#############################################

echo "=== Check 2: Node Status ==="
echo ""

NODES_OUTPUT=$(kubectl get nodes --no-headers 2>/dev/null || echo "")

if [ -z "$NODES_OUTPUT" ]; then
    echo -e "${RED}✗ Cannot get nodes${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    TOTAL_NODES=$(echo "$NODES_OUTPUT" | wc -l)
    READY_NODES=$(echo "$NODES_OUTPUT" | grep -c " Ready " || true)
    NOT_READY=$(echo "$NODES_OUTPUT" | grep -c "NotReady" || true)
    
    echo "Total Nodes: $TOTAL_NODES"
    echo "Ready: $READY_NODES"
    echo "NotReady: $NOT_READY"
    echo ""
    
    kubectl get nodes -o wide
    echo ""
    
    if [ "$NOT_READY" -gt 0 ]; then
        echo -e "${RED}✗ $NOT_READY node(s) are NotReady${NC}"
        echo "  Common causes: CNI not installed, kubelet issues"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    else
        echo -e "${GREEN}✓ All nodes are Ready${NC}"
    fi
fi

echo ""

#############################################
# Check 3: System Pods
#############################################

echo "=== Check 3: System Pods ==="
echo ""

SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null || echo "")

if [ -z "$SYSTEM_PODS" ]; then
    echo -e "${RED}✗ Cannot get system pods${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    TOTAL_PODS=$(echo "$SYSTEM_PODS" | wc -l)
    RUNNING_PODS=$(echo "$SYSTEM_PODS" | grep -c "Running" || true)
    PENDING_PODS=$(echo "$SYSTEM_PODS" | grep -c "Pending" || true)
    FAILED_PODS=$(echo "$SYSTEM_PODS" | grep -cE "Error|CrashLoopBackOff|ImagePullBackOff" || true)
    
    echo "Total System Pods: $TOTAL_PODS"
    echo "Running: $RUNNING_PODS"
    echo "Pending: $PENDING_PODS"
    echo "Failed: $FAILED_PODS"
    echo ""
    
    kubectl get pods -n kube-system
    echo ""
    
    if [ "$FAILED_PODS" -gt 0 ]; then
        echo -e "${RED}✗ $FAILED_PODS pod(s) are failing${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    elif [ "$PENDING_PODS" -gt 0 ]; then
        echo -e "${YELLOW}⚠ $PENDING_PODS pod(s) are pending${NC}"
        echo "  This may be normal if cluster just started"
    else
        echo -e "${GREEN}✓ All system pods are running${NC}"
    fi
fi

echo ""

#############################################
# Check 4: Calico CNI
#############################################

echo "=== Check 4: Calico CNI ==="
echo ""

CALICO_PODS=$(kubectl get pods -n kube-system -l k8s-app=calico-node --no-headers 2>/dev/null | wc -l)

if [ "$CALICO_PODS" -eq 0 ]; then
    echo -e "${RED}✗ Calico is not installed${NC}"
    echo "  Fix: kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml"
    echo "       kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    RUNNING_CALICO=$(kubectl get pods -n kube-system -l k8s-app=calico-node --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    echo "Calico Pods: $RUNNING_CALICO/$CALICO_PODS running"
    kubectl get pods -n kube-system -l k8s-app=calico-node
    echo ""
    
    if [ "$RUNNING_CALICO" -eq "$CALICO_PODS" ]; then
        echo -e "${GREEN}✓ Calico is running on all nodes${NC}"
    else
        echo -e "${YELLOW}⚠ Some Calico pods are not running${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

echo ""

#############################################
# Check 5: CoreDNS
#############################################

echo "=== Check 5: CoreDNS ==="
echo ""

COREDNS_PODS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | wc -l)

if [ "$COREDNS_PODS" -eq 0 ]; then
    echo -e "${RED}✗ CoreDNS not found${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    RUNNING_COREDNS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    
    echo "CoreDNS Pods: $RUNNING_COREDNS/$COREDNS_PODS running"
    kubectl get pods -n kube-system -l k8s-app=kube-dns
    echo ""
    
    if [ "$RUNNING_COREDNS" -eq "$COREDNS_PODS" ]; then
        echo -e "${GREEN}✓ CoreDNS is running${NC}"
    else
        echo -e "${YELLOW}⚠ CoreDNS pods are not all running${NC}"
        echo "  They need CNI to be fully operational"
    fi
fi

echo ""

#############################################
# Check 6: API Server
#############################################

echo "=== Check 6: API Server ==="
echo ""

if kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓ API server is accessible${NC}"
    kubectl cluster-info
else
    echo -e "${RED}✗ API server is not accessible${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

#############################################
# Check 7: etcd
#############################################

echo "=== Check 7: etcd ==="
echo ""

ETCD_POD=$(kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null | awk '{print $1}' | head -1)

if [ -n "$ETCD_POD" ]; then
    ETCD_STATUS=$(kubectl get pod -n kube-system "$ETCD_POD" --no-headers 2>/dev/null | awk '{print $3}')
    
    if [ "$ETCD_STATUS" = "Running" ]; then
        echo -e "${GREEN}✓ etcd is running${NC}"
    else
        echo -e "${RED}✗ etcd status: $ETCD_STATUS${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo -e "${RED}✗ etcd pod not found${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo ""

#############################################
# Check 8: Storage Class
#############################################

echo "=== Check 8: Storage Class ==="
echo ""

STORAGE_CLASSES=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)

if [ "$STORAGE_CLASSES" -gt 0 ]; then
    echo -e "${GREEN}✓ Storage classes available${NC}"
    kubectl get storageclass
else
    echo -e "${YELLOW}⚠ No storage classes found${NC}"
    echo "  Applications may not be able to create persistent volumes"
fi

echo ""

#############################################
# Check 9: Resource Availability
#############################################

echo "=== Check 9: Resource Availability ==="
echo ""

if kubectl top nodes &>/dev/null; then
    kubectl top nodes
    echo ""
    echo -e "${GREEN}✓ Metrics available${NC}"
else
    echo -e "${YELLOW}⚠ Metrics not available (metrics-server may not be installed)${NC}"
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
    echo "Cluster is ready for deployments!"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy applications:"
    echo "     kubectl apply -f ~/spring-petclinic-microservices/kubernetes/deployments/"
    echo ""
    echo "  2. Monitor deployment:"
    echo "     kubectl get pods -w"
    echo ""
    exit 0
else
    echo -e "${RED}✗ FOUND $ISSUES_FOUND ISSUE(S)${NC}"
    echo ""
    echo "Please fix the issues above before deploying applications."
    echo ""
    echo "Common fixes:"
    echo "  - Install Calico if missing"
    echo "  - Wait for pods to start (2-3 minutes)"
    echo "  - Check kubelet logs: sudo journalctl -u kubelet -f"
    echo ""
    exit 1
fi
