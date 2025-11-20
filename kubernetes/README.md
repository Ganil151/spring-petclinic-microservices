## Kubernetes Prerequisites Installed Successfully 

1. On the Master-Server: Initialize the cluster using 'kubeadm init'."
Example: 
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
```

2. Configure kubectl for the current user on the Master:
```bash
mkdir -p \$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
```

3. On the Worker-Server: Join the cluster using the token from 'kubeadm init'."
Example: 
```bash 
sudo kubeadm join <master-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
```

4. Install a Pod Network Addon (e.g., Flannel, Calico) on the Master."
5. Verify the cluster status using 'kubectl get nodes' on the Master."
6. 

#### Important: Ensure that the following ports are open between Master and Worker nodes:"
- Master: 
`6443 (API Server)`, 
`2379-2380 (etcd)`, 
`10250 (kubelet)`, 
`10259 (kube-scheduler)`, 
`10257 (kube-controller-manager)`
- Worker: 
`10250 (kubelet)`, 
`30000-32767 (NodePort Services)`

#### Kubenetes Installation Verification
```bash
#!/bin/bash
set -e

echo "=== Kubernetes Installation Verification ==="

# 1. Verify containerd installed and running
echo "[1/7] Checking containerd..."
if systemctl is-active --quiet containerd; then
    echo "✔ containerd is running"
else
    echo "✘ containerd NOT running"
    exit 1
fi

# 2. Verify kubelet installed and enabled
echo "[2/7] Checking kubelet installation..."
if command -v kubelet >/dev/null 2>&1; then
    echo "✔ kubelet installed"
else
    echo "✘ kubelet NOT installed"
    exit 1
fi

echo "[3/7] Checking kubelet service..."
if systemctl is-enabled --quiet kubelet; then
    echo "✔ kubelet enabled"
else
    echo "✘ kubelet NOT enabled"
    exit 1
fi

# 4. Check kubeadm
echo "[4/7] Checking kubeadm..."
if command -v kubeadm >/dev/null 2>&1; then
    echo "✔ kubeadm installed"
else
    echo "✘ kubeadm NOT installed"
    exit 1
fi

# 5. Check kubectl
echo "[5/7] Checking kubectl..."
if command -v kubectl >/dev/null 2>&1; then
    echo "✔ kubectl installed"
else
    echo "✘ kubectl NOT installed"
    exit 1
fi

# 6. Validate kubelet is not crashlooping
echo "[6/7] Validating kubelet status..."
if systemctl is-active --quiet kubelet; then
    echo "✔ kubelet active (normal before/after init)"
else
    echo "✘ kubelet is NOT active — check logs"
    journalctl -u kubelet -n 20
    exit 1
fi

# 7. If this is the master: check cluster init status
echo "[7/7] Checking kubectl config..."
if [ -f /etc/kubernetes/admin.conf ]; then
    echo "✔ Master node detected"
    
    export KUBECONFIG=/etc/kubernetes/admin.conf

    if kubectl get nodes >/dev/null 2>&1; then
        echo "✔ Kubernetes API reachable"
        kubectl get nodes -o wide
    else
        echo "✘ API server not reachable — cluster not initialized?"
    fi
else
    echo "✔ Worker node detected (admin.conf missing)"
    echo "Note: Worker will be validated fully after kubeadm join"
fi

echo "=== Kubernetes verification complete ==="
```

#### Veriy the Kubenetes are health
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```

## Deploying Spring Petclinic Microservices

### 1. Create Secrets
The `genai-service` requires API keys. Edit `kubernetes/deployments/secrets.yaml` and set your keys, or apply the default placeholders (which will cause the service to fail if it tries to use them).

```bash
kubectl apply -f kubernetes/deployments/secrets.yaml
```

### 2. Apply Deployments
Apply all deployments and services:

```bash
kubectl apply -f kubernetes/deployments/
```

### 3. Verify Deployment
Check the status of the pods:

```bash
kubectl get pods
```

Wait until all pods are in `Running` state.

### 4. Access the Application
The API Gateway is exposed via NodePort 30080.
Access the application at: `http://<node-ip>:30080`

If you are running locally (e.g., Docker Desktop, Minikube with tunnel), it might be available at `http://localhost:30080`.

### 5. Access Monitoring
*   **Prometheus**: `http://<node-ip>:9090` (ClusterIP, use port-forward if needed: `kubectl port-forward svc/prometheus-server 9090:9090`)
*   **Grafana**: `http://<node-ip>:3000` (ClusterIP, use port-forward if needed: `kubectl port-forward svc/grafana-server 3000:3000`)
    *   Default login: `admin` / `admin`

