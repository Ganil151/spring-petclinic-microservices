# Kubernetes Installation Troubleshooting

## 🔍 **Issue**: Kubernetes Components Not Installed

### **Symptoms**
```bash
sudo systemctl status kubelet  # Command not found or service doesn't exist
kubeadm version  # Command not found
kubectl version  # Command not found
```

---

## ✅ **Quick Fix Commands**

Run these commands on your K8s Master server:

### **1. Check Current Status**

```bash
# Fix the typo first (status not stauts)
sudo systemctl status kubelet

# Check if binaries exist
which kubeadm
which kubelet
which kubectl

# Check if packages are installed
rpm -qa | grep -E "kubeadm|kubelet|kubectl"
```

### **2. Check Installation Logs**

```bash
# Check if installation was attempted
sudo grep -i "kubelet\|kubeadm\|kubectl" /var/log/dnf.log | tail -20

# Check for errors in user-data execution
sudo cat /var/log/cloud-init-output.log | grep -A 5 -B 5 "kubernetes"
```

### **3. Manual Installation (If Not Installed)**

```bash
# Clean up any partial installation
sudo dnf remove -y kubelet kubeadm kubectl 2>/dev/null || true

# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Clean cache and install
sudo dnf clean all
sudo dnf makecache
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable kubelet
sudo systemctl enable --now kubelet

# Verify
kubeadm version
kubelet --version
kubectl version --client
```

---

## 🛠️ **Automated Fix Script**

I've created a diagnostic script for you:

**Location**: `kubernetes/diagnose-k8s-install.sh`

**Run it**:
```bash
cd ~/spring-petclinic-microservices/kubernetes
chmod +x diagnose-k8s-install.sh
sudo bash diagnose-k8s-install.sh
```

This script will:
1. ✅ Check if Kubernetes components are installed
2. ✅ Check systemd services
3. ✅ Check repository configuration
4. ✅ Offer to automatically fix the installation

---

## 🔍 **Common Causes**

### **1. User Data Script Failed**

The `k8s_master.sh` script may have failed during EC2 instance launch.

**Check**:
```bash
# View cloud-init logs
sudo cat /var/log/cloud-init-output.log

# Check for errors
sudo grep -i error /var/log/cloud-init-output.log
```

### **2. Repository Not Configured**

**Check**:
```bash
ls -la /etc/yum.repos.d/kubernetes.repo
cat /etc/yum.repos.d/kubernetes.repo
```

### **3. Network Issues During Installation**

**Check**:
```bash
# Test repository connectivity
curl -I https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
```

### **4. DNF Cache Issues**

**Fix**:
```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf repolist
```

---

## 📋 **Complete Reinstallation Steps**

If you need to start fresh:

```bash
# 1. Clean up everything
sudo kubeadm reset -f 2>/dev/null || true
sudo dnf remove -y kubelet kubeadm kubectl kubernetes-cni cri-tools
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd /etc/cni

# 2. Re-run the setup script
cd ~/spring-petclinic-microservices/terraform/app/scripts
sudo bash k8s_master.sh

# 3. Or manually install (see Quick Fix Commands above)
```

---

## ✅ **Verification Checklist**

After installation, verify:

```bash
# 1. Binaries installed
kubeadm version -o short
kubelet --version  
kubectl version --client --short

# 2. Kubelet service exists
sudo systemctl status kubelet

# 3. Repository configured
cat /etc/yum.repos.d/kubernetes.repo

# 4. Containerd running
sudo systemctl status containerd

# 5. Required kernel modules loaded
lsmod | grep br_netfilter
lsmod | grep overlay
```

---

## 🚀 **Next Steps After Installation**

Once Kubernetes components are installed:

```bash
# 1. Initialize cluster
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU

# 2. Configure kubectl
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 3. Install Calico
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# 4. Wait for Calico (2-3 minutes)
kubectl get pods -n calico-system -w

# 5. Verify cluster
kubectl get nodes
kubectl get pods -A
```

---

## 📞 **Quick Diagnostic Commands**

```bash
# One-liner to check everything
echo "=== Kubernetes Components ===" && \
which kubeadm kubelet kubectl && \
echo "=== Versions ===" && \
kubeadm version -o short && \
kubelet --version && \
kubectl version --client --short && \
echo "=== Services ===" && \
sudo systemctl status kubelet --no-pager && \
echo "=== Repository ===" && \
cat /etc/yum.repos.d/kubernetes.repo
```

---

## 💡 **Pro Tip**

The error "Unknown command verb stauts" is just a typo - you typed `stauts` instead of `status`. The real issue is that the Kubernetes components weren't installed during the initial setup.

Use the diagnostic script or manual commands above to fix it!
