# kubectl Configuration Issue - Quick Fix

## 🚨 **Problem**

```
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

This error means kubectl is not configured to connect to your Kubernetes cluster.

---

## ✅ **Quick Fix**

### **Step 1: Check if kubeconfig exists**

```bash
ls -la ~/.kube/config
```

If the file doesn't exist or is empty, you need to configure kubectl.

### **Step 2: Configure kubectl (Choose ONE method)**

#### **Method A: Copy from /etc/kubernetes/admin.conf** (Recommended)

```bash
# Create .kube directory
mkdir -p $HOME/.kube

# Copy admin config
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config

# Fix ownership
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify
kubectl get nodes
```

#### **Method B: Export KUBECONFIG environment variable**

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get nodes
```

To make it permanent, add to `~/.bashrc`:
```bash
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> ~/.bashrc
source ~/.bashrc
```

---

## 🔍 **Verify Configuration**

```bash
# Check kubectl config
kubectl config view

# Check current context
kubectl config current-context

# Test connection
kubectl cluster-info

# Get nodes
kubectl get nodes

# Get pods
kubectl get pods -A
```

---

## 🛠️ **If Cluster Not Initialized**

If `/etc/kubernetes/admin.conf` doesn't exist, the cluster may not be initialized:

```bash
# Check if cluster is initialized
sudo ls -la /etc/kubernetes/

# If not initialized, run kubeadm init
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Then configure kubectl
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

## 📋 **Complete Setup Checklist**

1. ✅ Initialize cluster: `sudo kubeadm init --pod-network-cidr=192.168.0.0/16`
2. ✅ Configure kubectl: `mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config`
3. ✅ Fix permissions: `sudo chown $(id -u):$(id -g) ~/.kube/config`
4. ✅ Install CNI: `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml`
5. ✅ Verify: `kubectl get nodes`

---

## 🚨 **Common Issues**

### **Issue 1: Permission Denied**
```bash
sudo chown $(id -u):$(id -g) $HOME/.kube/config
chmod 600 $HOME/.kube/config
```

### **Issue 2: Config File Empty**
```bash
# Check if admin.conf exists
sudo cat /etc/kubernetes/admin.conf

# If it exists, copy it
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### **Issue 3: Cluster Not Running**
```bash
# Check kubelet status
sudo systemctl status kubelet

# Check if API server is running
sudo crictl ps | grep kube-apiserver

# Check logs
sudo journalctl -u kubelet -f
```

---

## 💡 **Pro Tip**

Add this to your `~/.bashrc` for permanent configuration:

```bash
# Kubernetes configuration
export KUBECONFIG=$HOME/.kube/config

# kubectl alias
alias k=kubectl

# kubectl auto-completion
source <(kubectl completion bash)
complete -F __start_kubectl k
```

Then reload:
```bash
source ~/.bashrc
```
