#!/usr/bin/env bash
# k8s-diagnose.sh
# Comprehensive Kubernetes (k8s) cluster diagnosis (generic, not EKS-specific).
# Usage:
#   ./k8s-diagnose.sh            # prints to stdout
#   ./k8s-diagnose.sh --quiet    # less verbose
#   ./k8s-diagnose.sh --output report.txt
#
set -eo pipefail
IFS=$'\n\t'

# ---------- Config ----------
NAMESPACE_DEFAULT="default"
TIMEOUT_SHORT=10
TIMEOUT_LONG=60

# ---------- CLI args ----------
QUIET=0
OUTPUT_FILE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --quiet|-q) QUIET=1; shift ;;
    --output|-o) OUTPUT_FILE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

# ---------- Colors ----------
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

log()    { if [ $QUIET -eq 0 ]; then echo -e "$@"; fi }
info()   { log "${BLUE}ℹ ${1}${NC}"; }
ok()     { log "${GREEN}✓ ${1}${NC}"; }
warn()   { log "${YELLOW}⚠ ${1}${NC}"; }
err()    { log "${RED}✗ ${1}${NC}"; }

# If OUTPUT_FILE specified, tee outputs there
if [ -n "$OUTPUT_FILE" ]; then
  # ensure parent dir exists
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  # re-run script and tee both stdout/stderr
  if [ -t 1 ]; then
    # interactive terminal
    exec > >(tee -a "$OUTPUT_FILE") 2>&1
  else
    exec >>"$OUTPUT_FILE" 2>&1
  fi
fi

header() {
  echo -e "\n${BLUE}====================================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}====================================================================${NC}"
}

check_prereqs() {
  header "STEP 0: Prerequisites"
  if ! command -v kubectl >/dev/null 2>&1; then
    err "kubectl not found in PATH. Install kubectl and configure kubeconfig."
    exit 1
  fi

  if ! kubectl version --client >/dev/null 2>&1; then
    err "kubectl client not available or failing."
    exit 1
  fi

  if ! kubectl cluster-info >/dev/null 2>&1; then
    err "kubectl cannot reach the cluster. Check KUBECONFIG or kube-apiserver."
    exit 1
  fi
  ok "kubectl present and cluster reachable."
}

check_api_server() {
  header "STEP 1: API server & cluster basic info"
  kubectl version 
  echo ""
  info "kubectl cluster-info (first lines):"
  kubectl cluster-info | sed -n '1,6p' || true

  info "API Server health (readyz):"
  if kubectl get --raw='/readyz' >/dev/null 2>&1; then
    ok "API server readyz OK"
  else
    warn "API server readyz returned non-200 or unreachable"
  fi
}

check_nodes() {
  header "STEP 2: Nodes - status, conditions, kubelet"
  kubectl get nodes -o wide
  echo ""

  # list nodes not ready
  UNREADY=$(kubectl get nodes --no-headers | awk '$2!="Ready"{print $1}' || true)
  if [ -z "$UNREADY" ]; then
    ok "All nodes report Ready"
  else
    warn "Nodes not Ready: $UNREADY"
    for n in $UNREADY; do
      info "Describe node $n (Conditions summary):"
      kubectl describe node "$n" | awk '/Conditions:/{flag=1;next}/Non-terminated Pods:/{flag=0}flag' | sed 's/^/  /'
    done
  fi

  info "Node kubelet versions & addresses:"
  kubectl get nodes -o custom-columns=NAME:.metadata.name,KERNEL:.status.nodeInfo.kernelVersion,KUBELET:.status.nodeInfo.kubeletVersion,INTERNAL:.status.addresses[*].address --no-headers
}

check_control_plane() {
  header "STEP 3: Control plane components (kube-system)"
  info "Listing kube-system pods (wide):"
  kubectl get pods -n kube-system -o wide
  echo ""

  # Check common control-plane components
  for comp in kube-apiserver kube-controller-manager kube-scheduler etcd; do
    # these may be static or run only on control-plane node
    P=$(kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name --no-headers | grep -i "$comp" || true)
    if [ -n "$P" ]; then
      ok "Found $comp pods"
    else
      warn "No obvious $comp pod detected in kube-system (may be static pods or named differently)."
    fi
  done
}

detect_cni() {
  header "STEP 4: CNI Detection and status"

  # list of label selectors to try (common CNI providers)
  declare -A CNIS
  CNIS["calico"]="calico-system:calico-node;k8s-app=calico-node"
  CNIS["cilium"]="kube-system:cilium;cilium.io/name=cilium"
  CNIS["flannel"]="kube-system:flannel:kube-flannel"
  CNIS["weave"]="kube-system:weave-net:k8s-app=weave-net"
  CNIS["canal"]="kube-system:flannel;k8s-app=canal"
  CNIS["aws-vpc-cni"]="kube-system:aws-node;k8s-app=aws-node"
  CNIS["kube-router"]="kube-system:kube-router:kube-router"
  CNIS["multus"]="kube-system:multus/multus"

  FOUND=0
  for key in "${!CNIS[@]}"; do
    v=${CNIS[$key]}
    # try to parse v parts (format ns:label or ns:label:key)
    IFS=':' read -r ns label <<<"$v"
    # label may contain slash; fallback to grepping
    PODS=$(kubectl get pods -n "$ns" -o name 2>/dev/null | grep -i "$key\|$label" || true)
    if [ -n "$PODS" ]; then
      FOUND=1
      ok "Detected CNI candidate: $key (namespace: $ns)"
      kubectl get pods -n "$ns" -o wide | grep -i "$key\|$label" || kubectl get pods -n "$ns" -o wide
      # check not ready
      NOT_READY=$(kubectl get pods -n "$ns" --field-selector=status.phase!=Running -o wide 2>/dev/null | grep -i "$key\|$label" || true)
      if [ -z "$NOT_READY" ]; then
        ok "CNI pods for $key appear Running"
      else
        warn "Some $key CNI pods are not Running:"
        echo "$NOT_READY"
        info "Suggest checking CNI pod logs: kubectl -n $ns logs <pod>"
      fi
      break
    fi
  done

  if [ "$FOUND" -eq 0 ]; then
    warn "No common CNI pods found in typical namespaces. Run: kubectl get pods --all-namespaces | grep -i -E 'calico|cilium|flannel|weave|canal|aws-node|kube-router|multus'"
  fi

  # quick check: kube-proxy daemonset
  info "Checking kube-proxy daemonset status:"
  if kubectl get ds kube-proxy -n kube-system &>/dev/null; then
    kubectl get ds kube-proxy -n kube-system -o wide
  else
    warn "kube-proxy daemonset not found in kube-system (some CNIs replace it)."
  fi
}

check_pods() {
  header "STEP 5: Application Pods - failures, restarts, events"

  # Get pods not running/succeeded
  mapfile -t FAILING < <(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase --no-headers 2>/dev/null | sed '/^$/d' )
  if [ "${#FAILING[@]}" -eq 0 ]; then
    ok "No pods in Pending/Failed/CrashLoop states"
  else
    warn "Found pods that are not Running/Succeeded:"
    printf "%s\n" "${FAILING[@]}"
    echo ""
    to_show=3
    i=0
    for line in "${FAILING[@]}"; do
      ns=$(awk '{print $1}' <<<"$line")
      pod=$(awk '{print $2}' <<<"$line")
      status=$(awk '{print $3}' <<<"$line")
      info "Describing $ns/$pod (status: $status):"
      kubectl describe pod "$pod" -n "$ns" | sed -n '1,200p'
      echo ""
      info "Last logs (all containers) for $ns/$pod:"
      for c in $(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[*].name}'); do
        echo "---- container: $c ----"
        kubectl logs "$pod" -n "$ns" -c "$c" --tail=30 2>/dev/null || kubectl logs "$pod" -n "$ns" -c "$c" --tail=30 --previous 2>/dev/null || echo "  (no logs available)"
      done
      echo ""
      ((i++))
      if [ $i -ge $to_show ]; then break; fi
    done
  fi

  # High restart count pods
  header "Fast-check: High restart pods (last 24h)"
  kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,RESTARTS:.status.containerStatuses[*].restartCount --no-headers | awk '$3+0>0{print $0}' | sort -k3 -nr | head -n 10 || true
}

check_services_endpoints() {
  header "STEP 6: Services & Endpoints (incl. LoadBalancer/Ingress checks)"
  kubectl get svc --all-namespaces -o wide
  echo ""

  # endpoints check for services without endpoints
  warn_count=0
  mapfile -t SVCS < <(kubectl get svc --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,TYPE:.spec.type --no-headers)
  for s in "${SVCS[@]}"; do
    ns=$(awk '{print $1}' <<<"$s")
    name=$(awk '{print $2}' <<<"$s")
    ep_count=$(kubectl get endpoints -n "$ns" "$name" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)
    if [ -z "$ep_count" ] && [ "$(kubectl get svc -n "$ns" "$name" -o jsonpath='{.spec.type}' 2>/dev/null)" = "ClusterIP" ]; then
      echo -e "${YELLOW}Service $ns/$name has NO endpoints${NC}"
      warn_count=$((warn_count+1))
    fi
  done
  if [ $warn_count -eq 0 ]; then ok "All ClusterIP services have endpoints (or are intentionally headless)"; fi

  # Ingress resources
  if kubectl get ingress --all-namespaces &>/dev/null; then
    info "Ingress resources:"
    kubectl get ingress --all-namespaces -o wide
  fi
}

check_storage() {
  header "STEP 7: Storage (PV/PVC/StorageClass)"
  kubectl get sc || warn "No StorageClass found"
  kubectl get pv
  kubectl get pvc --all-namespaces -o wide
  # show PVCs not Bound
  PVC_NOT_BOUND=$(kubectl get pvc --all-namespaces --field-selector=status.phase!=Bound -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase --no-headers | sed '/^$/d' || true)
  if [ -n "$PVC_NOT_BOUND" ]; then
    warn "Some PVCs are not Bound:"
    echo "$PVC_NOT_BOUND"
  else
    ok "All PVCs are Bound (or none exist)."
  fi
}

check_dns_resolution() {
  header "STEP 8: DNS (CoreDNS) functionality test"
  # find a running coredns pod
  COREDNS_POD=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "$COREDNS_POD" ]; then
    warn "Could not find CoreDNS pod with label k8s-app=kube-dns. Try 'kubectl get pods -n kube-system'."
    return
  fi
  ok "Using CoreDNS pod: $COREDNS_POD"
  # run a DNS query from a busybox ephemeral pod
  kubectl run --rm -n "$NAMESPACE_DEFAULT" dns-test --image=busybox --restart=Never --command -- nslookup kubernetes.default.svc.cluster.local || warn "DNS lookup failed (nslookup)."
}

check_recent_events() {
  header "STEP 9: Recent Warnings / Errors (Cluster-wide events)"
  kubectl get events --all-namespaces --sort-by='.lastTimestamp' --field-selector type!=Normal -o wide | tail -n 50 || true
}

final_summary() {
  header "SUMMARY & SUGGESTED ACTIONS"
  echo "• If CNI pods are not Running, investigate CNI logs and ensure kubelet CNI dir (/etc/cni/net.d) has conf files."
  echo "• If pods show ImagePullBackOff, check image name/registry/auth and node network outbound access."
  echo "• If pods are CrashLoopBackOff inspect logs and check liveness/readiness probes or missing env/secret."
  echo "• If PVCs are not Bound, check StorageClass & PV provisioning (and CSI driver)."
  echo "• If CoreDNS fails, check kube-proxy/CNI and network routes between pods."
  echo ""
  ok "Diagnosis complete. Review above output for the most actionable clues."
  echo ""
}

# ------------- Execute checks -------------
check_prereqs
check_api_server
check_nodes
check_control_plane
detect_cni
check_pods
check_services_endpoints
check_storage
check_dns_resolution
check_recent_events
final_summary
