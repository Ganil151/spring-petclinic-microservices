# Kubernetes Worker Scripts - Error Fixes

## Scripts Reviewed and Fixed

### 1. `terraform/app/scripts/k8s_worker.sh`
### 2. `kubernetes/scripts/k8s-worker-full-setup.sh`

---

## ✅ Errors Fixed

### **Error 1: Incorrect GPG Key URL**

**Location:** Both scripts  
**Issue:** The Kubernetes repository GPG key URL was missing `/repodata/` in the path, causing 403 errors during package installation.

**Before (❌ Broken):**
```bash
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repomd.xml.key
```

**After (✅ Fixed):**
```bash
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
```

**Impact:** This was causing the error:
```
Status code: 403 for https://prod-cdn.packages.k8s.io/repositories/isv:/kubernetes:/core:/stable:/v1.31/rpm/repomd.xml.key
```

---

### **Error 2: kubectl Installed on Worker Node**

**Location:** `k8s_worker.sh` (Line 76)  
**Issue:** kubectl was being installed on worker nodes, but it's only needed on master nodes.

**Before (❌ Unnecessary):**
```bash
# --- 8. Install Kubeadm / Kubelet / Kubectl ---
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
```

**After (✅ Optimized):**
```bash
# --- 8. Install Kubeadm / Kubelet (kubectl not needed on worker) ---
dnf install -y kubelet kubeadm --disableexcludes=kubernetes
```

**Impact:** Reduces package installation size and follows Kubernetes best practices.

---

## 📋 Summary of Both Scripts

### **k8s_worker.sh** (Terraform user_data script)
- ✅ Configures hostname
- ✅ Installs dependencies (wget, iproute-tc, conntrack)
- ✅ Configures kernel modules and sysctl
- ✅ Disables swap
- ✅ Sets SELinux to permissive
- ✅ Installs and configures containerd
- ✅ Adds Kubernetes repository (with correct GPG key)
- ✅ Installs kubeadm and kubelet only
- ✅ Cleans old state
- ℹ️ **Does NOT join cluster** - requires manual join command

### **k8s-worker-full-setup.sh** (Interactive setup script)
- ✅ All features from k8s_worker.sh
- ✅ **PLUS**: Automatically retrieves join command from master
- ✅ **PLUS**: Joins the cluster automatically
- ✅ **PLUS**: Verifies setup after joining
- ✅ **PLUS**: Colored output and progress indicators
- ✅ **PLUS**: Interactive prompts for user confirmation

---

## 🚀 Usage

### **Option A: Terraform Deployment (Automated)**
The `k8s_worker.sh` script runs automatically during EC2 instance creation via Terraform's `user_data`.

After instance is created, manually run the join command:
```bash
ssh ec2-user@<worker-ip>
sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

### **Option B: Manual Setup (Interactive)**
Use the full setup script for manual worker configuration:
```bash
# Copy script to worker
scp k8s-worker-full-setup.sh ec2-user@<worker-ip>:~/

# SSH to worker and run
ssh ec2-user@<worker-ip>
sudo bash ~/k8s-worker-full-setup.sh

# Or with parameters (non-interactive)
sudo bash ~/k8s-worker-full-setup.sh <master-ip> <token> <ca-hash>
```

---

## ✅ Verification

After running either script and joining the cluster, verify from the master:

```bash
# On K8s Master
kubectl get nodes

# Should show:
# NAME                  STATUS   ROLES           AGE   VERSION
# K8s-Master-Server     Ready    control-plane   ...   v1.31.x
# K8s-Worker-Server     Ready    <none>          ...   v1.31.x
```

---

## 🔧 Troubleshooting

If you still encounter GPG key errors:
```bash
# Clean DNF cache
sudo dnf clean all

# Verify repository file
cat /etc/yum.repos.d/kubernetes.repo

# Try installation again
sudo dnf install -y kubelet kubeadm --disableexcludes=kubernetes
```

If kubelet fails to start:
```bash
# Check logs
sudo journalctl -u kubelet -f

# Common issues:
# - Swap not disabled: sudo swapoff -a
# - Containerd not running: sudo systemctl start containerd
# - Missing CNI: Wait for cluster join to complete
```

---

## 📝 Notes

- Both scripts now use the **correct GPG key URL**
- Both scripts install **only kubeadm and kubelet** (no kubectl)
- Worker nodes don't need kubectl - it's only for cluster administration
- The scripts are compatible with **Kubernetes v1.31**
- Both scripts use **containerd** as the container runtime
- SELinux is set to **permissive** mode for Kubernetes compatibility
