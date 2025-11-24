# Docker Quick Reference for Spring Petclinic Microservices

## 🚀 **Most Used Commands**

### **Start/Stop Services**
```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart all services
docker-compose restart

# View running services
docker-compose ps
```

### **View Logs**
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api-gateway

# Last 100 lines
docker-compose logs --tail 100 api-gateway
```

### **Service Management**
```bash
# Restart specific service
docker-compose restart customers-service

# Rebuild and restart
docker-compose up -d --build customers-service

# Scale service
docker-compose up -d --scale customers-service=3
```

---

## 📋 **Spring Petclinic Services**

| Service | Port | Health Check |
|---------|------|--------------|
| **config-server** | 8888 | http://localhost:8888/actuator/health |
| **discovery-server** | 8761 | http://localhost:8761/actuator/health |
| **customers-service** | 8081 | http://localhost:8081/actuator/health |
| **visits-service** | 8082 | http://localhost:8082/actuator/health |
| **vets-service** | 8083 | http://localhost:8083/actuator/health |
| **api-gateway** | 8080 | http://localhost:8080/actuator/health |
| **admin-server** | 9090 | http://localhost:9090/actuator/health |
| **prometheus** | 9091 | http://localhost:9091/-/healthy |
| **grafana** | 3000 | http://localhost:3000/api/health |

---

## 🔍 **Quick Diagnostics**

```bash
# Check all container status
docker ps

# Check resource usage
docker stats

# Check disk usage
docker system df

# View service logs
docker-compose logs -f <service_name>

# Enter container
docker-compose exec <service_name> /bin/bash

# Check container health
docker inspect --format='{{.State.Health.Status}}' <container_name>
```

---

## 🛠️ **Common Tasks**

### **Rebuild After Code Changes**
```bash
docker-compose down
docker-compose build
docker-compose up -d
```

### **Clean Up**
```bash
# Remove stopped containers
docker-compose down

# Remove volumes too
docker-compose down -v

# Clean all unused resources
docker system prune -a
```

### **Debug Service**
```bash
# View logs
docker-compose logs -f <service_name>

# Enter container
docker-compose exec <service_name> /bin/bash

# Check environment
docker-compose exec <service_name> env | grep SPRING
```

---

## 🚨 **Troubleshooting**

### **Service Won't Start**
```bash
docker-compose logs -f <service_name>
docker-compose restart <service_name>
```

### **Out of Memory**
```bash
docker stats
docker system prune
```

### **Network Issues**
```bash
docker-compose down
docker-compose up -d
```

---

## 💡 **Pro Tips**

1. Always use `docker-compose logs -f` to debug issues
2. Run `docker system prune` regularly to free space
3. Use `docker-compose up -d --build` after code changes
4. Check health endpoints before testing
5. Use `docker stats` to monitor resource usage

---

## 📚 **Full Documentation**

See **DOCKER_COMMAND_REFERENCE.md** for complete command list and diagnostics.

Run **docker-health-check.sh** for automated health checks.
