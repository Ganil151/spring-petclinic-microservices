# Docker Command Reference & Diagnostics

## 🚀 Quick Command Reference

### **Essential Docker Commands**

```bash
# Check Docker version
docker --version
docker version

# Check Docker info
docker info

# Check Docker Compose version
docker-compose --version

# View Docker system-wide information
docker system df

# Check Docker daemon status
sudo systemctl status docker

# Start Docker daemon
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker
```

---

## 📋 **Container Management**

### **Basic Container Operations**

```bash
# List running containers
docker ps

# List all containers (including stopped)
docker ps -a

# List containers with custom format
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"

# Start container
docker start <container_name>

# Stop container
docker stop <container_name>

# Restart container
docker restart <container_name>

# Remove container
docker rm <container_name>

# Force remove running container
docker rm -f <container_name>

# Remove all stopped containers
docker container prune

# View container logs
docker logs <container_name>

# Follow container logs (live)
docker logs -f <container_name>

# View last 100 lines of logs
docker logs --tail 100 <container_name>

# View logs with timestamps
docker logs -t <container_name>

# Execute command in running container
docker exec -it <container_name> /bin/bash

# Execute command as root
docker exec -it -u root <container_name> /bin/bash

# Inspect container
docker inspect <container_name>

# View container stats (live)
docker stats

# View stats for specific container
docker stats <container_name>

# Copy file from container
docker cp <container_name>:/path/to/file /local/path

# Copy file to container
docker cp /local/path <container_name>:/path/to/file
```

---

## 🖼️ **Image Management**

### **Image Operations**

```bash
# List images
docker images

# List all images (including intermediate)
docker images -a

# Pull image from registry
docker pull <image_name>:<tag>

# Build image from Dockerfile
docker build -t <image_name>:<tag> .

# Build with no cache
docker build --no-cache -t <image_name>:<tag> .

# Build with build args
docker build --build-arg VERSION=1.0 -t <image_name>:<tag> .

# Tag image
docker tag <source_image> <target_image>:<tag>

# Push image to registry
docker push <image_name>:<tag>

# Remove image
docker rmi <image_name>:<tag>

# Force remove image
docker rmi -f <image_name>:<tag>

# Remove all unused images
docker image prune

# Remove all images
docker image prune -a

# Inspect image
docker inspect <image_name>:<tag>

# View image history
docker history <image_name>:<tag>

# Save image to tar file
docker save -o image.tar <image_name>:<tag>

# Load image from tar file
docker load -i image.tar

# Export container to tar
docker export <container_name> > container.tar

# Import container from tar
docker import container.tar <image_name>:<tag>
```

---

## 🔗 **Network Management**

### **Network Operations**

```bash
# List networks
docker network ls

# Create network
docker network create <network_name>

# Create network with subnet
docker network create --subnet=172.18.0.0/16 <network_name>

# Inspect network
docker network inspect <network_name>

# Connect container to network
docker network connect <network_name> <container_name>

# Disconnect container from network
docker network disconnect <network_name> <container_name>

# Remove network
docker network rm <network_name>

# Remove all unused networks
docker network prune

# View network driver
docker network inspect <network_name> | grep Driver
```

---

## 💾 **Volume Management**

### **Volume Operations**

```bash
# List volumes
docker volume ls

# Create volume
docker volume create <volume_name>

# Inspect volume
docker volume inspect <volume_name>

# Remove volume
docker volume rm <volume_name>

# Remove all unused volumes
docker volume prune

# Remove all volumes (DANGEROUS!)
docker volume prune -a

# View volume location
docker volume inspect <volume_name> | grep Mountpoint
```

---

## 🐳 **Docker Compose Commands**

### **Compose Operations**

```bash
# Start services
docker-compose up

# Start in detached mode
docker-compose up -d

# Start specific service
docker-compose up -d <service_name>

# Build and start
docker-compose up --build

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Stop and remove images
docker-compose down --rmi all

# View running services
docker-compose ps

# View logs
docker-compose logs

# Follow logs
docker-compose logs -f

# View logs for specific service
docker-compose logs -f <service_name>

# Restart services
docker-compose restart

# Restart specific service
docker-compose restart <service_name>

# Execute command in service
docker-compose exec <service_name> /bin/bash

# Run one-off command
docker-compose run <service_name> <command>

# Scale service
docker-compose up -d --scale <service_name>=3

# Validate compose file
docker-compose config

# View service configuration
docker-compose config --services

# Pull images
docker-compose pull

# Build images
docker-compose build

# Build without cache
docker-compose build --no-cache

# View service ports
docker-compose port <service_name> <port>
```

---

## 🔍 **Diagnostic Commands**

### **System Diagnostics**

```bash
# Check Docker daemon status
sudo systemctl status docker

# View Docker daemon logs
sudo journalctl -u docker -f

# Check Docker disk usage
docker system df

# Detailed disk usage
docker system df -v

# Check Docker events (live)
docker events

# Check Docker events for specific container
docker events --filter container=<container_name>

# View Docker daemon configuration
docker info

# Check Docker version and build info
docker version

# Test Docker installation
docker run hello-world
```

### **Container Diagnostics**

```bash
# Check container health
docker inspect --format='{{.State.Health.Status}}' <container_name>

# View container processes
docker top <container_name>

# View container resource usage
docker stats <container_name> --no-stream

# Check container exit code
docker inspect --format='{{.State.ExitCode}}' <container_name>

# View container environment variables
docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' <container_name>

# Check container port mappings
docker port <container_name>

# View container IP address
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container_name>

# Check container restart count
docker inspect --format='{{.RestartCount}}' <container_name>

# View container mounts
docker inspect --format='{{json .Mounts}}' <container_name> | jq
```

### **Network Diagnostics**

```bash
# Test connectivity between containers
docker exec <container1> ping <container2>

# Check DNS resolution
docker exec <container_name> nslookup <hostname>

# View container network settings
docker inspect --format='{{json .NetworkSettings}}' <container_name> | jq

# Check if port is listening
docker exec <container_name> netstat -tuln

# Test HTTP endpoint
docker exec <container_name> curl http://localhost:8080/health

# View network gateway
docker network inspect <network_name> | grep Gateway
```

---

## 🛠️ **Troubleshooting Commands**

### **Common Issues**

#### **1. Container Won't Start**

```bash
# Check container logs
docker logs <container_name>

# Check last 50 lines
docker logs --tail 50 <container_name>

# Inspect container state
docker inspect <container_name> | grep -A 10 State

# Check exit code
docker inspect --format='{{.State.ExitCode}}' <container_name>

# Try starting with different command
docker run -it <image_name> /bin/bash
```

#### **2. Container Keeps Restarting**

```bash
# Check restart policy
docker inspect --format='{{.HostConfig.RestartPolicy}}' <container_name>

# View restart count
docker inspect --format='{{.RestartCount}}' <container_name>

# Check logs for errors
docker logs --tail 100 <container_name>

# Update restart policy
docker update --restart=no <container_name>
```

#### **3. Out of Disk Space**

```bash
# Check disk usage
docker system df

# Remove unused containers
docker container prune

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Clean everything (CAREFUL!)
docker system prune -a --volumes
```

#### **4. Network Issues**

```bash
# Restart Docker daemon
sudo systemctl restart docker

# Recreate network
docker network rm <network_name>
docker network create <network_name>

# Check iptables rules
sudo iptables -L -n

# Flush Docker iptables
sudo iptables -t nat -F
sudo iptables -t filter -F
sudo systemctl restart docker
```

#### **5. Permission Issues**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes
newgrp docker

# Fix socket permissions
sudo chmod 666 /var/run/docker.sock

# Restart Docker daemon
sudo systemctl restart docker
```

---

## 📊 **Monitoring Commands**

### **Resource Monitoring**

```bash
# View all container stats
docker stats

# View stats without streaming
docker stats --no-stream

# View stats with custom format
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Monitor specific containers
docker stats <container1> <container2>

# View container processes
docker top <container_name>

# Check container health
docker inspect --format='{{.State.Health}}' <container_name>
```

### **Log Monitoring**

```bash
# Follow logs from all compose services
docker-compose logs -f

# Follow logs with timestamps
docker-compose logs -f -t

# View logs since specific time
docker logs --since 1h <container_name>

# View logs until specific time
docker logs --until 2023-01-01T00:00:00 <container_name>

# Filter logs by pattern
docker logs <container_name> | grep ERROR

# Export logs to file
docker logs <container_name> > container.log
```

---

## 🧹 **Cleanup Commands**

### **System Cleanup**

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune

# Remove all unused resources
docker system prune

# Remove everything including volumes
docker system prune -a --volumes

# Remove all stopped containers
docker rm $(docker ps -a -q)

# Remove all images
docker rmi $(docker images -q)

# Remove all volumes
docker volume rm $(docker volume ls -q)

# Force remove all containers
docker rm -f $(docker ps -a -q)
```

---

## 🔐 **Registry & Authentication**

### **Docker Registry Commands**

```bash
# Login to Docker Hub
docker login

# Login to private registry
docker login <registry_url>

# Logout
docker logout

# Tag image for registry
docker tag <image> <registry>/<repository>:<tag>

# Push to registry
docker push <registry>/<repository>:<tag>

# Pull from registry
docker pull <registry>/<repository>:<tag>

# Search Docker Hub
docker search <term>
```

---

## 🏗️ **Build Optimization**

### **Build Commands**

```bash
# Build with BuildKit
DOCKER_BUILDKIT=1 docker build -t <image> .

# Build with progress output
docker build --progress=plain -t <image> .

# Build with target stage
docker build --target <stage_name> -t <image> .

# Build with multiple tags
docker build -t <image>:latest -t <image>:v1.0 .

# Build with secrets
docker build --secret id=mysecret,src=secret.txt -t <image> .

# View build cache
docker builder prune

# Clear build cache
docker builder prune -a
```

---

## 📝 **Docker Compose for Spring Petclinic**

### **Project-Specific Commands**

```bash
# Start all services
docker-compose up -d

# Start specific microservice
docker-compose up -d customers-service

# View all service logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f api-gateway

# Restart all services
docker-compose restart

# Rebuild and restart
docker-compose up -d --build

# Scale service
docker-compose up -d --scale customers-service=3

# Check service health
docker-compose ps

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### **Service-Specific Diagnostics**

```bash
# Check config-server
docker-compose logs -f config-server
curl http://localhost:8888/actuator/health

# Check discovery-server
docker-compose logs -f discovery-server
curl http://localhost:8761/actuator/health

# Check api-gateway
docker-compose logs -f api-gateway
curl http://localhost:8080/actuator/health

# Check database connectivity
docker-compose exec customers-service nc -zv mysql-server 3306

# View service environment
docker-compose exec customers-service env | grep SPRING
```

---

## 🎯 **Performance Tuning**

### **Resource Limits**

```bash
# Run with memory limit
docker run -m 512m <image>

# Run with CPU limit
docker run --cpus=2 <image>

# Run with both limits
docker run -m 512m --cpus=2 <image>

# Update running container limits
docker update --memory 1g <container_name>

# View container resource limits
docker inspect --format='{{.HostConfig.Memory}}' <container_name>
```

---

## 📚 **Quick Reference Table**

| Command | Description |
|---------|-------------|
| `docker ps` | List running containers |
| `docker ps -a` | List all containers |
| `docker images` | List images |
| `docker logs <container>` | View logs |
| `docker exec -it <container> bash` | Enter container |
| `docker-compose up -d` | Start services |
| `docker-compose down` | Stop services |
| `docker-compose logs -f` | Follow logs |
| `docker system prune` | Clean unused resources |
| `docker stats` | View resource usage |

---

## 🚨 **Emergency Commands**

```bash
# Stop all containers
docker stop $(docker ps -q)

# Kill all containers
docker kill $(docker ps -q)

# Remove all containers
docker rm -f $(docker ps -a -q)

# Restart Docker daemon
sudo systemctl restart docker

# Reset Docker to factory defaults (NUCLEAR OPTION)
sudo systemctl stop docker
sudo rm -rf /var/lib/docker
sudo systemctl start docker

# Check Docker daemon logs
sudo journalctl -u docker --no-pager | tail -100
```

---

## 💡 **Pro Tips**

1. **Use `.dockerignore`** to exclude files from build context
2. **Multi-stage builds** reduce image size
3. **Use specific tags** instead of `latest`
4. **Enable BuildKit** for faster builds
5. **Use health checks** in Dockerfile
6. **Limit container resources** to prevent resource exhaustion
7. **Use volumes** for persistent data
8. **Use networks** to isolate services
9. **Regular cleanup** prevents disk space issues
10. **Monitor logs** for early problem detection

---

## 📖 **Getting Help**

```bash
# Docker help
docker --help
docker <command> --help

# Docker Compose help
docker-compose --help
docker-compose <command> --help

# View command options
docker run --help
docker build --help
```

---

## ✅ **Health Check Script**

See `docker-health-check.sh` for automated diagnostics.

**Usage**:
```bash
chmod +x docker-health-check.sh
./docker-health-check.sh
```

---

## 🔗 **Related Documentation**

- **Spring Petclinic**: See `docker-compose.yml` for service definitions
- **Prometheus**: See `prometheus/prometheus.yml` for configuration
- **Grafana**: See `grafana/grafana.ini` for settings
- **Webhook**: See `webhook/README.md` for webhook receiver

---

## 📞 **Common Scenarios**

### **Scenario 1: Service Won't Start**
```bash
docker-compose logs -f <service_name>
docker-compose exec <service_name> /bin/bash
# Check configuration and dependencies
```

### **Scenario 2: Out of Memory**
```bash
docker stats
docker update --memory 2g <container_name>
docker-compose restart <service_name>
```

### **Scenario 3: Network Issues**
```bash
docker network inspect bridge
docker-compose down
docker-compose up -d
```

### **Scenario 4: Slow Performance**
```bash
docker stats
docker system df
docker system prune
# Consider resource limits and scaling
```
