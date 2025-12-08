#!/bin/bash

# Kubernetes Node Labeling Script
# Labels worker nodes with appropriate roles and workload types
# Usage: ./label-nodes.sh [primary-node] [secondary-node]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colo

# Default node names (can be overridden by arguments)
PRIMARY_WORKER="${1:-k8s-worker1-server}"
SECONDARY_WORKER="${2:-k8s-worker2-server}"

echo -e "${BLUE}=============================================="
echo -e "  Kubernetes Node Labeling Script"
echo -e "=============================================${NC}"
echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Primary Worker:   $PRIMARY_WORKER"
echo "  Secondary Worker: $SECONDARY_WORKER"
echo ""

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl not found. Please ensure kubectl is installed and configured.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ kubectl is available${NC}"
}

# Function to verify node exists
verify_node() {
    local node=$1
    if kubectl get nodes "$node" &> /dev/null; then
        echo -e "${GREEN}✅ Node $node exists${NC}"
        return 0
    else
        echo -e "${RED}❌ Node $node not found${NC}"
        return 1
    fi
}

# Function to remove all role labels from a node
remove_labels() {
    local node=$1
    echo -e "${YELLOW}Removing existing labels from $node...${NC}"
    
    kubectl label nodes "$node" \
        node-role.kubernetes.io/backend- \
        node-role.kubernetes.io/frontend- \
        node-role.kubernetes.io/worker- \
        node-role.kubernetes.io/control-plane- \
        --overwrite 2>/dev/null || true
    
    echo -e "${GREEN}✅ Labels removed from $node${NC}"
}

# Function to label a node as primary worker
label_primary_worker() {
    local node=$1
    echo -e "${YELLOW}Labeling $node as PRIMARY worker...${NC}"
    
    kubectl label nodes "$node" \
        node-role.kubernetes.io/worker= \
        node-role.kubernetes.io/frontend= \
        workload-type=primary \
        zone=primary \
        --overwrite
    
    echo -e "${GREEN}✅ $node labeled as PRIMARY worker${NC}"
}

# Function to label a node as secondary worker
label_secondary_worker() {
    local node=$1
    echo -e "${YELLOW}Labeling $node as SECONDARY worker...${NC}"
    
    kubectl label nodes "$node" \
        node-role.kubernetes.io/worker= \
        node-role.kubernetes.io/backend= \
        workload-type=secondary \
        zone=secondary \
        --overwrite
    
    echo -e "${GREEN}✅ $node labeled as SECONDARY worker${NC}"
}

# Function to display current labels
display_labels() {
    echo ""
    echo -e "${BLUE}Current Node Labels:${NC}"
    echo ""
    kubectl get nodes --show-labels
}

# Function to display node details
display_node_details() {
    echo ""
    echo -e "${BLUE}Node Details:${NC}"
    echo ""
    kubectl get nodes -o wide
}

# Main execution
main() {
    echo -e "${YELLOW}Step 1: Verifying kubectl${NC}"
    check_kubectl
    echo ""
    
    echo -e "${YELLOW}Step 2: Verifying nodes exist${NC}"
    verify_node "$PRIMARY_WORKER" || exit 1
    verify_node "$SECONDARY_WORKER" || exit 1
    echo ""
    
    echo -e "${YELLOW}Step 3: Removing existing labels${NC}"
    remove_labels "$PRIMARY_WORKER"
    remove_labels "$SECONDARY_WORKER"
    echo ""
    
    echo -e "${YELLOW}Step 4: Applying PRIMARY worker labels${NC}"
    label_primary_worker "$PRIMARY_WORKER"
    echo ""
    
    echo -e "${YELLOW}Step 5: Applying SECONDARY worker labels${NC}"
    label_secondary_worker "$SECONDARY_WORKER"
    echo ""
    
    echo -e "${YELLOW}Step 6: Displaying results${NC}"
    display_labels
    echo ""
    display_node_details
    echo ""
    
    echo -e "${GREEN}=============================================="
    echo -e "  ✅ Node Labeling Complete!"
    echo -e "=============================================${NC}"
    echo ""
    echo -e "${BLUE}Label Summary:${NC}"
    echo "  PRIMARY Worker ($PRIMARY_WORKER):"
    echo "    - node-role.kubernetes.io/worker"
    echo "    - node-role.kubernetes.io/frontend"
    echo "    - workload-type=primary"
    echo "    - zone=primary"
    echo ""
    echo "  SECONDARY Worker ($SECONDARY_WORKER):"
    echo "    - node-role.kubernetes.io/worker"
    echo "    - node-role.kubernetes.io/backend"
    echo "    - workload-type=secondary"
    echo "    - zone=secondary"
    echo ""
}

# Run main function
main "$@"
