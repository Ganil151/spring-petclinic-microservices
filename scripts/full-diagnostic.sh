#!/bin/bash

# Comprehensive diagnostic script for Kubernetes cluster and Ansible setup

set -e

echo "==========================================="
echo "Kubernetes & Ansible Diagnostic Report"
echo "==========================================="
echo ""
echo "Generated: $(date)"
echo ""

# Section 1: Ansible Configuration
echo "========== ANSIBLE CONFIGURATION =========="
echo ""

ANSIBLE_DIR="/home/ganil/spring-petclinic-microservices/ansible"
cd "$ANSIBLE_DIR" || exit 1

echo "Inventory Groups:"
ansible-inventory -i inventory.ini --graph 2>/dev/null || echo "  (Error reading inventory)"

echo ""
echo "Playbook Files:"
ls -1 playbooks/*.yml 2>/dev/null || echo "  (No playbooks found)"

echo ""
echo "Role Structure:"
ls -1 roles/ 2>/dev/null | grep -v "^geerlingguy" || echo "  (No custom roles found)"

for role in roles/*/; do
  if [ -d "$role" ]; then
    echo "  $(basename $role):"
    [ -f "${role}tasks/main.yml" ] && echo "    ✓ tasks/main.yml"
    [ -f "${role}handlers/main.yml" ] && echo "    ✓ handlers/main.yml"
    [ -f "${role}defaults/main.yml" ] && echo "    ✓ defaults/main.yml"
  fi
done

# Section 2: Kubernetes Cluster Status
echo ""
echo "========== KUBERNETES CLUSTER STATUS =========="
echo ""

export KUBECONFIG=/home/ec2-user/.kube/config

if ! kubectl cluster-info &>/dev/null; then
  echo "✗ Kubernetes cluster is not responding"
  echo "  Make sure kubeconfig is properly configured"
else
  echo "✓ Kubernetes cluster is online"
  echo ""
  
  echo "Cluster Info:"
  kubectl cluster-info 2>/dev/null | sed 's/^/  /'
  
  echo ""
  echo "Nodes:"
  kubectl get nodes -o wide 2>/dev/null | sed 's/^/  /'
  
  echo ""
  echo "Node Details:"
  kubectl get nodes -o json 2>/dev/null | jq '.items[] | {name: .metadata.name, status: .status.conditions[] | select(.type=="Ready") | .status}' | sed 's/^/  /'
  
  echo ""
  echo "System Pods (kube-system):"
  kubectl get pods -n kube-system --no-headers 2>/dev/null | sed 's/^/  /' | head -10
  
  echo ""
  echo "Application Pods (default):"
  kubectl get pods -n default --no-headers 2>/dev/null | sed 's/^/  /' | head -10
  
  echo ""
  echo "Services:"
  kubectl get svc -n default 2>/dev/null | sed 's/^/  /'
  
  echo ""
  echo "Persistent Volumes:"
  kubectl get pv 2>/dev/null | sed 's/^/  /' || echo "  (No PVs found)"
fi

# Section 3: Network Diagnostics
echo ""
echo "========== NETWORK DIAGNOSTICS =========="
echo ""

echo "DNS Configuration:"
kubectl get configmap coredns -n kube-system -o yaml 2>/dev/null | head -20 | sed 's/^/  /' || echo "  (CoreDNS ConfigMap not found)"

echo ""
echo "Network Policies:"
kubectl get networkpolicies -A 2>/dev/null | sed 's/^/  /' || echo "  (No network policies)"

# Section 4: Docker/Containerd Status
echo ""
echo "========== CONTAINER RUNTIME STATUS =========="
echo ""

if command -v docker &> /dev/null; then
  echo "Docker Status:"
  docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | sed 's/^/  /' || echo "  (Docker not running)"
fi

if command -v crictl &> /dev/null; then
  echo "Containerd Containers:"
  crictl ps 2>/dev/null | sed 's/^/  /' || echo "  (Containerd not accessible)"
fi

# Section 5: Deployment Manifests
echo ""
echo "========== DEPLOYMENT MANIFESTS =========="
echo ""

K8S_DIR="/home/ganil/spring-petclinic-microservices/kubernetes"
if [ -d "$K8S_DIR/base/deployments" ]; then
  echo "Available deployments:"
  ls -1 "$K8S_DIR/base/deployments/"*.yaml 2>/dev/null | xargs -I {} basename {} | sed 's/.yaml//' | sed 's/^/  /'
  
  echo ""
  echo "FQDN Configuration Check:"
  for file in "$K8S_DIR/base/deployments"/*.yaml; do
    if grep -q "discovery-server:8761" "$file" 2>/dev/null; then
      echo "  ✗ $(basename $file) - uses short hostname for discovery-server"
    elif grep -q "discovery-server.default.svc.cluster.local" "$file" 2>/dev/null; then
      echo "  ✓ $(basename $file) - uses FQDN for discovery-server"
    fi
  done
fi

# Section 6: Common Issues
echo ""
echo "========== COMMON ISSUES CHECK =========="
echo ""

# Check for pending pods
echo -n "Pending pods: "
pending=$(kubectl get pods -A --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l)
if [ "$pending" -gt 0 ]; then
  echo "✗ Found $pending pending pods"
  kubectl get pods -A --field-selector=status.phase=Pending 2>/dev/null | sed 's/^/  /'
else
  echo "✓ No pending pods"
fi

echo ""
echo -n "CrashLoopBackOff pods: "
crashloop=$(kubectl get pods -A 2>/dev/null | grep -c "CrashLoopBackOff" || true)
if [ "$crashloop" -gt 0 ]; then
  echo "✗ Found $crashloop CrashLoopBackOff pods"
  kubectl get pods -A 2>/dev/null | grep "CrashLoopBackOff" | sed 's/^/  /'
else
  echo "✓ No CrashLoopBackOff pods"
fi

echo ""
echo -n "Failed nodes: "
failed=$(kubectl get nodes 2>/dev/null | grep -c "NotReady" || true)
if [ "$failed" -gt 0 ]; then
  echo "✗ Found $failed failed nodes"
  kubectl get nodes 2>/dev/null | grep "NotReady" | sed 's/^/  /'
else
  echo "✓ All nodes are Ready"
fi

# Section 7: Recent Events
echo ""
echo "========== RECENT EVENTS =========="
echo ""

echo "Latest pod events (last 20):"
kubectl get events -A --sort-by='.lastTimestamp' 2>/dev/null | tail -20 | sed 's/^/  /' || echo "  (No events found)"

echo ""
echo "=========================================="
echo "Diagnostic report complete!"
echo "=========================================="
