# Kubernetes Quick Reference Guide

## 📚 Study Materials Created

I've created comprehensive Kubernetes notes in [`KUBERNETES_NOTES.md`](file:///c:/Users/ganil/Documents/spring-petclinic-microservices/kubernetes/KUBERNETES_NOTES.md) covering:

### Core Topics Covered

1. **Architecture** - Master/Worker node structure, control plane components
2. **Control Plane Components** - API Server, etcd, Scheduler, Controller Manager
3. **Node Components** - kubelet, kube-proxy, Container Runtime
4. **Kubernetes Objects** - Pods, Services, Deployments, StatefulSets, DaemonSets, Jobs
5. **Networking** - CNI plugins, Network Policies, DNS
6. **Storage** - Volumes, PersistentVolumes, PersistentVolumeClaims
7. **Configuration** - ConfigMaps, Secrets
8. **Workload Management** - Resource limits, Probes, Autoscaling
9. **Service Discovery** - DNS, Ingress
10. **kubectl Commands** - Common operations and debugging
11. **Best Practices** - Security, HA, monitoring
12. **Troubleshooting** - Common issues and solutions

---

## 🎯 Key Kubernetes Components at a Glance

![Kubernetes Architecture](C:/Users/ganil/.gemini/antigravity/brain/efe02e60-f4a0-4f0a-92fa-00244e737dbd/kubernetes_architecture_1763915576581.png)

### Control Plane (Master Node)
| Component | Port | Purpose |
|-----------|------|---------|
| **kube-apiserver** | 6443 | Frontend API for all cluster operations |
| **etcd** | 2379-2380 | Distributed key-value store (cluster state) |
| **kube-scheduler** | 10259 | Assigns Pods to nodes |
| **kube-controller-manager** | 10257 | Runs controllers (reconciliation loops) |

### Worker Node Components
| Component | Port | Purpose |
|-----------|------|---------|
| **kubelet** | 10250 | Node agent, manages Pods |
| **kube-proxy** | - | Network proxy, manages Service networking |
| **Container Runtime** | - | Runs containers (containerd, CRI-O) |

---

## 🚀 Essential kubectl Commands

### Cluster Info
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

### Working with Pods
```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- /bin/bash
```

### Deployments
```bash
kubectl get deployments
kubectl scale deployment <name> --replicas=3
kubectl rollout status deployment/<name>
kubectl rollout undo deployment/<name>
```

### Services
```bash
kubectl get services
kubectl describe service <service-name>
kubectl get endpoints <service-name>
```

### Debugging
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl top nodes
kubectl top pods
kubectl port-forward pod/<pod-name> 8080:80
```

---

## 📊 Kubernetes Object Hierarchy

![Deployment Hierarchy](C:/Users/ganil/.gemini/antigravity/brain/efe02e60-f4a0-4f0a-92fa-00244e737dbd/kubernetes_deployment_hierarchy_1763915683588.png)

```
Cluster
├── Namespaces
│   ├── Pods (smallest unit)
│   ├── Services (stable networking)
│   ├── Deployments → ReplicaSets → Pods
│   ├── StatefulSets → Pods (stateful apps)
│   ├── DaemonSets → Pods (one per node)
│   ├── ConfigMaps (configuration)
│   ├── Secrets (sensitive data)
│   └── PersistentVolumeClaims
└── PersistentVolumes (cluster-wide)
```

---

## 🔧 Common Troubleshooting Scenarios

### Pod Stuck in Pending
```bash
kubectl describe pod <pod-name>
# Check: Resources, node selector, taints/tolerations
```

### Pod in CrashLoopBackOff
```bash
kubectl logs <pod-name>
kubectl logs <pod-name> --previous
# Check: Application errors, resource limits, probes
```

### Service Not Accessible
```bash
kubectl get endpoints <service-name>
kubectl describe service <service-name>
# Check: Pod labels match service selector
```

### Node NotReady
```bash
kubectl describe node <node-name>
# On the node:
sudo systemctl status kubelet
sudo journalctl -u kubelet -f
```

---

## 🎓 Study Tips

1. **Hands-on Practice**: Set up a local cluster with Minikube or Kind
2. **Start Simple**: Begin with Pods, then Services, then Deployments
3. **Understand the Flow**: API Server → Scheduler → kubelet → Container Runtime
4. **Master kubectl**: Practice common commands daily
5. **Read Logs**: Always check `kubectl describe` and `kubectl logs` when debugging

---

## 📖 Your Kubernetes Journey

### Beginner Level
- [ ] Understand Pods and how containers run
- [ ] Learn about Services and how to expose Pods
- [ ] Practice with Deployments and scaling
- [ ] Master basic kubectl commands

### Intermediate Level
- [ ] Work with ConfigMaps and Secrets
- [ ] Understand StatefulSets for databases
- [ ] Learn about Persistent Volumes
- [ ] Implement health checks (probes)
- [ ] Set resource requests and limits

### Advanced Level
- [ ] Configure Network Policies
- [ ] Set up Ingress controllers
- [ ] Implement RBAC for security
- [ ] Use Horizontal Pod Autoscaler
- [ ] Monitor with Prometheus/Grafana
- [ ] Understand etcd backup/restore

---

## 🔗 Additional Resources

- **Full Notes**: [`KUBERNETES_NOTES.md`](file:///c:/Users/ganil/Documents/spring-petclinic-microservices/kubernetes/KUBERNETES_NOTES.md)
- **Official Docs**: <https://kubernetes.io/docs/>
- **kubectl Cheat Sheet**: <https://kubernetes.io/docs/reference/kubectl/cheatsheet/>
- **Interactive Tutorial**: <https://kubernetes.io/docs/tutorials/>

---

## 💡 Quick Tips

> **Tip 1**: Use `kubectl explain <resource>` to get documentation on any resource type
> ```bash
> kubectl explain pod
> kubectl explain deployment.spec
> ```

> **Tip 2**: Use `-o yaml` or `-o json` to see full resource definitions
> ```bash
> kubectl get pod <pod-name> -o yaml
> ```

> **Tip 3**: Use `--dry-run=client -o yaml` to generate YAML templates
> ```bash
> kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yaml
> ```

> **Tip 4**: Watch resources in real-time with `-w`
> ```bash
> kubectl get pods -w
> ```

---

**Happy Learning! 🚀**
