# Quick Reference Card - Kubernetes Cluster Management

## 🚀 Essential Commands

### Cluster Status
```bash
# All nodes
kubectl get nodes -o wide

# All pods
kubectl get pods -A

# Services
kubectl get svc -n default

# Everything
kubectl get all -n default
```

### Application Management
```bash
# Deploy
kubectl apply -f kubernetes/base/deployments/

# Remove
kubectl delete deployment <name> -n default

# Restart
kubectl rollout restart deployment/<name> -n default

# Check status
kubectl get deployment <name> -n default -o wide
```

### Debugging
```bash
# Pod logs
kubectl logs <pod-name>

# Last 100 lines
kubectl logs <pod-name> --tail=100

# Follow logs
kubectl logs <pod-name> -f

# Previous container (if crashed)
kubectl logs <pod-name> --previous

# Pod details
kubectl describe pod <pod-name>

# Enter pod
kubectl exec -it <pod-name> -- /bin/bash

# Check environment
kubectl exec <pod-name> -- env
```

### Network Testing
```bash
# Test DNS
kubectl run -it --rm test --image=busybox --restart=Never -- \
  nslookup discovery-server.default.svc.cluster.local

# Test connectivity
kubectl run -it --rm test --image=busybox --restart=Never -- \
  wget -O- http://discovery-server.default.svc.cluster.local:8761

# Port forward
kubectl port-forward svc/api-gateway 8080:8080
```

## 📊 Setup Commands

### Fresh Cluster Setup
```bash
cd /home/ganil/spring-petclinic-microservices/ansible
ansible-playbook -i inventory.ini playbooks/k8s-cluster-roles.yml -v
```
**Time**: 15-20 minutes

### Deploy Applications
```bash
bash /home/ganil/spring-petclinic-microservices/kubernetes/scripts/setup-cluster-and-deploy.sh
```
**Time**: 5-10 minutes

### Fix Kubeconfig
```bash
sudo bash /home/ganil/spring-petclinic-microservices/kubernetes/scripts/setup-kubeconfig.sh
```
**Time**: 1 minute

### Run Diagnostics
```bash
bash /home/ganil/spring-petclinic-microservices/scripts/full-diagnostic.sh
```
**Time**: 2 minutes

## 🔍 Troubleshooting Quick Guide

### Pod is Pending
```bash
# Check why
kubectl describe pod <pod-name>

# Common causes: insufficient resources, node selector
# Solution: Add more resources or remove node selector
```

### Pod is CrashLoopBackOff
```bash
# Check logs
kubectl logs <pod-name> --previous
kubectl logs <pod-name>

# Check environment
kubectl exec <pod-name> -- env | grep SPRING

# Test DNS
kubectl exec <pod-name> -- nslookup discovery-server.default.svc.cluster.local
```

### Service not accessible
```bash
# Check service exists
kubectl get svc <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# Test from pod
kubectl run -it --rm test --image=busybox --restart=Never -- \
  wget -O- http://<service-name>:<port>/
```

### DNS not working
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system | grep coredns

# Check DNS config
kubectl get configmap coredns -n kube-system -o yaml | grep -A 5 "Corefile"

# Test DNS from pod
kubectl run -it --rm test --image=busybox --restart=Never -- nslookup kubernetes.default
```

### Node not Ready
```bash
# Check node status
kubectl describe node <node-name>

# SSH to node
ssh ec2-user@<node-ip>

# Check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# Check containerd
sudo systemctl status containerd
```

## 📋 Monitoring Checklist

**Daily**:
- [ ] All nodes are Ready: `kubectl get nodes`
- [ ] All pods are Running: `kubectl get pods -A`
- [ ] No error events: `kubectl get events -A`

**Weekly**:
- [ ] Resource usage: `kubectl top nodes`
- [ ] Pod logs: `kubectl logs -A` (check for errors)
- [ ] Disk space: `df -h` on nodes

**Monthly**:
- [ ] Kubernetes updates available
- [ ] Container image updates
- [ ] Security patches
- [ ] Capacity planning

## 🛠️ Useful Aliases

Add to `~/.bashrc`:
```bash
alias k='kubectl'
alias kgp='kubectl get pods'
alias kga='kubectl get pods -A'
alias kgn='kubectl get nodes -o wide'
alias kgs='kubectl get svc'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
```

## 📁 Key Directories

```
ansible/               - Ansible playbooks and roles
├── playbooks/        - Playbook files
├── roles/            - Reusable roles
└── inventory.ini     - Host inventory

kubernetes/           - Kubernetes manifests
├── base/deployments/ - Microservice deployments
└── scripts/          - Deployment scripts

scripts/              - Utility scripts
└── full-diagnostic.sh - Complete diagnostics
```

## 🔐 Kubeconfig Locations

```bash
# Root user
/root/.kube/config

# ec2-user
/home/ec2-user/.kube/config

# System-wide
/etc/kubernetes/admin.conf

# Set kubeconfig
export KUBECONFIG=/path/to/config
```

## 📞 Emergency Contacts

For issues:
1. Check logs: `kubectl logs <pod>`
2. Describe pod: `kubectl describe pod <pod>`
3. Run diagnostics: `bash scripts/full-diagnostic.sh`
4. Check documentation: See root README files

## 💾 Important Files to Backup

- `~/.kube/config` or `/root/.kube/config`
- `/etc/kubernetes/pki/` (certificates)
- Deployment manifests
- Configuration files

## ⏱️ Common Timeouts

| Operation | Timeout |
|-----------|---------|
| Pod startup | 5 minutes |
| Node join | 10 minutes |
| Cluster init | 15 minutes |
| API server ready | 2 minutes |
| Service endpoint | 30 seconds |

## 📚 Documentation Links

- `QUICK_START.md` - Setup guide
- `FIXES_SUMMARY.md` - What was fixed
- `ANSIBLE_ROLES_SETUP.md` - Ansible details
- `IMPLEMENTATION_CHECKLIST.md` - Track progress

## 🎯 Success Indicators

✓ All nodes show "Ready"  
✓ All pods show "Running"  
✓ No "CrashLoopBackOff" pods  
✓ Services have valid endpoints  
✓ DNS resolution works  
✓ Microservices communicate  
✓ Logs show no errors  

## 🚨 Red Flags

✗ Nodes in "NotReady" state  
✗ Pods in "Pending" or "CrashLoopBackOff"  
✗ Services with no endpoints  
✗ DNS resolution failures  
✗ High error rates in logs  
✗ Resource exhaustion  
✗ Network connectivity issues  

---

**Print this card and keep it handy!**  
**Last Updated**: December 8, 2025
