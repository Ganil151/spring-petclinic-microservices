#!/bin/bash

# Script to label nodes and configure service distribution
# Run this on the master node

set -e

echo "=== Configuring Node Labels for Service Distribution ==="
echo ""

# Strategy: Distribute services across two worker nodes
# k8s-ap-server: Frontend + API Gateway
# k8s-as-server: Backend services (customers, vets, visits)

echo "Labeling k8s-ap-server for frontend workloads..."
kubectl label node k8s-ap-server workload-type=frontend --overwrite
kubectl label node k8s-ap-server zone=zone-a --overwrite

echo "Labeling k8s-as-server for backend workloads..."
kubectl label node k8s-as-server workload-type=backend --overwrite
kubectl label node k8s-as-server zone=zone-b --overwrite

echo ""
echo "✓ Node labels configured"
echo ""

echo "=== Current Node Labels ==="
kubectl get nodes --show-labels

echo ""
echo "=== How to Use These Labels ==="
echo ""
echo "In your deployment YAML files, add nodeSelector:"
echo ""
echo "For Frontend Services (API Gateway, Angular UI):"
cat <<'EOF'
---
spec:
  template:
    spec:
      nodeSelector:
        workload-type: frontend
      containers:
      - name: api-gateway
        ...
EOF

echo ""
echo "For Backend Services (customers, vets, visits):"
cat <<'EOF'
---
spec:
  template:
    spec:
      nodeSelector:
        workload-type: backend
      containers:
      - name: customers-service
        ...
EOF

echo ""
echo "For Infrastructure Services (config-server, discovery-server):"
echo "These can run on any worker node without nodeSelector"
echo ""

echo "=== Example: Spread Pods Across Both Nodes ==="
cat <<'EOF'
---
# Use pod anti-affinity to spread replicas across different nodes
spec:
  replicas: 2
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - customers-service
              topologyKey: kubernetes.io/hostname
EOF

echo ""
echo "=== Verification Commands ==="
echo ""
echo "# See which pods are running on which nodes:"
echo "kubectl get pods -o wide --all-namespaces"
echo ""
echo "# See pods on a specific node:"
echo "kubectl get pods --all-namespaces --field-selector spec.nodeName=k8s-ap-server"
echo "kubectl get pods --all-namespaces --field-selector spec.nodeName=k8s-as-server"
