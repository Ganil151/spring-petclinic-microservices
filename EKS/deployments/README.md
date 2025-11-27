# Kubernetes Deployments for Spring Petclinic Microservices

## 📁 **File Structure**

```
deployments/
├── config-server-deployment.yaml       # Config Server deployment
├── config-server-service.yaml          # Config Server service
├── discovery-server-deployment.yaml    # Eureka Server deployment
├── discovery-server-service.yaml       # Eureka Server service
├── customers-service-deployment.yaml   # Customers microservice
├── customers-service-service.yaml      # Customers service
├── visits-service-deployment.yaml      # Visits microservice
├── visits-service-service.yaml         # Visits service
├── vets-service-deployment.yaml        # Vets microservice
├── vets-service-service.yaml           # Vets service
├── api-gateway-deployment.yaml         # API Gateway deployment
├── api-gateway-service.yaml            # API Gateway service (NodePort)
└── mysql-secret.yaml                   # MySQL credentials secret
```

---

## 🎯 **Services Overview**

| Service | Type | Port | Description |
|---------|------|------|-------------|
| **config-server** | ClusterIP | 8888 | Spring Cloud Config Server |
| **discovery-server** | ClusterIP | 8761 | Eureka Service Discovery |
| **customers-service** | ClusterIP | 8081 | Customer management microservice |
| **visits-service** | ClusterIP | 8082 | Visits management microservice |
| **vets-service** | ClusterIP | 8083 | Veterinarians management microservice |
| **api-gateway** | NodePort | 8080 (30080) | API Gateway (external access) |

---

## 🔑 **Key Features**

### **1. Health Probes**
All services include:
- **Liveness Probe**: Restarts container if unhealthy
- **Readiness Probe**: Removes from service if not ready
- Uses Spring Boot Actuator `/actuator/health` endpoint

### **2. Resource Limits**
- **Config/Discovery**: 256Mi-512Mi RAM, 250m-500m CPU
- **Microservices/Gateway**: 384Mi-768Mi RAM, 250m-500m CPU

### **3. Environment Variables**
- `SPRING_PROFILES_ACTIVE`: Spring profile to use
- `SERVER_PORT`: Service port
- `SPRING_CONFIG_IMPORT`: Config server URL
- `EUREKA_CLIENT_SERVICEURL_DEFAULTZONE`: Eureka server URL
- `SPRING_DATASOURCE_*`: MySQL connection details

### **4. MySQL Integration**
- Connects to external MySQL server (`mysql-server:3306`)
- Uses Kubernetes secret for credentials
- Separate databases: `customers`, `visits`, `vets`

---

## 🚀 **Deployment Order**

The Jenkins pipeline deploys in this order:

1. **MySQL Secret** (credentials)
2. **Config Server** (configuration management)
3. **Discovery Server** (service registry)
4. **Microservices** (customers, visits, vets)
5. **API Gateway** (entry point)

---

## 📋 **Manual Deployment**

### **Prerequisites**
```bash
# Ensure kubectl is configured
kubectl cluster-info

# Check nodes are ready
kubectl get nodes
```

### **Deploy MySQL Secret**
```bash
kubectl apply -f deployments/mysql-secret.yaml
```

### **Deploy Infrastructure**
```bash
# Config Server
kubectl apply -f deployments/config-server-deployment.yaml
kubectl apply -f deployments/config-server-service.yaml
kubectl rollout status deployment/config-server

# Discovery Server
kubectl apply -f deployments/discovery-server-deployment.yaml
kubectl apply -f deployments/discovery-server-service.yaml
kubectl rollout status deployment/discovery-server
```

### **Deploy Microservices**
```bash
# Customers Service
kubectl apply -f deployments/customers-service-deployment.yaml
kubectl apply -f deployments/customers-service-service.yaml

# Visits Service
kubectl apply -f deployments/visits-service-deployment.yaml
kubectl apply -f deployments/visits-service-service.yaml

# Vets Service
kubectl apply -f deployments/vets-service-deployment.yaml
kubectl apply -f deployments/vets-service-service.yaml
```

### **Deploy API Gateway**
```bash
kubectl apply -f deployments/api-gateway-deployment.yaml
kubectl apply -f deployments/api-gateway-service.yaml
kubectl rollout status deployment/api-gateway
```

---

## 🔍 **Verification**

### **Check Deployments**
```bash
kubectl get deployments
```

Expected output:
```
NAME                READY   UP-TO-DATE   AVAILABLE   AGE
config-server       1/1     1            1           5m
discovery-server    1/1     1            1           4m
customers-service   1/1     1            1           3m
visits-service      1/1     1            1           3m
vets-service        1/1     1            1           3m
api-gateway         1/1     1            1           2m
```

### **Check Pods**
```bash
kubectl get pods
```

### **Check Services**
```bash
kubectl get services
```

### **Access API Gateway**
```bash
# Get NodePort URL
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
NODE_PORT=$(kubectl get service api-gateway -o jsonpath='{.spec.ports[0].nodePort}')
echo "API Gateway: http://$NODE_IP:$NODE_PORT"

# Or use port-forward for testing
kubectl port-forward service/api-gateway 8080:8080
# Access at http://localhost:8080
```

---

## 🔧 **Configuration**

### **Update Image Tag**
```bash
# Update all deployments to use specific image tag
export IMAGE_TAG="42"
for deployment in deployments/*-deployment.yaml; do
    sed -i "s|image: ganil151/spring-petclinic-microservice:.*|image: ganil151/spring-petclinic-microservice:${IMAGE_TAG}|g" "$deployment"
done
```

### **Update MySQL Password**
```bash
# Edit the secret
kubectl edit secret mysql-secret

# Or recreate it
kubectl delete secret mysql-secret
kubectl create secret generic mysql-secret \
    --from-literal=password='YourNewPassword' \
    --from-literal=root-password='YourNewRootPassword'
```

### **Scale Services**
```bash
# Scale a service
kubectl scale deployment/customers-service --replicas=3

# Check scaling
kubectl get deployment customers-service
```

---

## 🐛 **Troubleshooting**

### **Pod Not Starting**
```bash
# Check pod status
kubectl get pods

# Describe pod
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### **Service Not Accessible**
```bash
# Check service endpoints
kubectl get endpoints

# Check if pods are ready
kubectl get pods -l app=api-gateway

# Test from within cluster
kubectl run test-pod --rm -it --image=curlimages/curl -- sh
curl http://api-gateway:8080/actuator/health
```

### **Database Connection Issues**
```bash
# Check MySQL secret
kubectl get secret mysql-secret -o yaml

# Check if MySQL server is accessible
kubectl run mysql-test --rm -it --image=mysql:8.0 -- \
    mysql -h mysql-server -u petclinic_user -p

# Check service logs for DB errors
kubectl logs -l app=customers-service
```

### **Config Server Issues**
```bash
# Check config server logs
kubectl logs -l app=config-server

# Test config server
kubectl port-forward service/config-server 8888:8888
curl http://localhost:8888/actuator/health
```

---

## 📊 **Monitoring**

### **Resource Usage**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods

# Describe resource limits
kubectl describe deployment config-server
```

### **Health Checks**
```bash
# Check all pod health
kubectl get pods -o wide

# Test health endpoint
kubectl exec -it <pod-name> -- wget -qO- http://localhost:8080/actuator/health
```

---

## 🗑️ **Cleanup**

### **Delete All Resources**
```bash
# Delete deployments
kubectl delete -f deployments/

# Or delete individually
kubectl delete deployment --all
kubectl delete service --all
kubectl delete secret mysql-secret
```

### **Delete Specific Service**
```bash
kubectl delete deployment customers-service
kubectl delete service customers-service
```

---

## 💡 **Best Practices**

1. **Always deploy in order**: Config → Discovery → Microservices → Gateway
2. **Wait for readiness**: Use `kubectl rollout status` between deployments
3. **Use secrets**: Never hardcode passwords in deployment files
4. **Monitor resources**: Adjust limits based on actual usage
5. **Use namespaces**: Separate environments (dev, staging, prod)
6. **Version images**: Always use specific image tags, not `latest`
7. **Health probes**: Ensure all services have proper health checks
8. **Resource limits**: Set appropriate CPU/memory limits

---

## 🔗 **Related Documentation**

- [EKS_COMMAND_REFERENCE.md](../EKS/EKS_COMMAND_REFERENCE.md) - kubectl commands
- [INFRASTRUCTURE_ARCHITECTURE.md](../kubernetes/INFRASTRUCTURE_ARCHITECTURE.md) - Architecture overview
- [KUBECTL_CONFIG_FIX.md](../kubernetes/KUBECTL_CONFIG_FIX.md) - kubectl configuration
- [k8s-complete-setup.sh](../kubernetes/scripts/k8s-complete-setup.sh) - Cluster setup script

---

## 📝 **Notes**

- **MySQL Server**: Must be accessible at `mysql-server:3306`
- **NodePort**: API Gateway exposed on port 30080
- **Image**: All services use the same image with different environment variables
- **Secrets**: MySQL credentials stored in `mysql-secret`
- **Probes**: Initial delays account for Spring Boot startup time
