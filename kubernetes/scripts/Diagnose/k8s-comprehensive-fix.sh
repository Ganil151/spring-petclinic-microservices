#!/usr/bin/env bash
# k8s-comprehensive-fix.sh
# Comprehensive Kubernetes diagnosis & safe-fix tool (containerd-focused)
#
# Usage:
#   ./k8s-comprehensive-fix.sh            # diagnose only
#   ./k8s-comprehensive-fix.sh --auto     # attempt safe fixes (review output!)
#   ./k8s-comprehensive-fix.sh --collect  # collect logs & artifacts to ./k8s-diagnostics-<ts>.tgz
#   ./k8s-comprehensive-fix.sh --generate-daemonset  # prints privileged DaemonSet YAML
#
set -euo pipefail
IFS=$'\n\t'

# ----------------- Configuration -----------------
DRY_RUN=1
AUTO_FIX=0
COLLECT_LOGS=0
QUIET=0
GENERATE_DAEMONSET=0

TS=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="./k8s-diagnostics-${TS}"
SUMMARY="${OUTPUT_DIR}/summary.txt"
MAX_POD_LOG_LINES=200
BUSYBOX_IMAGE="busybox:1.35.0"
CALICO_MANIFEST_URL="https://docs.projectcalico.org/manifests/calico.yaml"
LOCAL_PATH_MANIFEST="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"

# ----------------- CLI -----------------
usage(){
  cat <<EOF
Usage: $0 [--auto] [--collect] [--generate-daemonset] [--quiet]

Options:
  --auto                Attempt safe automatic fixes (default: diagnose-only)
  --collect             Collect logs & artifacts to ${OUTPUT_DIR} (implies diagnosis + artifacts)
  --generate-daemonset  Print a privileged DaemonSet YAML (for host log collection)
  --quiet               Minimal output
  --help                Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto) AUTO_FIX=1; DRY_RUN=0; shift ;;
    --collect) COLLECT_LOGS=1; shift ;;
    --generate-daemonset) GENERATE_DAEMONSET=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

# ---------- Output helpers ----------
log(){ if [ "$QUIET" -eq 0 ]; then echo -e "$@"; fi; }
info(){ log "\033[34mℹ $1\033[0m"; }
ok(){ log "\033[32m✓ $1\033[0m"; echo "OK: $1" >> "$SUMMARY"; }
warn(){ log "\033[33m⚠ $1\033[0m"; echo "WARN: $1" >> "$SUMMARY"; }
fail(){ log "\033[31m✗ $1\033[0m"; echo "FAIL: $1" >> "$SUMMARY"; }

mkdir -p "$OUTPUT_DIR"
: > "$SUMMARY"

# ---------- Helpers ----------
run_or_dry(){
  # run_or_dry "description" kubectl ...args...
  local desc="$1"; shift
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[DRY-RUN] $desc -> kubectl $*"
  else
    info "$desc"
    kubectl "$@"
  fi
}

# ---------- Check prerequisites & API health ----------
check_prereqs_and_api(){
  echo "" >> "$SUMMARY"
  echo "K8S DIAGNOSIS START: $(date)" >> "$SUMMARY"

  info "Checking for kubectl..."
  if ! command -v kubectl >/dev/null 2>&1; then
    fail "kubectl not found in PATH. Install kubectl and configure KUBECONFIG."
    exit 1
  fi
  ok "kubectl found"

  info "Testing API server health (/healthz)..."
  # Use raw endpoint to avoid false negatives from cluster-info messages
  if kubectl get --raw /healthz >/dev/null 2>&1; then
    ok "API server reachable and healthy (/healthz ok)"
  else
    fail "kubectl client cannot reach Kubernetes API server. Check KUBECONFIG, context, and kube-apiserver."
    # Print helpful diagnostics to help user fix kubeconfig
    info "Troubleshooting tips:"
    echo " - Ensure KUBECONFIG is set (echo \$KUBECONFIG) or ~/.kube/config exists" >> "$SUMMARY"
    echo " - Show contexts: kubectl config get-contexts" >> "$SUMMARY"
    echo " - Try: kubectl get nodes or kubectl get --raw /healthz from the control-plane host" >> "$SUMMARY"
    exit 1
  fi
}

# ---------- Runtime detection ----------
detect_runtime(){
  info "Detecting container runtime (containerd expected)..."
  if command -v crictl >/dev/null 2>&1; then
    RUNTIME="containerd"
    ok "crictl available; assuming containerd runtime"
  else
    # try to infer from kubelet info
    if kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}' 2>/dev/null | grep -qi containerd; then
      RUNTIME="containerd"
      ok "Nodes report containerd as runtime"
    else
      RUNTIME="unknown"
      warn "Could not detect crictl/containerd automatically. Install crictl for better runtime ops."
    fi
  fi
  echo "Runtime: $RUNTIME" >> "$SUMMARY"
}

# ---------- Cluster checks ----------
check_cluster_basic(){
  info "Collecting basic cluster info"
  kubectl version --short > "${OUTPUT_DIR}/kubectl-version.txt" 2>/dev/null || true
  kubectl cluster-info > "${OUTPUT_DIR}/cluster-info.txt" 2>/dev/null || true
  ok "Collected basic cluster info"
}

check_nodes(){
  info "Checking nodes (status & conditions)"
  kubectl get nodes -o wide | tee "${OUTPUT_DIR}/nodes.txt"
  NOT_READY=$(kubectl get nodes --no-headers | awk '$2!="Ready" {print $1}' || true)
  if [ -z "$NOT_READY" ]; then
    ok "All nodes are Ready"
  else
    warn "Nodes not Ready: $NOT_READY"
    for n in $NOT_READY; do
      info "Describing node $n (conditions summary)"
      kubectl describe node "$n" > "${OUTPUT_DIR}/node-${n}-describe.txt" || true
    done
  fi
  kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.kubeletVersion}{"\n"}{end}' > "${OUTPUT_DIR}/kubelet-versions.txt" || true
}

check_control_plane(){
  info "Listing kube-system pods (control-plane components)"
  kubectl get pods -n kube-system -o wide | tee "${OUTPUT_DIR}/kube-system-pods.txt"
  for comp in kube-apiserver kube-controller-manager kube-scheduler etcd; do
    if kubectl get pods -n kube-system -o name | grep -qi "$comp"; then
      ok "Control-plane component detected: $comp"
    else
      warn "Component $comp not obviously present in kube-system (may be static on host)"
    fi
  done
}

detect_cni(){
  info "Detecting CNI providers"
  kubectl get pods --all-namespaces -o wide | tee "${OUTPUT_DIR}/all-pods.txt"
  CNI_FOUND=0
  for label in "calico" "cilium" "flannel" "weave" "canal" "aws-node" "kube-router" "multus"; do
    if grep -qi "$label" "${OUTPUT_DIR}/all-pods.txt"; then
      info "CNI candidate detected: $label"
      CNI_FOUND=1
    fi
  done
  if [ "$CNI_FOUND" -eq 0 ]; then
    warn "No common CNI pods found. Networking will be broken until a CNI is installed."
    echo "No common CNI pods found" >> "$SUMMARY"
  else
    ok "CNI candidate(s) detected"
  fi
  echo "CNI_FOUND=$CNI_FOUND" >> "$SUMMARY"
}

check_kube_proxy(){
  if kubectl get ds kube-proxy -n kube-system >/dev/null 2>&1; then
    kubectl get ds kube-proxy -n kube-system -o wide > "${OUTPUT_DIR}/kube-proxy-ds.txt"
    ok "kube-proxy daemonset present"
  else
    warn "kube-proxy daemonset not present in kube-system (some CNIs replace it)"
  fi
}

check_pods(){
  info "Checking pod health across all namespaces"
  kubectl get pods --all-namespaces -o wide > "${OUTPUT_DIR}/pods-all.txt"
  NON_READY=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase --no-headers | sed '/^$/d' || true)
  if [ -z "$NON_READY" ]; then
    ok "No non-Running pods found"
  else
    warn "Non-Running/Failing pods detected (see ${OUTPUT_DIR}/non-ready-pods.txt)"
    echo "$NON_READY" | tee "${OUTPUT_DIR}/non-ready-pods.txt"
    echo "$NON_READY" | head -n 10 | while read -r ns pod status; do
      info "Describing $ns/$pod"
      kubectl describe pod -n "$ns" "$pod" > "${OUTPUT_DIR}/${ns}-${pod}-describe.txt" || true
      info "Collecting logs for $ns/$pod"
      for c in $(kubectl get pod -n "$ns" "$pod" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || echo ""); do
        kubectl logs -n "$ns" "$pod" -c "$c" --tail="$MAX_POD_LOG_LINES" > "${OUTPUT_DIR}/${ns}-${pod}-${c}-logs.txt" 2>/dev/null || true
      done
    done
  fi
}

check_services_endpoints(){
  info "Checking Services & Endpoints"
  kubectl get svc --all-namespaces -o wide > "${OUTPUT_DIR}/services.txt"
  # find services without endpoints
  NO_EP=$(kubectl get endpoints --all-namespaces -o json | grep -E '"subsets":\s*\[\s*\]' -B1 -n 2>/dev/null || true)
  if [ -n "$NO_EP" ]; then
    warn "Some services have no endpoints. See ${OUTPUT_DIR}/services.txt"
    echo "$NO_EP" > "${OUTPUT_DIR}/services-no-endpoints.txt"
  else
    ok "Services endpoints appear present"
  fi
  if kubectl get ingress --all-namespaces >/dev/null 2>&1; then
    kubectl get ingress --all-namespaces -o wide > "${OUTPUT_DIR}/ingress.txt"
    ok "Ingress resources listed"
  fi
}

check_storage(){
  info "Checking StorageClasses, PVs, PVCs"
  kubectl get sc -o wide > "${OUTPUT_DIR}/storageclasses.txt" || true
  kubectl get pv -o wide > "${OUTPUT_DIR}/pv.txt" || true
  kubectl get pvc --all-namespaces -o wide > "${OUTPUT_DIR}/pvc.txt" || true
  PVC_PENDING=$(kubectl get pvc --all-namespaces --field-selector=status.phase!=Bound -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase --no-headers | sed '/^$/d' || true)
  if [ -n "$PVC_PENDING" ]; then
    warn "Unbound PVCs found (see ${OUTPUT_DIR}/pvc-not-bound.txt)"
    echo "$PVC_PENDING" | tee "${OUTPUT_DIR}/pvc-not-bound.txt"
  else
    ok "PVCs are Bound"
  fi
}

check_coredns(){
  info "Checking CoreDNS and DNS resolution"
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide > "${OUTPUT_DIR}/coredns.txt" 2>/dev/null || true
  if [ ! -s "${OUTPUT_DIR}/coredns.txt" ]; then
    kubectl get pods -n kube-system -l k8s-app=coredns -o wide > "${OUTPUT_DIR}/coredns.txt" 2>/dev/null || true
  fi
  if [ -s "${OUTPUT_DIR}/coredns.txt" ]; then
    ok "CoreDNS pods found"
  else
    warn "CoreDNS pods not found with standard labels"
  fi

  info "Testing DNS resolution from a temporary busybox pod (nslookup kubernetes.default.svc.cluster.local)"
  if kubectl run --rm -i --tty --restart=Never dns-test --image="$BUSYBOX_IMAGE" -- nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1; then
    ok "DNS resolution inside cluster succeeded"
  else
    warn "DNS lookup failed from pod - investigate CoreDNS, CNI, kube-proxy"
  fi
}

# ---------- Safe remediation functions (only run if AUTO_FIX=1) ----------
attempt_fix_cni(){
  # Only try if no CNI detected
  if grep -Ei 'calico|cilium|flannel|weave|canal|aws-node|kube-router|multus' "${OUTPUT_DIR}/all-pods.txt" >/dev/null 2>&1; then
    ok "CNI present; skipping CNI install"
    return
  fi
  warn "No CNI detected. Attempting to install Calico (suitable for many k8s clusters, not EKS)."
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[DRY-RUN] kubectl apply -f $CALICO_MANIFEST_URL"
  else
    kubectl apply -f "$CALICO_MANIFEST_URL" && ok "Calico manifest applied (monitor pods in kube-system/calico-system)" || fail "Failed to apply Calico manifest"
  fi
}

attempt_restart_kube_proxy(){
  if kubectl get ds kube-proxy -n kube-system >/dev/null 2>&1; then
    info "Rolling restart of kube-proxy daemonset"
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[DRY-RUN] kubectl rollout restart ds/kube-proxy -n kube-system"
    else
      kubectl rollout restart ds/kube-proxy -n kube-system && ok "kube-proxy restarted" || warn "kube-proxy restart failed"
    fi
  else
    warn "kube-proxy not present; skipping"
  fi
}

attempt_restart_coredns(){
  if kubectl get deployment coredns -n kube-system >/dev/null 2>&1; then
    info "Restarting CoreDNS deployment"
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[DRY-RUN] kubectl rollout restart deployment/coredns -n kube-system"
    else
      kubectl rollout restart deployment/coredns -n kube-system && ok "CoreDNS restarted" || warn "CoreDNS restart failed"
    fi
  else
    warn "CoreDNS deployment not found"
  fi
}

attempt_fix_imagepulls(){
  info "Looking for ImagePullBackOff / ErrImagePull pods"
  mapfile -t IMG_ERRS < <(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"|"}{range .status.containerStatuses[*]}{.state.waiting.reason}{";"}{end}{"\n"}{end}' | grep -E "ImagePullBackOff|ErrImagePull" || true)
  if [ "${#IMG_ERRS[@]}" -eq 0 ]; then
    ok "No image pull errors found"
    return
  fi
  warn "Image pull errors detected"
  for l in "${IMG_ERRS[@]}"; do
    ns="${l%%|*}"
    rest="${l#*|}"
    pod="${rest%%|*}"
    info "Attempting to restart pod to retry image pull: $ns/$pod"
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[DRY-RUN] kubectl delete pod -n $ns $pod --grace-period=0 --force"
    else
      kubectl delete pod -n "$ns" "$pod" --grace-period=0 --force || warn "Failed to delete $ns/$pod"
      ok "Deleted $ns/$pod (retrying image pull)"
    fi
  done
}

attempt_fix_crashloops(){
  info "Looking for CrashLoopBackOff pods"
  mapfile -t CRASHES < <(kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"|"}{.metadata.name}{"|"}{range .status.containerStatuses[*]}{.state.waiting.reason}{";"}{end}{"\n"}{end}' | grep -E "CrashLoopBackOff" || true)
  if [ "${#CRASHES[@]}" -eq 0 ]; then
    ok "No CrashLoopBackOff pods"
    return
  fi
  warn "CrashLoopBackOff pods found"
  for l in "${CRASHES[@]}"; do
    ns="${l%%|*}"
    rest="${l#*|}"
    pod="${rest%%|*}"
    info "Collected describe and logs for $ns/$pod into ${OUTPUT_DIR}"
    kubectl describe pod -n "$ns" "$pod" > "${OUTPUT_DIR}/${ns}-${pod}-describe.txt" || true
    kubectl logs -n "$ns" "$pod" --all-containers --tail="$MAX_POD_LOG_LINES" > "${OUTPUT_DIR}/${ns}-${pod}-logs.txt" 2>/dev/null || true

    # If readiness/liveness failure is present, optionally increase initialDelaySeconds on parent deployment (best-effort)
    if kubectl describe pod -n "$ns" "$pod" | grep -i -E "Readiness probe failed|Liveness probe failed" >/dev/null 2>&1; then
      warn "Probe failures detected for $ns/$pod"
      owner_name=$(kubectl get pod -n "$ns" "$pod" -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null || true)
      owner_kind=$(kubectl get pod -n "$ns" "$pod" -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null || true)
      if [ -n "$owner_name" ] && [ -n "$owner_kind" ]; then
        info "Pod parent: $owner_kind/$owner_name"
        if [ "$DRY_RUN" -eq 1 ]; then
          info "[DRY-RUN] Would patch $owner_kind/$owner_name to increase initialDelaySeconds for probes"
        else
          # best-effort patch: set first container probe delays to 60s if present
          kubectl patch "$owner_kind" "$owner_name" -n "$ns" --type='json' -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/initialDelaySeconds","value":60},{"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/initialDelaySeconds","value":60}]' 2>/dev/null || true
          kubectl rollout restart "$owner_kind" "$owner_name" -n "$ns" || true
          ok "Patched and restarted $owner_kind/$owner_name (best-effort)"
        fi
      fi
    else
      # gentle restart: delete pod so it restarts
      if [ "$DRY_RUN" -eq 1 ]; then
        info "[DRY-RUN] kubectl delete pod -n $ns $pod --grace-period=0 --force"
      else
        kubectl delete pod -n "$ns" "$pod" --grace-period=0 --force || true
        ok "Restarted $ns/$pod"
      fi
    fi
  done
}

attempt_fix_pvcs(){
  PVC_PENDING=$(kubectl get pvc --all-namespaces --field-selector=status.phase!=Bound -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,STATUS:.status.phase --no-headers | sed '/^$/d' || true)
  if [ -z "$PVC_PENDING" ]; then
    ok "No unbound PVCs"
    return
  fi
  warn "Unbound PVCs found"
  if kubectl get sc --no-headers >/dev/null 2>&1; then
    info "StorageClass exists; inspect CSI drivers / provisioner pods"
    kubectl get pods -n kube-system | grep -i csi || true
    echo "$PVC_PENDING" > "${OUTPUT_DIR}/pvc-not-bound.txt"
  else
    warn "No StorageClass present. Installing local-path provisioner (suitable for dev/single-node clusters)"
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[DRY-RUN] kubectl apply -f $LOCAL_PATH_MANIFEST"
    else
      kubectl apply -f "$LOCAL_PATH_MANIFEST" && ok "local-path provisioner installed" || warn "local-path install failed"
    fi
  fi
}

# ---------- Log collection ----------
collect_pod_logs(){
  info "Collecting logs for non-ready pods into $OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR/pod-logs"
  NONREADY=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name --no-headers | sed '/^$/d' || true)
  echo "$NONREADY" > "${OUTPUT_DIR}/non-ready-list.txt"
  while read -r ns pod; do
    [ -z "$ns" ] && continue
    for c in $(kubectl get pod -n "$ns" "$pod" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null || echo ""); do
      kubectl logs -n "$ns" "$pod" -c "$c" --tail="$MAX_POD_LOG_LINES" > "${OUTPUT_DIR}/pod-logs/${ns}_${pod}_${c}.log" 2>/dev/null || true
    done
  done <<< "$(echo "$NONREADY")"
  ok "Collected pod logs"
}

generate_daemonset_yaml(){
  cat <<'YAML'
# privileged-node-collector-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-log-collector
  namespace: kube-system
spec:
  selector:
    matchLabels:
      name: node-log-collector
  template:
    metadata:
      labels:
        name: node-log-collector
    spec:
      hostPID: true
      hostNetwork: true
      serviceAccountName: default
      tolerations:
      - operator: Exists
      containers:
      - name: collect
        image: busybox
        securityContext:
          privileged: true
        command:
        - sh
        - -c
        - |
          mkdir -p /host-logs && cp -r /var/log /host-logs || true
          sleep 3600
        volumeMounts:
        - name: host-root
          mountPath: /host-logs
      volumes:
      - name: host-root
        hostPath:
          path: /tmp/node-collector
          type: DirectoryOrCreate
YAML
}

pack_and_finish(){
  info "Packaging artifacts into ${OUTPUT_DIR}.tgz"
  tar czf "${OUTPUT_DIR}.tgz" -C "$(dirname "$OUTPUT_DIR")" "$(basename "$OUTPUT_DIR")" || true
  ok "Packaged artifacts: ${OUTPUT_DIR}.tgz"
  echo "" >> "$SUMMARY"
  echo "Completed at: $(date)" >> "$SUMMARY"
  echo "Artifacts: ${OUTPUT_DIR}.tgz" >> "$SUMMARY"
  info "Summary:"
  cat "$SUMMARY"
}

# ---------- Main run ----------
info "Starting cluster diagnosis..."
check_prereqs_and_api
detect_runtime
check_cluster_basic
check_nodes
check_control_plane
detect_cni
check_kube_proxy
check_pods
check_services_endpoints
check_storage
check_coredns

if [ "$AUTO_FIX" -eq 1 ]; then
  info "AUTO_FIX enabled - attempting safe actions"
  attempt_fix_cni
  attempt_restart_kube_proxy
  attempt_restart_coredns
  attempt_fix_imagepulls
  attempt_fix_crashloops
  attempt_fix_pvcs
fi

if [ "$COLLECT_LOGS" -eq 1 ]; then
  collect_pod_logs
  generate_daemonset_yaml > "${OUTPUT_DIR}/privileged-daemonset.yaml"
  ok "Diagnostic artifacts in $OUTPUT_DIR"
fi

pack_and_finish
ok "Diagnosis complete. Review ${OUTPUT_DIR} and summary for next steps."
