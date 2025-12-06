#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}      Kubernetes Cluster Diagnostic Tool      ${NC}"
echo -e "${YELLOW}==============================================${NC}"
echo "Date: $(date)"
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl could not be found. Please install it first.${NC}"
    exit 1
fi

# Function: Check Connectivity
check_connectivity() {
    echo -e "${YELLOW}>> Checking Cluster Connectivity...${NC}"
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✓ Connected to Kubernetes API${NC}"
    else
        echo -e "${RED}✗ Cannot connect to Kubernetes API${NC}"
        exit 1
    fi
    echo ""
}

# Function: Check Node Status
check_nodes() {
    echo -e "${YELLOW}>> Checking Node Status...${NC}"
    kubectl get nodes -o wide
    
    echo -e "\n${YELLOW}-- Diagnostics --${NC}"
    NOT_READY_NODES=$(kubectl get nodes --no-headers | awk '$2 != "Ready" {print $1}')
    if [ -n "$NOT_READY_NODES" ]; then
        echo -e "${RED}WARNING: The following nodes are NOT Ready:${NC}"
        echo "$NOT_READY_NODES"
    else
        echo -e "${GREEN}✓ All nodes are Ready${NC}"
    fi
    echo ""
}

# Function: Check Pod Status
check_pods() {
    echo -e "${YELLOW}>> Checking Pod Status...${NC}"
    
    # Check for non-running pods (excluding Completed/Succeeded jobs)
    PROBLEMATIC_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null || true)
    
    if [ -n "$PROBLEMATIC_PODS" ]; then
        echo -e "${RED}Found unhealthy pods:${NC}"
        kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o wide
    else
        echo -e "${GREEN}✓ All pods are in Running or Succeeded state${NC}"
    fi

    echo -e "\n${YELLOW}-- High Restarts --${NC}"
    # Find pods with restarts > 0
    RESTARTING_PODS=$(kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.status.containerStatuses[*].restartCount>0)]}{.metadata.namespace}{"/"}{.metadata.name}{" Restarts: "}{.status.containerStatuses[*].restartCount}{"\n"}{end}')
    
    if [ -n "$RESTARTING_PODS" ]; then
        echo -e "${YELLOW}Pods with restart history:${NC}"
        echo "$RESTARTING_PODS" | sort -k 3 -n -r | head -n 10
    else
        echo -e "${GREEN}✓ No pod restarts detected${NC}"
    fi
    echo ""
}

# Function: Check Events
check_events() {
    echo -e "${YELLOW}>> Recent Warning Events (Last 1 hour)...${NC}"
    EVENTS=$(kubectl get events --all-namespaces --field-selector type=Warning --sort-by='.lastTimestamp')
    if [ -z "$EVENTS" ]; then
         echo -e "${GREEN}✓ No warning events found${NC}"
    else
         kubectl get events --all-namespaces --field-selector type=Warning --sort-by='.lastTimestamp' | tail -n 15
    fi
    echo ""
}

# Function: Resource Usage
check_resources() {
    echo -e "${YELLOW}>> Resource Usage...${NC}"
    
    if kubectl top nodes &> /dev/null; then
        echo "Top Nodes by CPU:"
        kubectl top nodes --sort-by=cpu | head -n 5
        echo ""
        echo "Top Nodes by Memory:"
        kubectl top nodes --sort-by=memory | head -n 5
        echo ""
        echo "Top Pods by CPU:"
        kubectl top pods --all-namespaces --sort-by=cpu | head -n 10
        echo ""
        echo "Top Pods by Memory:"
        kubectl top pods --all-namespaces --sort-by=memory | head -n 10
    else
        echo -e "${YELLOW}Metrics API not available (metrics-server might not be installed). Skipping resource check.${NC}"
    fi
    echo ""
}

# Main Execution
check_connectivity
check_nodes
check_pods
check_events
check_resources

echo -e "${YELLOW}==============================================${NC}"
echo -e "${YELLOW}           Diagnostic Complete                ${NC}"
echo -e "${YELLOW}==============================================${NC}"
