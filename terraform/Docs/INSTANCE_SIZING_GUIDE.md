# EC2 Instance Sizing Guide for Spring Petclinic Microservices

## 📊 Recommended Instance Types by Server

### **Production-Ready Sizing**

| Server | Instance Type | vCPUs | Memory | Storage | Monthly Cost* | Use Case |
|--------|---------------|-------|--------|---------|---------------|----------|
| **K8s Master** | `t3.large` | 2 | 8 GB | 50 GB | ~$60 | Control plane, etcd, scheduler |
| **K8s Worker** | `t3.xlarge` | 4 | 16 GB | 50 GB | ~$120 | Runs all microservices pods |
| **Jenkins Master** | `t3.large` | 2 | 8 GB | 30 GB | ~$60 | Build orchestration |
| **Jenkins Worker** | `t3.xlarge` | 4 | 16 GB | 30 GB | ~$120 | Docker builds, Maven |
| **MySQL Database** | `t3.medium` | 2 | 4 GB | 20 GB | ~$30 | Database server |
| **Monitoring** | `t3.medium` | 2 | 4 GB | 20 GB | ~$30 | Prometheus, Grafana |
| **Webhook Receiver** | `t3.small` | 2 | 2 GB | 20 GB | ~$15 | Lightweight webhook handler |

**Total Monthly Cost**: ~$435/month

*Costs are approximate for us-east-1 region

---

### **Development/Testing Sizing** (Current)

| Server | Instance Type | vCPUs | Memory | Storage | Monthly Cost* | Notes |
|--------|---------------|-------|--------|---------|---------------|-------|
| **K8s Master** | `t2.large` | 2 | 8 GB | 50 GB | ~$67 | ✅ Adequate |
| **K8s Worker** | `t2.large` | 2 | 8 GB | 50 GB | ~$67 | ⚠️ May struggle with all pods |
| **Jenkins Master** | `t2.large` | 2 | 8 GB | 30 GB | ~$67 | ✅ Adequate |
| **Jenkins Worker** | `t2.large` | 2 | 8 GB | 30 GB | ~$67 | ⚠️ Slow builds |
| **MySQL Database** | `t2.small` | 1 | 2 GB | 20 GB | ~$17 | ⚠️ Minimal for dev |
| **Monitoring** | `t2.small` | 1 | 2 GB | 20 GB | ~$17 | ⚠️ May run out of memory |
| **Webhook Receiver** | `t2.large` | 2 | 8 GB | 20 GB | ~$67 | ✅ Oversized for task |

**Total Monthly Cost**: ~$369/month

---

### **Budget-Friendly Sizing**

| Server | Instance Type | vCPUs | Memory | Storage | Monthly Cost* | Trade-offs |
|--------|---------------|-------|--------|---------|---------------|------------|
| **K8s Master** | `t3.medium` | 2 | 4 GB | 50 GB | ~$30 | Slower scheduling |
| **K8s Worker** | `t3.large` | 2 | 8 GB | 50 GB | ~$60 | Limited pod capacity |
| **Jenkins Master** | `t3.medium` | 2 | 4 GB | 30 GB | ~$30 | Fewer concurrent jobs |
| **Jenkins Worker** | `t3.large` | 2 | 8 GB | 30 GB | ~$60 | Slower builds |
| **MySQL Database** | `t3.small` | 2 | 2 GB | 20 GB | ~$15 | Basic performance |
| **Monitoring** | `t3.small` | 2 | 2 GB | 20 GB | ~$15 | Limited metrics retention |
| **Webhook Receiver** | `t3.micro` | 2 | 1 GB | 20 GB | ~$7 | Sufficient for webhooks |

**Total Monthly Cost**: ~$217/month

---

## 🎯 **Detailed Recommendations by Server**

### **1. Kubernetes Master Server**

#### **Recommended**: `t3.large` (2 vCPUs, 8 GB RAM)

**Why**:
- Runs control plane components (API server, scheduler, controller-manager)
- Hosts etcd database (requires consistent performance)
- Handles cluster state management
- Needs headroom for cluster operations

**Minimum**: `t3.medium` (2 vCPUs, 4 GB RAM)
- Works for small clusters (<10 nodes)
- May struggle with large deployments

**Workload Breakdown**:
- `kube-apiserver`: 200-500 MB RAM
- `etcd`: 200-500 MB RAM
- `kube-scheduler`: 50-100 MB RAM
- `kube-controller-manager`: 100-200 MB RAM
- `CoreDNS`: 100-200 MB RAM
- System overhead: 1-2 GB RAM

---

### **2. Kubernetes Worker Server**

#### **Recommended**: `t3.xlarge` (4 vCPUs, 16 GB RAM)

**Why**:
- Runs all Spring Petclinic microservices (11+ pods)
- Each microservice needs 512 MB - 1 GB RAM
- Needs CPU for Java applications
- Requires headroom for pod scheduling

**Minimum**: `t3.large` (2 vCPUs, 8 GB RAM)
- Can run limited number of pods
- May need resource limits on pods

**Spring Petclinic Microservices**:
1. `config-server`: 512 MB
2. `discovery-server`: 512 MB
3. `customers-service`: 768 MB
4. `visits-service`: 768 MB
5. `vets-service`: 768 MB
6. `api-gateway`: 768 MB
7. `admin-server`: 512 MB
8. `genai-service`: 1 GB
9. `prometheus-server`: 1 GB
10. `grafana-server`: 512 MB
11. `tracing-server`: 512 MB

**Total**: ~8-10 GB RAM needed for pods + 2-3 GB for system

---

### **3. Jenkins Master**

#### **Recommended**: `t3.large` (2 vCPUs, 8 GB RAM)

**Why**:
- Orchestrates build pipelines
- Stores build history and artifacts
- Runs Jenkins UI
- Manages plugins and configurations

**Minimum**: `t3.medium` (2 vCPUs, 4 GB RAM)
- Works for small teams
- Fewer concurrent builds

**Resource Usage**:
- Jenkins JVM: 2-4 GB RAM
- Build queue: 500 MB - 1 GB
- Plugins: 500 MB - 1 GB
- System: 1 GB

---

### **4. Jenkins Worker (Build Agent)**

#### **Recommended**: `t3.xlarge` (4 vCPUs, 16 GB RAM)

**Why**:
- Runs Maven builds (memory-intensive)
- Builds Docker images
- Runs tests
- Handles multiple concurrent builds

**Minimum**: `t3.large` (2 vCPUs, 8 GB RAM)
- Single build at a time
- Slower build times

**Build Resource Requirements**:
- Maven build: 2-4 GB RAM
- Docker build: 1-2 GB RAM
- Test execution: 1-2 GB RAM
- System overhead: 1 GB

---

### **5. MySQL Database Server**

#### **Recommended**: `t3.medium` (2 vCPUs, 4 GB RAM)

**Why**:
- Handles 3 databases (customers, visits, vets)
- Supports concurrent connections from microservices
- Needs buffer pool for caching
- Requires CPU for query processing

**Minimum**: `t3.small` (2 vCPUs, 2 GB RAM)
- Works for development
- Limited concurrent connections

**MySQL Configuration**:
- InnoDB buffer pool: 1-2 GB
- Query cache: 256-512 MB
- Connection overhead: 500 MB
- System: 500 MB

---

### **6. Monitoring Server (Prometheus + Grafana)**

#### **Recommended**: `t3.medium` (2 vCPUs, 4 GB RAM)

**Why**:
- Prometheus scrapes 10+ targets
- Stores time-series data
- Grafana renders dashboards
- Needs CPU for queries

**Minimum**: `t3.small` (2 vCPUs, 2 GB RAM)
- Limited metrics retention
- Slower dashboard rendering

**Resource Breakdown**:
- Prometheus: 1-2 GB RAM
- Grafana: 500 MB - 1 GB RAM
- Node Exporter: 50 MB
- System: 500 MB

---

### **7. Webhook Receiver**

#### **Recommended**: `t3.small` (2 vCPUs, 2 GB RAM)

**Why**:
- Lightweight application
- Handles HTTP webhooks
- Minimal resource requirements

**Minimum**: `t3.micro` (2 vCPUs, 1 GB RAM)
- Sufficient for webhook handling
- Cost-effective

---

## 💰 **Cost Comparison**

### **Monthly Costs by Configuration**

| Configuration | Total Cost | Best For |
|---------------|------------|----------|
| **Production** | ~$435/mo | Production workloads, high availability |
| **Development** | ~$369/mo | Current setup, adequate for dev/test |
| **Budget** | ~$217/mo | Learning, POC, minimal workloads |

### **Cost Optimization Tips**

1. **Use t3 instead of t2**: Better performance, similar cost
2. **Enable CPU credits**: t3 unlimited for burst workloads
3. **Use Reserved Instances**: Save 30-40% for 1-year commitment
4. **Use Spot Instances**: Save 70-90% for non-critical workloads
5. **Right-size regularly**: Monitor and adjust based on usage

---

## 🔧 **Instance Type Comparison**

### **t2 vs t3 Instances**

| Feature | t2 | t3 |
|---------|----|----|
| **Baseline Performance** | Lower | Higher |
| **CPU Credits** | Limited | Unlimited option |
| **Network Performance** | Moderate | Up to 5 Gbps |
| **Cost** | Slightly cheaper | Better value |
| **Recommendation** | Legacy | **Preferred** |

### **When to Use Each Type**

- **t3.micro**: Webhooks, lightweight apps
- **t3.small**: MySQL dev, monitoring dev
- **t3.medium**: K8s master (small), MySQL prod
- **t3.large**: K8s master, Jenkins master, K8s worker (small)
- **t3.xlarge**: K8s worker, Jenkins worker
- **t3.2xlarge**: Large K8s worker, high-traffic apps

---

## 📈 **Scaling Recommendations**

### **Horizontal Scaling** (Add more instances)

- **K8s Workers**: Add more workers instead of larger instances
- **Jenkins Workers**: Add build agents for parallel builds
- **MySQL**: Use RDS Multi-AZ for HA

### **Vertical Scaling** (Larger instances)

- **K8s Master**: Upgrade to t3.xlarge for large clusters
- **Monitoring**: Upgrade to t3.large for long retention
- **Jenkins Master**: Upgrade to t3.xlarge for many plugins

---

## 🎯 **Recommended Terraform Configuration**

Update your `terraform.tfvars`:

```hcl
# Production Configuration
instance_type = "t3.large"  # Default for most servers

# Or specify per instance in main.tf:
# K8s Master: t3.large
# K8s Worker: t3.xlarge
# Jenkins Master: t3.large
# Jenkins Worker: t3.xlarge
# MySQL: t3.medium
# Monitoring: t3.medium
# Webhook: t3.small
```

---

## 📊 **Resource Monitoring**

### **Check Current Usage**

```bash
# CPU usage
top

# Memory usage
free -h

# Disk usage
df -h

# Per-process memory
ps aux --sort=-%mem | head -10

# Docker container stats
docker stats
```

### **Kubernetes Resource Usage**

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -A

# Describe node capacity
kubectl describe node <node-name>
```

---

## ✅ **Quick Decision Matrix**

| Your Situation | Recommended Setup |
|----------------|-------------------|
| **Learning/POC** | Budget config (~$217/mo) |
| **Development Team** | Current config (~$369/mo) |
| **Staging Environment** | Production config (~$435/mo) |
| **Production** | Production + HA (~$600+/mo) |
| **High Traffic** | Scale horizontally (add workers) |

---

## 🚀 **Migration Path**

### **From Current (t2.large) to Recommended**

1. **Phase 1**: Upgrade K8s Worker to t3.xlarge
2. **Phase 2**: Upgrade Jenkins Worker to t3.xlarge
3. **Phase 3**: Migrate to t3 family for all instances
4. **Phase 4**: Upgrade MySQL and Monitoring to t3.medium

### **Terraform Changes**

```hcl
# In terraform.tfvars or main.tf
k8s_worker_instance_type    = "t3.xlarge"  # From t2.large
jenkins_worker_instance_type = "t3.xlarge"  # From t2.large
mysql_instance_type         = "t3.medium"  # From t2.small
monitor_instance_type       = "t3.medium"  # From t2.small
```

---

## 💡 **Pro Tips**

1. **Start small, scale up**: Begin with budget config, monitor, then upgrade
2. **Use CloudWatch**: Monitor CPU and memory to right-size
3. **Enable detailed monitoring**: Track resource usage patterns
4. **Set up alerts**: Get notified when resources are constrained
5. **Review monthly**: Adjust instance types based on actual usage
6. **Consider Reserved Instances**: For long-term cost savings
7. **Use Auto Scaling**: For K8s workers to handle variable load

---

## 📞 **Need Help Deciding?**

Ask yourself:

1. **What's your budget?** → Choose configuration tier
2. **How many users?** → Determines worker size
3. **Build frequency?** → Affects Jenkins worker size
4. **Data volume?** → Impacts MySQL and monitoring size
5. **Uptime requirements?** → Production needs HA setup

**General Rule**: Start with development config, monitor for 1-2 weeks, then adjust based on actual usage.
