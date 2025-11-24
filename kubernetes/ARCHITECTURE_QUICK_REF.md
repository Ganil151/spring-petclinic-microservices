# Spring Petclinic Microservices - Quick Architecture Reference

## 🏗️ System Overview

**Spring Petclinic Microservices** is a distributed application demonstrating microservices architecture patterns using Spring Cloud technologies.

### Core Services (4)

| Service | Port | Domain | Database |
|---------|------|--------|----------|
| **Customers Service** | 8081 | Owners & Pets | MySQL |
| **Vets Service** | 8083 | Veterinarians | MySQL |
| **Visits Service** | 8082 | Pet Visits | MySQL |
| **GenAI Service** | 8084 | AI Chatbot | - |

### Infrastructure Services (2)

| Service | Port | Purpose |
|---------|------|---------|
| **Config Server** | 8888 | Centralized configuration |
| **Discovery Server (Eureka)** | 8761 | Service registry |

### Gateway & Frontend (1)

| Service | Port | Purpose |
|---------|------|---------|
| **API Gateway** | 8080 | Entry point, routing, AngularJS UI |

### Monitoring Stack (4)

| Service | Port | Purpose |
|---------|------|---------|
| **Zipkin** | 9411 | Distributed tracing |
| **Prometheus** | 9091 | Metrics collection |
| **Grafana** | 3000 | Metrics visualization |
| **Admin Server** | 9090 | Spring Boot Admin |

---

## 🔄 Request Flow

```
User Browser
    ↓
API Gateway (:8080)
    ↓
Service Discovery (Eureka :8761)
    ↓
Business Services (:8081, :8082, :8083, :8084)
    ↓
MySQL Databases
```

---

## 🐳 Docker Compose Services

Total: **11 containers**

1. config-server
2. discovery-server
3. customers-service
4. vets-service
5. visits-service
6. genai-service
7. api-gateway
8. tracing-server (Zipkin)
9. admin-server
10. prometheus-server
11. grafana-server

---

## ☸️ Kubernetes Deployment

### Resources Created

- **12 Deployments** (one per service)
- **12 Services** (ClusterIP + 1 NodePort for API Gateway)
- **1 Secret** (GenAI API keys)
- **ConfigMaps** (application configuration)

### Access Points

- **Application**: `http://<node-ip>:30080`
- **Eureka Dashboard**: Port-forward to 8761
- **Grafana**: Port-forward to 3000
- **Prometheus**: Port-forward to 9091

---

## 🔧 Technology Stack

- **Language**: Java 17
- **Framework**: Spring Boot 3.x
- **Service Discovery**: Netflix Eureka
- **API Gateway**: Spring Cloud Gateway
- **Configuration**: Spring Cloud Config
- **Circuit Breaker**: Resilience4j
- **Metrics**: Micrometer + Prometheus
- **Tracing**: OpenTelemetry + Zipkin
- **AI**: Spring AI (OpenAI/Azure OpenAI)
- **Database**: MySQL 8.x / HSQLDB
- **Container**: Docker, containerd
- **Orchestration**: Kubernetes, Docker Compose

---

## 📊 Service Dependencies

```
Config Server (must start first)
    ↓
Discovery Server (Eureka)
    ↓
All other services (register with Eureka)
```

---

## 🚀 Quick Start

### Docker Compose
```bash
# Build images
./mvnw clean install -P buildDocker

# Start all services
docker compose up

# Access application
http://localhost:8080
```

### Kubernetes
```bash
# Apply all deployments
kubectl apply -f kubernetes/deployments/

# Check status
kubectl get pods

# Access application
http://<node-ip>:30080
```

---

## 📈 Monitoring Endpoints

| Dashboard | URL | Credentials |
|-----------|-----|-------------|
| Eureka | http://localhost:8761 | None |
| Grafana | http://localhost:3000 | admin/admin |
| Prometheus | http://localhost:9091 | None |
| Zipkin | http://localhost:9411 | None |
| Admin | http://localhost:9090 | None |

---

## 🤖 GenAI Service Features

**Natural Language Queries**:
- "List all owners"
- "Are there any vets that specialize in surgery?"
- "Add a dog for Betty named Moopsie"
- "Which owners have dogs?"

**Requirements**:
- OpenAI API Key OR Azure OpenAI credentials
- Set via environment variables or Kubernetes Secrets

---

## 📁 Project Structure

```
spring-petclinic-microservices/
├── spring-petclinic-api-gateway/
├── spring-petclinic-config-server/
├── spring-petclinic-discovery-server/
├── spring-petclinic-customers-service/
├── spring-petclinic-vets-service/
├── spring-petclinic-visits-service/
├── spring-petclinic-genai-service/
├── spring-petclinic-admin-server/
├── docker/                    # Dockerfiles
├── kubernetes/                # K8s manifests
│   └── deployments/          # Service deployments
├── terraform/                # Infrastructure as Code
├── ansible/                  # Configuration management
├── docker-compose.yml        # Docker Compose config
└── pom.xml                   # Maven parent POM
```

---

## 🔐 Security Notes

> [!WARNING]
> Default configuration is for development only!

**For Production**:
- Enable HTTPS/TLS
- Implement OAuth2/JWT authentication
- Secure inter-service communication
- Use Kubernetes Secrets properly
- Enable network policies
- Implement rate limiting

---

## 📚 Documentation

- **Full Architecture**: [ARCHITECTURE.md](file:///c:/Users/ganil/Documents/spring-petclinic-microservices/ARCHITECTURE.md)
- **Kubernetes Notes**: [kubernetes/KUBERNETES_NOTES.md](file:///c:/Users/ganil/Documents/spring-petclinic-microservices/kubernetes/KUBERNETES_NOTES.md)
- **Kubernetes Quick Ref**: [kubernetes/K8S_QUICK_REFERENCE.md](file:///c:/Users/ganil/Documents/spring-petclinic-microservices/kubernetes/K8S_QUICK_REFERENCE.md)

---

**Project**: Spring Petclinic Microservices  
**Repository**: https://github.com/spring-petclinic/spring-petclinic-microservices
