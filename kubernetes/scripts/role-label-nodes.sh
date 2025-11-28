#!/bin/bash

# Script to label Kubernetes nodes with a specified role
# Run this on a machine configured with kubectl access to your cluster

set -e

echo "=== Labeling Kubernetes Nodes ==="
echo ""

# Get all nodes
ALL_NODES=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name,ROLE:.metadata.labels.node-role\.kubernetes\.io/control-plane --no-headers)

if [ -z "$ALL_NODES" ]; then
    echo "No nodes found!"
    exit 1
fi

echo "Current nodes:"
kubectl get nodes
echo ""

# Prompt for the role name
read -p "Enter the role name to assign (e.g., worker, compute, storage): " ROLE_NAME

if [ -z "$ROLE_NAME" ]; then
    echo "Role name cannot be empty. Exiting."
    exit 1
fi

echo ""
echo "You have chosen to label nodes with the role: $ROLE_NAME"
echo "This will create the label: node-role.kubernetes.io/$ROLE_NAME=$ROLE_NAME"
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi
echo ""

# Prompt for node selection strategy
echo "How would you like to select nodes to label?"
echo "1) Label ALL nodes"
echo "2) Label specific nodes (comma-separated list)"
echo "3) Label nodes EXCEPT specific ones (comma-separated list)"
read -p "Enter your choice (1, 2, or 3): " -n 1 -r
echo
echo ""

NODES_TO_LABEL=""

case $REPLY in
    1)
        NODES_TO_LABEL=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)
        ;;
    2)
        read -p "Enter node names to label (comma-separated, e.g., node1,node2,node3): " NODE_LIST_INPUT
        # Convert comma-separated string to space-separated and validate
        IFS=',' read -ra NODE_ARRAY <<< "$NODE_LIST_INPUT"
        for node in "${NODE_ARRAY[@]}"; do
            node=$(echo "$node" | xargs) # Trim whitespace
            if kubectl get node "$node" &> /dev/null; then
                NODES_TO_LABEL="$NODES_TO_LABEL $node"
            else
                echo "Warning: Node '$node' not found. Skipping."
            fi
        done
        ;;
    3)
        EXCLUDE_LIST_INPUT=""
        read -p "Enter node names to EXCLUDE from labeling (comma-separated, e.g., master1,node2): " EXCLUDE_LIST_INPUT
        # Get all nodes
        ALL_NODES_LIST=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)
        # Convert comma-separated string to array for exclusion
        IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_LIST_INPUT"
        for node in $ALL_NODES_LIST; do
            SHOULD_LABEL=true
            for exclude_node in "${EXCLUDE_ARRAY[@]}"; do
                exclude_node=$(echo "$exclude_node" | xargs) # Trim whitespace
                if [ "$node" = "$exclude_node" ]; then
                    SHOULD_LABEL=false
                    break
                fi
            done
            if [ "$SHOULD_LABEL" = true ]; then
                NODES_TO_LABEL="$NODES_TO_LABEL $node"
            fi
        done
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

if [ -z "$NODES_TO_LABEL" ]; then
    echo "No valid nodes selected for labeling. Exiting."
    exit 1
fi

echo "Nodes selected for labeling with role '$ROLE_NAME':"
for node in $NODES_TO_LABEL; do
    echo "  - $node"
done
echo ""

# Label the selected nodes
for node in $NODES_TO_LABEL; do
    echo "Labeling $node with node-role.kubernetes.io/$ROLE_NAME=$ROLE_NAME..."
    kubectl label node "$node" "node-role.kubernetes.io/$ROLE_NAME=$ROLE_NAME" --overwrite
    echo "✓ $node labeled"
done

echo ""
echo "=== Updated Node Status ==="
kubectl get nodes -o wide # Added -o wide for potentially more details

echo ""
echo "=== Example Usage of Labels ==="
echo "You can now use the label '$ROLE_NAME' for scheduling:"
echo "  nodeSelector:"
echo "    node-role.kubernetes.io/$ROLE_NAME: $ROLE_NAME"
echo ""
echo "Or using node affinity:"
echo "  affinity:"
echo "    nodeAffinity:"
echo "      requiredDuringSchedulingIgnoredDuringExecution:"
echo "        nodeSelectorTerms:"
echo "        - matchExpressions:"
echo "          - key: node-role.kubernetes.io/$ROLE_NAME"
echo "            operator: In"
echo "            values:"
echo "            - $ROLE_NAME"