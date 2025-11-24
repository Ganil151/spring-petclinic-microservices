# EKS & kubectl Command Reference

## 🚀 Quick Command Reference

### **Essential kubectl Commands**

```bash
# Check kubectl version
kubectl version --client

# Check cluster connection
kubectl cluster-info

# View cluster nodes
kubectl get nodes

# View all resources
kubectl get all -A

# Get cluster context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <context-name>
```

---

## 📋 **Pod Management**

### **Basic Pod Operations**

```bash
# List pods in default namespace
kubectl get pods

# List pods in all namespaces
kubectl get pods -A

# List pods in specific namespace
kubectl get pods -n <namespace>

# Get pod details
kubectl describe pod <pod-name>

# View pod logs
kubectl logs <pod-name>

# Follow pod logs (live)
kubectl logs -f <pod-name>

# View logs from previous container instance
kubectl logs <pod-name> --previous

# View logs for specific container in pod
kubectl logs <pod-name> -c <container-name>

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash

# Execute command in specific container
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash

# Copy file from pod
kubectl cp <pod-name>:/path/to/file /local/path

# Copy file to pod
kubectl cp /local/path <pod-name>:/path/to/file

# Delete pod
kubectl delete pod <pod-name>

# Force delete pod
kubectl delete pod <pod-name> --force --grace-period=0

# Get pod YAML
kubectl get pod <pod-name> -o yaml

# Get pod JSON
kubectl get pod <pod-name> -o json

# Watch pods
kubectl get pods -w

# Get pod IP
kubectl get pod <pod-name> -o jsonpath='{.status.podIP}'

# Get pod node
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeName}'
```

---

## 🚀 **Deployment Management**

### **Deployment Operations**

```bash
# List deployments
kubectl get deployments

# Get deployment details
kubectl describe deployment <deployment-name>

# Create deployment
kubectl create deployment <name> --image=<image>

# Scale deployment
kubectl scale deployment <deployment-name> --replicas=3

# Update deployment image
kubectl set image deployment/<deployment-name> <container-name>=<new-image>

# Rollout status
kubectl rollout status deployment/<deployment-name>

# Rollout history
kubectl rollout history deployment/<deployment-name>

# Rollback deployment
kubectl rollout undo deployment/<deployment-name>

# Rollback to specific revision
kubectl rollout undo deployment/<deployment-name> --to-revision=2

# Restart deployment
kubectl rollout restart deployment/<deployment-name>

# Pause rollout
kubectl rollout pause deployment/<deployment-name>

# Resume rollout
kubectl rollout resume deployment/<deployment-name>

# Delete deployment
kubectl delete deployment <deployment-name>

# Edit deployment
kubectl edit deployment <deployment-name>

# Apply deployment from file
kubectl apply -f deployment.yaml

# Delete deployment from file
kubectl delete -f deployment.yaml
```

---

## 🔗 **Service Management**

### **Service Operations**

```bash
# List services
kubectl get services
kubectl get svc

# Get service details
kubectl describe service <service-name>

# Expose deployment as service
kubectl expose deployment <deployment-name> --port=80 --target-port=8080

# Create LoadBalancer service
kubectl expose deployment <deployment-name> --type=LoadBalancer --port=80

# Create NodePort service
kubectl expose deployment <deployment-name> --type=NodePort --port=80

# Get service endpoints
kubectl get endpoints <service-name>

# Delete service
kubectl delete service <service-name>

# Get service URL (for LoadBalancer)
kubectl get service <service-name> -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Port forward to service
kubectl port-forward service/<service-name> 8080:80
```

---

## 🗂️ **Namespace Management**

### **Namespace Operations**

```bash
# List namespaces
kubectl get namespaces
kubectl get ns

# Create namespace
kubectl create namespace <namespace-name>

# Delete namespace
kubectl delete namespace <namespace-name>

# Set default namespace
kubectl config set-context --current --namespace=<namespace-name>

# Get current namespace
kubectl config view --minify --output 'jsonpath={..namespace}'

# View resources in namespace
kubectl get all -n <namespace-name>
```

---

## 📦 **ConfigMap & Secret Management**

### **ConfigMap Operations**

```bash
# List ConfigMaps
kubectl get configmaps
kubectl get cm

# Create ConfigMap from literal
kubectl create configmap <name> --from-literal=key1=value1

# Create ConfigMap from file
kubectl create configmap <name> --from-file=config.properties

# Get ConfigMap details
kubectl describe configmap <name>

# Edit ConfigMap
kubectl edit configmap <name>

# Delete ConfigMap
kubectl delete configmap <name>

# Get ConfigMap YAML
kubectl get configmap <name> -o yaml
```

### **Secret Operations**

```bash
# List secrets
kubectl get secrets

# Create secret from literal
kubectl create secret generic <name> --from-literal=password=mypass

# Create secret from file
kubectl create secret generic <name> --from-file=ssh-key=~/.ssh/id_rsa

# Create Docker registry secret
kubectl create secret docker-registry <name> \
  --docker-server=<server> \
  --docker-username=<username> \
  --docker-password=<password>

# Get secret details
kubectl describe secret <name>

# Decode secret
kubectl get secret <name> -o jsonpath='{.data.password}' | base64 -d

# Delete secret
kubectl delete secret <name>
```

---

## 🔍 **Diagnostic Commands**

### **Cluster Diagnostics**

```bash
# Get cluster info
kubectl cluster-info

# Get cluster info dump
kubectl cluster-info dump

# Get node details
kubectl describe node <node-name>

# Get node resource usage
kubectl top nodes

# Get pod resource usage
kubectl top pods

# Get pod resource usage in namespace
kubectl top pods -n <namespace>

# Get events
kubectl get events

# Get events sorted by time
kubectl get events --sort-by='.lastTimestamp'

# Get events for specific resource
kubectl get events --field-selector involvedObject.name=<pod-name>

# Check API resources
kubectl api-resources

# Check API versions
kubectl api-versions

# Explain resource
kubectl explain pod
kubectl explain pod.spec.containers
```

### **Pod Diagnostics**

```bash
# Get pod status
kubectl get pod <pod-name> -o jsonpath='{.status.phase}'

# Get pod restart count
kubectl get pod <pod-name> -o jsonpath='{.status.containerStatuses[0].restartCount}'

# Get pod conditions
kubectl get pod <pod-name> -o jsonpath='{.status.conditions[*].type}'

# Check pod readiness
kubectl get pod <pod-name> -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'

# Get pod events
kubectl describe pod <pod-name> | grep -A 10 Events

# Check pod resource requests/limits
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].resources}'

# Get pod labels
kubectl get pod <pod-name> --show-labels

# Get pods by label
kubectl get pods -l app=myapp

# Get pod container images
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].image}'
```

---

## 🛠️ **Troubleshooting Commands**

### **Common Issues**

#### **1. Pod Not Starting**

```bash
# Check pod status
kubectl get pod <pod-name>

# Get detailed pod info
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name>

# Check previous container logs
kubectl logs <pod-name> --previous

# Check events
kubectl get events --field-selector involvedObject.name=<pod-name>

# Check node resources
kubectl describe node <node-name>
```

#### **2. ImagePullBackOff**

```bash
# Check pod events
kubectl describe pod <pod-name> | grep -A 5 Events

# Check image pull secrets
kubectl get secrets

# Verify image exists
docker pull <image-name>

# Check node can pull image
kubectl debug node/<node-name> -it --image=busybox
```

#### **3. CrashLoopBackOff**

```bash
# Check logs
kubectl logs <pod-name>

# Check previous logs
kubectl logs <pod-name> --previous

# Check resource limits
kubectl describe pod <pod-name> | grep -A 5 Limits

# Check liveness/readiness probes
kubectl describe pod <pod-name> | grep -A 10 Liveness
```

#### **4. Pending Pods**

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl top nodes

# Check pod resource requests
kubectl describe pod <pod-name> | grep -A 5 Requests

# Check node taints
kubectl describe nodes | grep Taints

# Check pod tolerations
kubectl get pod <pod-name> -o jsonpath='{.spec.tolerations}'
```

#### **5. Service Not Accessible**

```bash
# Check service
kubectl get service <service-name>

# Check endpoints
kubectl get endpoints <service-name>

# Check pod labels match service selector
kubectl get pod <pod-name> --show-labels
kubectl get service <service-name> -o jsonpath='{.spec.selector}'

# Test service from within cluster
kubectl run test --image=busybox -it --rm -- wget -O- http://<service-name>

# Check network policies
kubectl get networkpolicies
```

---

## 🌐 **AWS EKS Specific Commands**

### **eksctl Commands**

```bash
# Create EKS cluster
eksctl create cluster --name <cluster-name> --region <region>

# Create cluster from config file
eksctl create cluster -f eks-cluster-config.yaml

# Delete cluster
eksctl delete cluster --name <cluster-name>

# Get cluster info
eksctl get cluster --name <cluster-name>

# List clusters
eksctl get clusters

# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Create node group
eksctl create nodegroup --cluster=<cluster-name> --name=<nodegroup-name>

# Delete node group
eksctl delete nodegroup --cluster=<cluster-name> --name=<nodegroup-name>

# Scale node group
eksctl scale nodegroup --cluster=<cluster-name> --name=<nodegroup-name> --nodes=3

# List node groups
eksctl get nodegroup --cluster=<cluster-name>

# Enable IAM OIDC provider
eksctl utils associate-iam-oidc-provider --cluster=<cluster-name> --approve

# Create IAM service account
eksctl create iamserviceaccount \
  --name <sa-name> \
  --namespace <namespace> \
  --cluster <cluster-name> \
  --attach-policy-arn <policy-arn> \
  --approve
```

### **AWS CLI for EKS**

```bash
# List EKS clusters
aws eks list-clusters

# Describe cluster
aws eks describe-cluster --name <cluster-name>

# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>

# List node groups
aws eks list-nodegroups --cluster-name <cluster-name>

# Describe node group
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>

# List Fargate profiles
aws eks list-fargate-profiles --cluster-name <cluster-name>

# Describe Fargate profile
aws eks describe-fargate-profile --cluster-name <cluster-name> --fargate-profile-name <profile-name>

# List add-ons
aws eks list-addons --cluster-name <cluster-name>

# Describe add-on
aws eks describe-addon --cluster-name <cluster-name> --addon-name <addon-name>
```

---

## 📊 **Monitoring & Logging**

### **Resource Monitoring**

```bash
# Get node metrics
kubectl top nodes

# Get pod metrics
kubectl top pods

# Get pod metrics in namespace
kubectl top pods -n <namespace>

# Get pod metrics with containers
kubectl top pods --containers

# Watch resource usage
watch kubectl top pods

# Get resource quotas
kubectl get resourcequota

# Get limit ranges
kubectl get limitrange
```

### **Logging**

```bash
# View pod logs
kubectl logs <pod-name>

# Follow logs
kubectl logs -f <pod-name>

# View logs from all containers in pod
kubectl logs <pod-name> --all-containers

# View logs with timestamps
kubectl logs <pod-name> --timestamps

# View logs since time
kubectl logs <pod-name> --since=1h

# View logs tail
kubectl logs <pod-name> --tail=100

# Export logs to file
kubectl logs <pod-name> > pod.log
```

---

## 🔐 **Security & RBAC**

### **RBAC Commands**

```bash
# List roles
kubectl get roles

# List cluster roles
kubectl get clusterroles

# List role bindings
kubectl get rolebindings

# List cluster role bindings
kubectl get clusterrolebindings

# Create service account
kubectl create serviceaccount <sa-name>

# Get service account token
kubectl get secret $(kubectl get sa <sa-name> -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d

# Check permissions
kubectl auth can-i create pods
kubectl auth can-i create pods --as=<user>

# Check permissions for service account
kubectl auth can-i create pods --as=system:serviceaccount:<namespace>:<sa-name>
```

---

## 🧹 **Cleanup Commands**

### **Resource Cleanup**

```bash
# Delete all pods in namespace
kubectl delete pods --all -n <namespace>

# Delete all resources in namespace
kubectl delete all --all -n <namespace>

# Delete namespace (deletes all resources)
kubectl delete namespace <namespace>

# Delete resources by label
kubectl delete pods -l app=myapp

# Delete resources from file
kubectl delete -f deployment.yaml

# Prune resources
kubectl apply -f . --prune -l app=myapp

# Delete completed pods
kubectl delete pods --field-selector=status.phase==Succeeded

# Delete failed pods
kubectl delete pods --field-selector=status.phase==Failed
```

---

## 📝 **YAML Management**

### **YAML Operations**

```bash
# Apply YAML file
kubectl apply -f deployment.yaml

# Apply all YAML files in directory
kubectl apply -f ./manifests/

# Apply with record
kubectl apply -f deployment.yaml --record

# Dry run
kubectl apply -f deployment.yaml --dry-run=client

# Server-side dry run
kubectl apply -f deployment.yaml --dry-run=server

# Diff before apply
kubectl diff -f deployment.yaml

# Get resource as YAML
kubectl get deployment <name> -o yaml

# Export resource to YAML
kubectl get deployment <name> -o yaml > deployment.yaml

# Validate YAML
kubectl apply -f deployment.yaml --dry-run=client --validate=true

# Replace resource
kubectl replace -f deployment.yaml

# Force replace
kubectl replace -f deployment.yaml --force
```

---

## 🎯 **Spring Petclinic on EKS**

### **Deployment Commands**

```bash
# Apply all Kubernetes manifests
kubectl apply -f kubernetes/

# Check deployment status
kubectl get deployments

# Check pod status
kubectl get pods

# Check services
kubectl get services

# Get LoadBalancer URL
kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Scale microservice
kubectl scale deployment customers-service --replicas=3

# Update image
kubectl set image deployment/customers-service customers-service=<new-image>

# View logs for specific service
kubectl logs -f deployment/customers-service

# Restart deployment
kubectl rollout restart deployment/customers-service
```

### **Service Health Checks**

```bash
# Check config-server
kubectl logs -f deployment/config-server
kubectl exec -it <config-server-pod> -- wget -qO- http://localhost:8888/actuator/health

# Check discovery-server
kubectl logs -f deployment/discovery-server
kubectl exec -it <discovery-server-pod> -- wget -qO- http://localhost:8761/actuator/health

# Check api-gateway
kubectl logs -f deployment/api-gateway
kubectl exec -it <api-gateway-pod> -- wget -qO- http://localhost:8080/actuator/health

# Check database connectivity
kubectl exec -it <customers-service-pod> -- nc -zv mysql-service 3306
```

---

## 📚 **Quick Reference Table**

| Command | Description |
|---------|-------------|
| `kubectl get pods` | List pods |
| `kubectl get nodes` | List nodes |
| `kubectl logs <pod>` | View logs |
| `kubectl exec -it <pod> -- bash` | Enter pod |
| `kubectl apply -f file.yaml` | Apply manifest |
| `kubectl delete -f file.yaml` | Delete resources |
| `kubectl get svc` | List services |
| `kubectl top nodes` | Node metrics |
| `kubectl top pods` | Pod metrics |
| `kubectl describe pod <pod>` | Pod details |

---

## 🚨 **Emergency Commands**

```bash
# Force delete stuck pod
kubectl delete pod <pod-name> --force --grace-period=0

# Force delete stuck namespace
kubectl get namespace <namespace> -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/<namespace>/finalize" -f -

# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node
kubectl uncordon <node-name>

# Restart all pods in deployment
kubectl rollout restart deployment --all

# Delete all evicted pods
kubectl get pods | grep Evicted | awk '{print $1}' | xargs kubectl delete pod
```

---

## 💡 **Pro Tips**

1. **Use aliases**: `alias k=kubectl`
2. **Enable auto-completion**: `source <(kubectl completion bash)`
3. **Use `-o wide`** for more details: `kubectl get pods -o wide`
4. **Use `--watch`** to monitor changes: `kubectl get pods --watch`
5. **Use labels** for organization: `kubectl get pods -l app=myapp`
6. **Use namespaces** to isolate environments
7. **Always check events** when troubleshooting
8. **Use `kubectl explain`** for resource documentation
9. **Test with `--dry-run`** before applying
10. **Keep manifests in version control**

---

## 📖 **Getting Help**

```bash
# kubectl help
kubectl --help
kubectl <command> --help

# Explain resource
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers

# View API resources
kubectl api-resources

# View API versions
kubectl api-versions
```

---

## ✅ **Health Check Script**

See `eks-health-check.sh` for automated diagnostics.

**Usage**:
```bash
chmod +x eks-health-check.sh
./eks-health-check.sh
```
