# EKS Quick Reference for Spring Petclinic Microservices

## 🚀 **Most Used Commands**

### **Cluster Management**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Check cluster connection
kubectl cluster-info

# View nodes
kubectl get nodes

# View all resources
kubectl get all -A
```

### **Pod Management**
```bash
# List pods
kubectl get pods

# View pod logs
kubectl logs -f <pod-name>

# Enter pod
kubectl exec -it <pod-name> -- /bin/bash

# Describe pod
kubectl describe pod <pod-name>
```

### **Deployment Management**
```bash
# Apply manifests
kubectl apply -f kubernetes/

# Scale deployment
kubectl scale deployment <name> --replicas=3

# Restart deployment
kubectl rollout restart deployment/<name>

# Check rollout status
kubectl rollout status deployment/<name>
```

---

## 📋 **Spring Petclinic Services**

| Service | Deployment | Health Check |
|---------|------------|--------------|
| **config-server** | `kubectl get deployment config-server` | `/actuator/health` |
| **discovery-server** | `kubectl get deployment discovery-server` | `/actuator/health` |
| **customers-service** | `kubectl get deployment customers-service` | `/actuator/health` |
| **visits-service** | `kubectl get deployment visits-service` | `/actuator/health` |
| **vets-service** | `kubectl get deployment vets-service` | `/actuator/health` |
| **api-gateway** | `kubectl get deployment api-gateway` | `/actuator/health` |

---

## 🔍 **Quick Diagnostics**

```bash
# Check all pods
kubectl get pods -A

# Check pod status
kubectl get pods -o wide

# View events
kubectl get events --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods

# View logs
kubectl logs -f deployment/<service-name>
```

---

## 🛠️ **Common Tasks**

### **Deploy Application**
```bash
# Apply all manifests
kubectl apply -f kubernetes/

# Check deployment status
kubectl get deployments

# Wait for rollout
kubectl rollout status deployment/api-gateway
```

### **Update Service**
```bash
# Update image
kubectl set image deployment/<name> <container>=<new-image>

# Restart deployment
kubectl rollout restart deployment/<name>

# Check rollout
kubectl rollout status deployment/<name>
```

### **Debug Service**
```bash
# View logs
kubectl logs -f deployment/<service-name>

# Enter pod
kubectl exec -it <pod-name> -- /bin/bash

# Check health
kubectl exec -it <pod-name> -- wget -qO- http://localhost:8080/actuator/health
```

### **Get Service URL**
```bash
# Get LoadBalancer URL
kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Or use this
kubectl get svc api-gateway
```

---

## 🚨 **Troubleshooting**

### **Pod Not Starting**
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl get events --field-selector involvedObject.name=<pod-name>
```

### **ImagePullBackOff**
```bash
kubectl describe pod <pod-name> | grep -A 5 Events
kubectl get secrets
```

### **CrashLoopBackOff**
```bash
kubectl logs <pod-name> --previous
kubectl describe pod <pod-name>
```

### **Service Not Accessible**
```bash
kubectl get service <service-name>
kubectl get endpoints <service-name>
kubectl describe service <service-name>
```

---

## 🌐 **AWS EKS Specific**

### **Cluster Operations**
```bash
# List clusters
aws eks list-clusters

# Describe cluster
aws eks describe-cluster --name <cluster-name>

# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

### **Node Group Operations**
```bash
# List node groups
aws eks list-nodegroups --cluster-name <cluster-name>

# Describe node group
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <name>

# Scale node group (using eksctl)
eksctl scale nodegroup --cluster=<cluster-name> --name=<nodegroup-name> --nodes=3
```

---

## 📊 **Monitoring**

```bash
# Node metrics
kubectl top nodes

# Pod metrics
kubectl top pods

# Pod metrics in namespace
kubectl top pods -n <namespace>

# Watch pods
kubectl get pods -w

# View events
kubectl get events --sort-by='.lastTimestamp'
```

---

## 🧹 **Cleanup**

```bash
# Delete deployment
kubectl delete deployment <name>

# Delete service
kubectl delete service <name>

# Delete all resources from file
kubectl delete -f kubernetes/

# Delete namespace (deletes all resources)
kubectl delete namespace <namespace>
```

---

## 💡 **Pro Tips**

1. Use `kubectl get pods -o wide` for more details
2. Use `kubectl logs -f` to follow logs in real-time
3. Use `kubectl describe` to see events and details
4. Use `kubectl top` to monitor resource usage
5. Use `kubectl get events` to see recent cluster events
6. Set up aliases: `alias k=kubectl`
7. Enable auto-completion: `source <(kubectl completion bash)`

---

## 📚 **Full Documentation**

See **EKS_COMMAND_REFERENCE.md** for complete command list.

Run **eks-health-check.sh** for automated health checks.

---

## 🔗 **Useful Links**

- **AWS EKS Docs**: https://docs.aws.amazon.com/eks/
- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **eksctl Docs**: https://eksctl.io/

---

## ⚡ **Quick Start**

```bash
# 1. Configure kubectl
aws eks update-kubeconfig --name <cluster-name> --region <region>

# 2. Verify connection
kubectl get nodes

# 3. Deploy application
kubectl apply -f kubernetes/

# 4. Check status
kubectl get pods
kubectl get svc

# 5. Get application URL
kubectl get service api-gateway

# 6. Run health check
./eks-health-check.sh
```
