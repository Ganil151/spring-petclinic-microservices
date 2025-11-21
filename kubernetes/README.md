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

#### ======= Kubernetes Installation Verification =======
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

#### ======= Install Calico Network Plugin =======
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml

# To troubleshoot these issues: 
 kubectl get nodes
NAME                STATUS     ROLES           AGE     VERSION
k8s-master-server   NotReady   control-plane   6h33m   v1.31.14
k8s-worker-server   NotReady   <none>          6h28m   v1.31.14
[ec2-user@K8s-Master-Server ~]$ kubectl get ds -n kube-system
NAME         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
kube-proxy   2         2         2       2            2           kubernetes.io/os=linux   6h33m
[ec2-user@K8s-Master-Server ~]$ kubectl describe pod coredns
Error from server (NotFound): pods "coredns" not found
[ec2-user@K8s-Master-Server ~]$ kubectl get events -n kube-system
LAST SEEN   TYPE      REASON             OBJECT                         MESSAGE
3m50s       Warning   FailedScheduling   pod/coredns-7c65d6cfc9-tfpm8   0/2 nodes are available: 2 node(s) had untolerated taint {node.kubernetes.io/not-ready: }. preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.
3m20s       Warning   FailedScheduling   pod/coredns-7c65d6cfc9-zq7xj   0/2 nodes are available: 2 node(s) had untolerated taint {node.kubernetes.io/not-ready: }. preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.
[ec2-user@K8s-Master-Server ~]$ kubectl get nodes -o wide
NAME                STATUS     ROLES           AGE     VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                    CONTAINER-RUNTIME
k8s-master-server   NotReady   control-plane   6h35m   v1.31.14   10.0.1.163    <none>        Amazon Linux 2023.9.20250929   6.1.153-175.280.amzn2023.x86_64   containerd://2.0.6
k8s-worker-server   NotReady   <none>          6h30m   v1.31.14   10.0.1.28     <none>        Amazon Linux 2023.9.20250929   6.1.153-175.280.amzn2023.x86_64   containerd://2.0.6
```

#### ======= Verify the Kubernetes Cluster Health =======
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```
#### 
```bash
kubectl describe node k8s-worker-server | grep -A 5 Conditions
# Output should show the node is NotReady
Conditions:
  Type                 Status  LastHeartbeatTime                 LastTransitionTime                Reason                       Message
  ----                 ------  -----------------                 ------------------                ------                       -------
  NetworkUnavailable   False   Fri, 21 Nov 2025 03:29:15 +0000   Fri, 21 Nov 2025 03:29:15 +0000   CalicoIsUp                   Calico is running on this node
  MemoryPressure       False   Fri, 21 Nov 2025 04:20:26 +0000   Thu, 20 Nov 2025 20:55:42 +0000   KubeletHasSufficientMemory   kubelet has sufficient memory available
  DiskPressure         False   Fri, 21 Nov 2025 04:20:26 +0000   Fri, 21 Nov 2025 03:34:32 +0000   KubeletHasNoDiskPressure     kubelet has no disk pressure
```

```bash
kubectl get nodes -o wide
# Output should show the API server and etcd    
NAME                STATUS     ROLES           AGE    VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                    CONTAINER-RUNTIME
k8s-master-server   NotReady   control-plane   151m   v1.31.14   10.0.1.163    <none>        Amazon Linux 2023.9.20250929   6.1.153-175.280.amzn2023.x86_64   containerd://2.0.6
k8s-worker-server   NotReady   <none>          147m   v1.31.14   10.0.1.28     <none>        Amazon Linux 2023.9.20250929   6.1.153-175.280.amzn2023.x86_64   containerd://2.0.6
```
### Check control plane components 
- `kube-apiserver`: The frontend to the Kubernetes control plane. It exposes the Kubernetes API.
- `etcd`: Consistent and highly available key-value store used as Kubernetes' backing store for all cluster data.
- `kube-controller-manager`: Runs controller processes. Logically, each controller is a separate process, but to reduce complexity, they are all compiled into a single binary and run in a single process.
- `kube-scheduler`: Watches for newly created Pods with no assigned node, and selects a node for them to run on.
```bash
# This command lists pods in the `kube-system` namespace that have the label `tier=control-plane`. These pods represent the core components of the Kubernetes control plane like `kube-apiserver`, `etcd`, `kube-controller-manager`, and `kube-scheduler`.
kubectl get pods -n kube-system -l tier=control-plane
# Output
NAME                                            READY   STATUS    RESTARTS   AGE
etcd-k8s-master-server                          1/1     Running   0          151m
kube-apiserver-k8s-master-server                1/1     Running   0          151m
kube-controller-manager-k8s-master-server       1/1     Running   0          151m
kube-scheduler-k8s-master-server                1/1     Running   0          151m
```

#### This command lists all pods in the `kube-system` namespace with additional information such as IP address, node, and readiness status.
```bash
kubectl get pods -n kube-system -o wide
# Output
NAME                                            READY   STATUS    RESTARTS   AGE   IP            NODE                NOMINATED NODE   READINESS GATES
etcd-k8s-master-server                          1/1     Running   0          151m  10.0.1.163      k8s-master-server   <none>           <none>
kube-apiserver-k8s-master-server                1/1     Running   0          151m  10.0.1.163      k8s-master-server   <none>           <none>
kube-controller-manager-k8s-master-server       1/1     Running   0          151m  10.0.1.163      k8s-master-server   <none>           <none>
kube-scheduler-k8s-master-server                1/1     Running   0          151m  10.0.1.163      k8s-master-server   <none>           <none>
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
Access the application at: `http://54.162.211.229:30080`

If you are running locally (e.g., Docker Desktop, Minikube with tunnel), it might be available at `http://localhost:30080`.

### 5. Access Monitoring
*   **Prometheus**: `http://54.162.211.229:9090` (ClusterIP, use port-forward if needed: `kubectl port-forward svc/prometheus-server 9090:9090`)
*   **Grafana**: `http://54.162.211.229:3000` (ClusterIP, use port-forward if needed: `kubectl port-forward svc/grafana-server 3000:3000`)
    *   Default login: `admin` / `admin`


### Check API server availability
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```

### Verify etcd health
```bash
kubectl get pods -n kube-system -l component=etcd
```

### Verify kube-dns health
```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
kubectl get svc -n kube-system -l k8s-app=kube-dns
kubectl get endpoints -n kube-system -l k8s-app=kube-dns
kubectl get configmap -n kube-system -l k8s-app=kube-dns
kubectl get deployment -n kube-system -l k8s-app=kube-dns
kubectl get daemonset -n kube-system -l k8s-app=kube-dns
kubectl get statefulset -n kube-system -l k8s-app=kube-dns
kubectl get pod -n kube-system -l k8s-app=kube-dns
# Also test DNS resolution inside a pod:
kubectl run -i --tty --image=busybox --restart=Never dns-test -- nslookup kubernetes
kubectl run -i --tty --image=busybox --restart=Never dns-test -- nslookup kubernetes.default
kubectl run -i --tty --image=busybox --restart=Never dns-test -- nslookup kubernetes.default.svc
kubectl run -i --tty --image=busybox --restart=Never dns-test -- nslookup kubernetes.default.svc.cluster.local
kubectl run -i --tty --image=busybox --restart=Never dns-test -- nslookup kubernetes.default.svc.cluster.local
kubectl run dns-test --image=busybox:1.28 --restart=Never -- sleep 3600
kubectl exec dns-test -- nslookup kubernetes.default
```


### ======== TROUBLESHOOTING ======== 
COMPLETELY RESET AND REBUILD THE MASTER
- Step 1: Full Reset the Master
```bash
sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo systemctl stop containerd

# remove state
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet /var/lib/cni /etc/cni/net.d

# ensure containerd configured properly
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# re-run init
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

- Step 2: Rebuild the Master
```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU
``` 

- Step 3: Rebuild the Worker
```bash
#find the join command from the master
sudo kubeadm token create --print-join-command

#join the worker to the cluster 
sudo kubeadm join <master-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
``` 

- Step 4: Setup kubectl access
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

- Step 5: Verify the cluster
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```

- Step 6: Install Calico
```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/custom-resources.yaml
```

- Step 7: Verify the cluster
```bash
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```

- Step 8: Reset the Worker Node Too
```bash
sudo kubeadm reset
sudo systemctl stop kubelet
sudo systemctl stop docker
sudo rm -rf /var/lib/cni
sudo rm -rf /var/lib/etcd/*
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /var/lib/containers/*
sudo rm -rf /var/lib/etcd/*
# Then use the new join command:
sudo kubeadm token create --print-join-command
```

- Join the worker to the cluster 
```bash
sudo kubeadm join <master-ip>:<master-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
``` 
---

- Check kubelet & containerd systemd status + journal
```bash
sudo systemctl status kubelet containerd --no-pager
sudo journalctl -u kubelet -n 200 --no-pager
sudo journalctl -u containerd -n 200 --no-pager
```

- Confirm static manifest files exist (kubelet reads these)
```bash
ls -l /etc/kubernetes/manifests
sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | sed -n '1,200p'
```

- See runtime containers created by kubelet
```bash
sudo crictl ps -a | sed -n '1,200p'
sudo crictl images | sed -n '1,200p'
# logs for the apiserver pod/container (replace <containerID> from crictl ps -a output)
sudo crictl logs <containerID>
# If crictl not installed, use ctr:
sudo ctr -n k8s.io containers list
sudo ctr -n k8s.io tasks list
# get logs (if available)
sudo ctr -n k8s.io tasks logs <taskID>
```
- Is API server port listening?
```bash
sudo ss -ltnp | grep -E '6443|10250' || true
```

- Check disk, memory and CPU pressure
```bash
df -h /var /var/lib
free -m
top -b -n1 | head -n 20
```

- TL;DR — Run these three checks now (copy/paste)
```bash
# 1. check services
sudo systemctl status kubelet containerd --no-pager

# 2. check whether kube-apiserver container exists and its logs (if using containerd)
sudo crictl ps -a || sudo ctr -n k8s.io containers list

# 3. tail kubelet logs for errors
sudo journalctl -u kubelet -n 200 --no-
```

- Check coredns status
```bash
kubectl -n kube-system get pods
# Output:
NAME                                        READY   STATUS    RESTARTS   AGE
coredns-7c65d6cfc9-tfpm8                    0/1     Pending   0          6h12m
coredns-7c65d6cfc9-zq7xj                    0/1     Pending   0          6h12m
etcd-k8s-master-server                      1/1     Running   3          6h13m
kube-apiserver-k8s-master-server            1/1     Running   3          6h13m
kube-controller-manager-k8s-master-server   1/1     Running   3          6h13m
kube-proxy-ctbnw                            1/1     Running   0          6h8m
kube-proxy-pq4bf                            1/1     Running   0          6h12m
kube-scheduler-k8s-master-server            1/1     Running   3          6h13m
```

