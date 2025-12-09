# Implementation Checklist

## Pre-Implementation Verification

- [ ] All nodes are accessible via SSH
- [ ] Ansible is installed on control machine
- [ ] SSH keys are properly configured
- [ ] Network connectivity is verified (ping all nodes)
- [ ] Sufficient disk space on all nodes (min 30GB recommended)
- [ ] No conflicts with existing Kubernetes installation

## Implementation Steps

### Phase 1: Validate Configuration
- [ ] Review ansible/inventory.ini for correct host IPs
- [ ] Verify SSH key paths in inventory
- [ ] Test inventory: `ansible-inventory -i ansible/inventory.ini --graph`
- [ ] Test connectivity: `ansible -i ansible/inventory.ini all -m ping`
- [ ] Verify playbook syntax: `ansible-playbook ansible/playbooks/k8s-cluster-roles.yml --syntax-check`

### Phase 2: Review Deployment Changes
- [ ] Review kubernetes/base/deployments/*.yaml for FQDN updates
- [ ] Verify resource requests/limits are present
- [ ] Check environment variables for SPRING_CONFIG_IMPORT
- [ ] Verify EUREKA_CLIENT_SERVICEURL_DEFAULTZONE uses FQDN

### Phase 3: Setup Kubernetes Cluster
- [ ] Run ansible playbook: `ansible-playbook -i ansible/inventory.ini ansible/playbooks/k8s-cluster-roles.yml -v`
- [ ] Wait for all tasks to complete (10-15 minutes)
- [ ] Verify no errors in playbook output
- [ ] Check for "failed" or "error" messages

### Phase 4: Verify Cluster
- [ ] All nodes show "Ready": `kubectl get nodes`
- [ ] No nodes in "NotReady" state
- [ ] All system pods running: `kubectl get pods -n kube-system`
- [ ] CoreDNS pods are running (at least 2)
- [ ] API server is responding
- [ ] etcd is healthy
- [ ] Calico networking is working

### Phase 5: Deploy Applications
- [ ] Delete old deployments (if any)
- [ ] Apply new deployment manifests: `kubectl apply -f kubernetes/base/deployments/`
- [ ] Wait for pods to start (2-5 minutes)
- [ ] Verify all pods are running: `kubectl get pods -n default`

### Phase 6: Verify Applications
- [ ] All microservice pods show "Running"
- [ ] No "CrashLoopBackOff" pods
- [ ] No "Pending" pods
- [ ] Services are created: `kubectl get svc`
- [ ] DNS resolution works for discovery-server
- [ ] DNS resolution works for config-server
- [ ] Application logs show successful startup

### Phase 7: Final Verification
- [ ] Run full diagnostic: `bash scripts/full-diagnostic.sh`
- [ ] Review diagnostic output for any warnings
- [ ] Test service-to-service communication
- [ ] Verify all environment variables are correct
- [ ] Check pod resource usage is within limits

## Testing Checklist

### DNS Resolution Tests
- [ ] `kubectl run -it --rm test --image=busybox --restart=Never -- nslookup discovery-server.default.svc.cluster.local`
- [ ] `kubectl run -it --rm test --image=busybox --restart=Never -- nslookup config-server.default.svc.cluster.local`
- [ ] Verify responses with correct IP addresses

### Service Connectivity Tests
- [ ] From a pod, verify connectivity to discovery-server
- [ ] From a pod, verify connectivity to config-server
- [ ] Test inter-pod communication

### Application Startup Tests
- [ ] Check logs: `kubectl logs -l app=admin-server -f`
- [ ] Check logs: `kubectl logs -l app=api-gateway -f`
- [ ] Check logs: `kubectl logs -l app=customers-service -f`
- [ ] Verify all show successful startup messages

### Health Check Tests
- [ ] Verify liveness probes are passing
- [ ] Verify readiness probes are passing
- [ ] Check pod status with `kubectl describe pod <pod-name>`

## Rollback Checklist (If Needed)

- [ ] Save current configuration: `kubectl get all -n default -o yaml > backup.yaml`
- [ ] Note current cluster state
- [ ] Document any custom modifications
- [ ] Have kubeconfig backup available
- [ ] Know how to restore from backup

## Performance Benchmarks

Document baseline values:
- [ ] Pod startup time: ___ seconds
- [ ] DNS resolution time: ___ ms
- [ ] Service connectivity time: ___ ms
- [ ] Node resource usage: ___ CPU, ___ Memory
- [ ] Application response time: ___ ms

## Documentation & Knowledge Transfer

- [ ] Review QUICK_START.md
- [ ] Review FIXES_SUMMARY.md
- [ ] Review ANSIBLE_ROLES_SETUP.md
- [ ] Review CHANGES_SUMMARY.md
- [ ] Document any custom configuration
- [ ] Create runbook for future maintenance
- [ ] Document troubleshooting procedures

## Maintenance Checklist

### Regular Tasks
- [ ] Monitor cluster health: `kubectl get nodes` (daily)
- [ ] Check pod status: `kubectl get pods -A` (daily)
- [ ] Review logs for errors: `kubectl logs` (weekly)
- [ ] Check disk usage: `df -h` (weekly)
- [ ] Verify backups are working (weekly)

### Periodic Tasks
- [ ] Update Kubernetes components (monthly)
- [ ] Update container images (monthly)
- [ ] Review resource usage and capacity (monthly)
- [ ] Test disaster recovery procedures (quarterly)
- [ ] Security audit (quarterly)

## Monitoring Setup

- [ ] Prometheus is configured
- [ ] Grafana dashboards are created
- [ ] Alert rules are defined
- [ ] Log aggregation is set up (if using)
- [ ] Metrics collection is working

## Post-Implementation Sign-Off

- [ ] Technical lead: _________________ Date: _______
- [ ] Operations team: ________________ Date: _______
- [ ] Project manager: _______________ Date: _______

## Notes & Issues

**Issues Encountered**:
_________________________________________________________________

**Resolutions Applied**:
_________________________________________________________________

**Outstanding Items**:
_________________________________________________________________

**Lessons Learned**:
_________________________________________________________________

**Follow-Up Actions**:
- [ ] Item 1: ___________________
- [ ] Item 2: ___________________
- [ ] Item 3: ___________________

## Quick Reference Commands

```bash
# Cluster status
kubectl get nodes
kubectl get pods -A
kubectl cluster-info

# Deployment management
kubectl apply -f <file>
kubectl delete deployment <name>
kubectl rollout restart deployment/<name>

# Debugging
kubectl logs <pod>
kubectl describe pod <pod>
kubectl exec -it <pod> -- /bin/bash

# Diagnostics
bash scripts/full-diagnostic.sh
ansible-playbook ansible/playbooks/k8s-cluster-roles.yml --syntax-check

# Network testing
kubectl run -it --rm test --image=busybox --restart=Never -- <command>

# Kubeconfig
kubectl config view
export KUBECONFIG=~/.kube/config
```

## Contact Information

**Technical Lead**: _____________________ Phone: ____________
**Operations**: _________________________ Phone: ____________
**Project Manager**: ____________________ Phone: ____________

## Version History

- v1.0 (Initial) - Dec 8, 2025
  - Created Ansible roles structure
  - Fixed DNS resolution with FQDN
  - Added resource limits
  - Updated deployment manifests
