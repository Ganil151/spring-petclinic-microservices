#!/bin/bash

# Script to delete Kubernetes pods
# Usage: ./delete-pods.sh [OPTIONS]

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="default"
FORCE=false
DRY_RUN=false

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Delete Kubernetes pods with various filtering options.

OPTIONS:
    -n, --namespace NAMESPACE    Namespace to delete pods from (default: default)
    -p, --pod POD_NAME          Specific pod name to delete
    -l, --label LABEL_SELECTOR  Delete pods matching label selector (e.g., app=api-gateway)
    -a, --all                   Delete all pods in the namespace
    -f, --force                 Force delete without confirmation
    --dry-run                   Show what would be deleted without actually deleting
    -h, --help                  Display this help message

EXAMPLES:
    # Delete a specific pod
    $0 -n default -p my-pod-123

    # Delete all pods with a specific label
    $0 -n default -l app=customers-service

    # Delete all pods in a namespace (with confirmation)
    $0 -n default --all

    # Dry run to see what would be deleted
    $0 -n default -l app=vets-service --dry-run

    # Force delete without confirmation
    $0 -n default -l app=api-gateway --force

EOF
    exit 0
}

# Function to confirm action
confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi
    
    read -p "Are you sure you want to delete the above pods? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        exit 1
    fi
}

# Parse command line arguments
POD_NAME=""
LABEL_SELECTOR=""
DELETE_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -p|--pod)
            POD_NAME="$2"
            shift 2
            ;;
        -l|--label)
            LABEL_SELECTOR="$2"
            shift 2
            ;;
        -a|--all)
            DELETE_ALL=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Verify namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}Error: Namespace '$NAMESPACE' does not exist${NC}"
    exit 1
fi

# Build kubectl command based on options
echo -e "${GREEN}Namespace: ${NC}$NAMESPACE"
echo ""

if [ -n "$POD_NAME" ]; then
    # Delete specific pod
    echo -e "${YELLOW}Pod to delete:${NC}"
    kubectl get pod "$POD_NAME" -n "$NAMESPACE" 2>/dev/null || {
        echo -e "${RED}Error: Pod '$POD_NAME' not found in namespace '$NAMESPACE'${NC}"
        exit 1
    }
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${GREEN}[DRY RUN]${NC} Would delete pod: $POD_NAME"
        exit 0
    fi
    
    confirm
    echo -e "${GREEN}Deleting pod: $POD_NAME${NC}"
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE"
    
elif [ -n "$LABEL_SELECTOR" ]; then
    # Delete pods by label selector
    echo -e "${YELLOW}Pods matching label '$LABEL_SELECTOR':${NC}"
    PODS=$(kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" --no-headers 2>/dev/null | wc -l)
    
    if [ "$PODS" -eq 0 ]; then
        echo -e "${YELLOW}No pods found matching label '$LABEL_SELECTOR'${NC}"
        exit 0
    fi
    
    kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${GREEN}[DRY RUN]${NC} Would delete $PODS pod(s)"
        exit 0
    fi
    
    confirm
    echo -e "${GREEN}Deleting pods with label: $LABEL_SELECTOR${NC}"
    kubectl delete pods -n "$NAMESPACE" -l "$LABEL_SELECTOR"
    
elif [ "$DELETE_ALL" = true ]; then
    # Delete all pods in namespace
    echo -e "${YELLOW}All pods in namespace '$NAMESPACE':${NC}"
    PODS=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    
    if [ "$PODS" -eq 0 ]; then
        echo -e "${YELLOW}No pods found in namespace '$NAMESPACE'${NC}"
        exit 0
    fi
    
    kubectl get pods -n "$NAMESPACE"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "\n${GREEN}[DRY RUN]${NC} Would delete all $PODS pod(s)"
        exit 0
    fi
    
    echo -e "${RED}WARNING: This will delete ALL pods in namespace '$NAMESPACE'${NC}"
    confirm
    echo -e "${GREEN}Deleting all pods in namespace: $NAMESPACE${NC}"
    kubectl delete pods --all -n "$NAMESPACE"
    
else
    echo -e "${RED}Error: You must specify one of: --pod, --label, or --all${NC}"
    echo ""
    usage
fi

echo -e "${GREEN}Done!${NC}"
