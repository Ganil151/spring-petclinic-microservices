## Spring Petclinic microservices deployment architecture

### Method 1: Node Selector (Simplest)
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customers-service
spec:
  replicas: 2
  template:
    spec:
      nodeSelector:
        node-role.kubernetes.io/worker: worker
        # Or use custom labels:
        # workload-type: api
      containers:
      - name: customers-service
        image: your-image
```

### Method 2: Node Affinity (More Flexible)
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customers-service
spec:
  replicas: 2
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/worker
                operator: In
                values:
                - worker
              # Or use custom labels:
              # - key: workload-type
              #   operator: In
              #   values:
              #   - api
      containers:
      - name: customers-service
        image: your-image
```

### Method 3: Taints and Tolerations (Most Flexible)
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customers-service
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: customers-service
        image: your-image
      tolerations:
      - key: "node-role.kubernetes.io/worker"
        operator: "Equal"
        value: "worker"
        effect: "NoSchedule"
      # Or use custom labels:
      # - key: "workload-type"
      #   operator: "Equal"
      #   value: "api"
``` 

### Method 4: Node Selector with Taints (Most Flexible)
```bash
apiVersion: apps/v1
kind: Deployment
metadata:
  name: customers-service
spec:
  replicas: 2
  template:
    spec:
      nodeSelector:
        node-role.kubernetes.io/worker: worker
        # Or use custom labels:
        # workload-type: api
      containers:
      - name: customers-service
        image: your-image
      tolerations:
      - key: "node-role.kubernetes.io/worker"
        operator: "Equal"
        value: "worker"
        effect: "NoSchedule"
      # Or use custom labels:
      # - key: "workload-type"
      #   operator: "Equal"
      #   value: "api"
``` 

### Frontend & Backend Services
```bash
# Frontend services on k8s-ap-server
spec:
  template:
    spec:
      nodeSelector:
        workload: frontend

# Backend services on k8s-as-server
spec:
  template:
    spec:
      nodeSelector:
        workload: backend
```

### Distrubution by Node Label
```bash
# Label nodes for different workload types
kubectl label node k8s-ap-server workload=frontend
kubectl label node k8s-as-server workload=backend
```

### 🎨 Frontend/Gateway Layer
api-gateway - Entry point for all external traffic, routes requests to backend services
admin-server - Spring Boot Admin dashboard for monitoring

### 🔧 Backend/Business Services
customers-service - Manages customer and pet data
vets-service - Manages veterinarian information
visits-service - Manages pet visit records
genai-service - AI chatbot service (optional)

### ⚙️ Infrastructure Services
config-server - Centralized configuration management
discovery-server - Eureka service registry (service discovery)

### 📊 Monitoring/Observability
prometheus-server - Metrics collection
tracing-server - Distributed tracing (Zipkin)

### Recommended Node Assignment Strategy
Based on the architecture, here's the optimal distribution:

#### k8s-ap-server (Frontend/Gateway Node):
- ✓ api-gateway
- ✓ admin-server

#### k8s-as-server (Backend Node):
- ✓ customers-service
- ✓ vets-service
- ✓ visits-service
- ✓ genai-service (if using)

#### Any Worker Node (Infrastructure - flexible):
- ✓ config-server
- ✓ discovery-server
- ✓ prometheus-server
- ✓ tracing-server

This distribution ensures:
Frontend traffic hits one node (k8s-ap-server)
Backend processing happens on another (k8s-as-server)
Infrastructure services can run anywhere for flexibility
Load is balanced between your two worker nodes