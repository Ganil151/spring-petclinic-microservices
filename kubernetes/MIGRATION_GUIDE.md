# K8s to K3s Migration Guide

## Quick Reference

### Migration Scripts Created

| Script | Purpose | Run On |
|--------|---------|--------|
| `migrate-k8s-to-k3s.sh` | **Master script** - Orchestrates entire migration | Master node |
| `uninstall-k8s-master.sh` | Removes K8s from master | Master node |
| `uninstall-k8s-worker.sh` | Removes K8s from worker | Worker nodes |
| `k3s_server.sh` | Installs K3s server | Master node (after reboot) |
| `k3s_agent.sh` | Installs K3s agent | Worker nodes (optional) |
| `deploy-to-k3s.sh` | Deploys Spring Petclinic | K3s server |

## Recommended Migration Path

### Option 1: Automated Migration (Recommended)

```bash
# On K8s Master
cd ~/spring-petclinic-microservices/kubernetes/scripts/
chmod +x migrate-k8s-to-k3s.sh
./migrate-k8s-to-k3s.sh

# After reboot
bash ~/install-k3s-after-reboot.sh

# Deploy application
cd ~/spring-petclinic-microservices/kubernetes/scripts/
bash deploy-to-k3s.sh
```

### Option 2: Manual Step-by-Step

#### On Master Node:

```bash
# 1. Backup (optional but recommended)
kubectl get all --all-namespaces -o yaml > k8s-backup.yaml

# 2. Uninstall K8s
cd ~/spring-petclinic-microservices/kubernetes/scripts/
chmod +x uninstall-k8s-master.sh
./uninstall-k8s-master.sh

# 3. Reboot
sudo reboot

# 4. After reboot - Install K3s
cd ~/spring-petclinic-microservices/terraform/app/scripts/
chmod +x k3s_server.sh
./k3s_server.sh

# 5. Deploy application
cd ~/spring-petclinic-microservices/kubernetes/scripts/
chmod +x deploy-to-k3s.sh
./deploy-to-k3s.sh
```

#### On Worker Nodes (if you had them):

```bash
# 1. Uninstall K8s
cd ~/spring-petclinic-microservices/kubernetes/scripts/
chmod +x uninstall-k8s-worker.sh
./uninstall-k8s-worker.sh

# 2. Reboot
sudo reboot

# 3. After reboot - Join K3s cluster (optional)
# Get token from master first:
# ssh ec2-user@<master-ip> "sudo cat /var/lib/rancher/k3s/server/node-token"

export K3S_SERVER_IP="<master-ip>"
export K3S_TOKEN="<token-from-master>"
cd ~/spring-petclinic-microservices/terraform/app/scripts/
chmod +x k3s_agent.sh
./k3s_agent.sh
```

## What Each Script Does

### migrate-k8s-to-k3s.sh
- ✅ Detects if master or worker
- ✅ Backs up all Kubernetes resources (master only)
- ✅ Calls appropriate uninstall script
- ✅ Creates post-reboot installation script
- ✅ Optionally reboots the server

### uninstall-k8s-master.sh
- ✅ Drains the node
- ✅ Resets kubeadm
- ✅ Removes all K8s packages
- ✅ Deletes configuration files
- ✅ Removes network interfaces (CNI, Calico, Flannel)
- ✅ Cleans iptables rules
- ✅ Removes etcd data
- ✅ Optionally cleans Docker

### uninstall-k8s-worker.sh
- ✅ Resets kubeadm
- ✅ Removes all K8s packages
- ✅ Deletes configuration files
- ✅ Removes network interfaces
- ✅ Cleans iptables rules
- ✅ Optionally cleans Docker

### k3s_server.sh
- ✅ Installs K3s in ~2 minutes
- ✅ Configures kubectl automatically
- ✅ Installs Helm
- ✅ Installs metrics-server
- ✅ Creates petclinic namespace
- ✅ Saves node token for workers

## Important Notes

### Before Migration

1. **Backup your data** - The migration script backs up K8s resources, but verify you have everything
2. **Note your configuration** - Document any custom settings
3. **Check dependencies** - Ensure you have the repository cloned

### During Migration

1. **Reboot is required** - Clean slate ensures no conflicts
2. **Takes ~10-15 minutes** - Uninstall + reboot + K3s install
3. **Internet required** - K3s downloads from the internet

### After Migration

1. **Verify K3s is running**: `kubectl get nodes`
2. **Deploy application**: `bash deploy-to-k3s.sh`
3. **Monitor pods**: `kubectl get pods -w`
4. **Access application**: Check the URL shown by deploy script

## Troubleshooting

### Uninstall script fails
```bash
# Manually clean up
sudo kubeadm reset -f
sudo rm -rf /etc/kubernetes/ /var/lib/kubelet/ /var/lib/etcd/
sudo reboot
```

### K3s installation fails
```bash
# Check logs
sudo journalctl -u k3s -f

# Reinstall
curl -sfL https://get.k3s.io | sh -
```

### kubectl not working after K3s install
```bash
# Reconfigure
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

### Pods still failing after migration
```bash
# Check logs
kubectl logs <pod-name>

# Restart deployment
kubectl rollout restart deployment/<deployment-name>

# Check resources
kubectl describe pod <pod-name>
```

## Rollback Plan

If you need to go back to K8s:

```bash
# 1. Uninstall K3s
/usr/local/bin/k3s-uninstall.sh

# 2. Reboot
sudo reboot

# 3. Reinstall K8s
cd ~/spring-petclinic-microservices/terraform/app/scripts/
bash k8s_master.sh  # or k8s_worker.sh

# 4. Restore from backup
kubectl apply -f ~/k8s-backup-*/all-resources.yaml
```

## Benefits After Migration

- ⚡ **Faster startup** - K3s boots in ~30 seconds vs 2-3 minutes
- 💾 **Lower memory** - ~512MB vs ~2GB
- 🔧 **Easier management** - Single binary, auto-configured
- ✅ **Same functionality** - All your apps work the same way

## Timeline

| Step | Time |
|------|------|
| Backup | 1-2 min |
| Uninstall K8s | 2-3 min |
| Reboot | 1-2 min |
| Install K3s | 2-5 min |
| Deploy apps | 2-3 min |
| **Total** | **~10-15 min** |

## Next Steps After Migration

1. **Test your application** - Verify everything works
2. **Update documentation** - Note the change to K3s
3. **Update CI/CD** - If using Jenkins, update kubeconfig path
4. **Monitor performance** - Check resource usage improvements
5. **Consider EKS** - For production, plan migration to AWS EKS

## Questions?

- K3s docs: https://docs.k3s.io/
- K3s vs K8s: See `K3S_VS_K8S.md`
- Issues: Check logs with `kubectl logs` and `journalctl -u k3s`
