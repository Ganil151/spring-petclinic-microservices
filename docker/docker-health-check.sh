#!/bin/bash
# Docker Health Check and Diagnostic Script
# Run this to verify Docker setup and container health

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header "Docker Health Check"
echo ""

# 1. Check Docker installation
print_info "1. Checking Docker installation..."
if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker is installed: $DOCKER_VERSION"
else
    print_error "Docker is NOT installed"
    exit 1
fi
echo ""

# 2. Check Docker daemon
print_info "2. Checking Docker daemon status..."
if sudo systemctl is-active --quiet docker; then
    print_success "Docker daemon is running"
else
    print_error "Docker daemon is NOT running"
    print_info "Start with: sudo systemctl start docker"
    exit 1
fi
echo ""

# 3. Check Docker Compose
print_info "3. Checking Docker Compose installation..."
if command -v docker-compose &>/dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_success "Docker Compose is installed: $COMPOSE_VERSION"
else
    print_warning "Docker Compose is NOT installed"
fi
echo ""

# 4. Check Docker permissions
print_info "4. Checking Docker permissions..."
if docker ps &>/dev/null; then
    print_success "Docker permissions are correct"
else
    print_warning "Docker permissions issue. Run: sudo usermod -aG docker $USER"
fi
echo ""

# 5. Check disk space
print_info "5. Checking Docker disk usage..."
docker system df
echo ""

DISK_USAGE=$(docker system df | grep "Images" | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    print_warning "High disk usage ($DISK_USAGE%). Consider running: docker system prune"
else
    print_success "Disk usage is acceptable ($DISK_USAGE%)"
fi
echo ""

# 6. List running containers
print_info "6. Checking running containers..."
RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}")
if [ -z "$(docker ps -q)" ]; then
    print_warning "No containers are running"
else
    print_success "Running containers:"
    echo "$RUNNING_CONTAINERS"
fi
echo ""

# 7. Check for stopped containers
print_info "7. Checking stopped containers..."
STOPPED_COUNT=$(docker ps -a -f status=exited --format "{{.Names}}" | wc -l)
if [ "$STOPPED_COUNT" -gt 0 ]; then
    print_warning "Found $STOPPED_COUNT stopped containers"
    docker ps -a -f status=exited --format "table {{.Names}}\t{{.Status}}"
else
    print_success "No stopped containers"
fi
echo ""

# 8. Check Docker networks
print_info "8. Checking Docker networks..."
docker network ls
echo ""

# 9. Check Docker volumes
print_info "9. Checking Docker volumes..."
VOLUME_COUNT=$(docker volume ls -q | wc -l)
if [ "$VOLUME_COUNT" -gt 0 ]; then
    print_success "Found $VOLUME_COUNT volumes"
    docker volume ls
else
    print_info "No volumes found"
fi
echo ""

# 10. Check for docker-compose.yml
print_info "10. Checking for docker-compose.yml..."
if [ -f "docker-compose.yml" ]; then
    print_success "docker-compose.yml found"
    
    # Validate compose file
    if docker-compose config &>/dev/null; then
        print_success "docker-compose.yml is valid"
    else
        print_error "docker-compose.yml has errors"
        docker-compose config
    fi
else
    print_warning "docker-compose.yml not found in current directory"
fi
echo ""

# 11. Check container health (if any running)
if [ ! -z "$(docker ps -q)" ]; then
    print_info "11. Checking container health..."
    for container in $(docker ps --format "{{.Names}}"); do
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo "no healthcheck")
        if [ "$HEALTH" = "healthy" ]; then
            print_success "$container: healthy"
        elif [ "$HEALTH" = "no healthcheck" ]; then
            print_info "$container: no healthcheck defined"
        else
            print_warning "$container: $HEALTH"
        fi
    done
    echo ""
fi

# 12. Check resource usage
if [ ! -z "$(docker ps -q)" ]; then
    print_info "12. Checking resource usage..."
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    echo ""
fi

# 13. Check for images
print_info "13. Checking Docker images..."
IMAGE_COUNT=$(docker images -q | wc -l)
if [ "$IMAGE_COUNT" -gt 0 ]; then
    print_success "Found $IMAGE_COUNT images"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
else
    print_warning "No images found"
fi
echo ""

# 14. Check for dangling images
print_info "14. Checking for dangling images..."
DANGLING_COUNT=$(docker images -f "dangling=true" -q | wc -l)
if [ "$DANGLING_COUNT" -gt 0 ]; then
    print_warning "Found $DANGLING_COUNT dangling images. Clean with: docker image prune"
else
    print_success "No dangling images"
fi
echo ""

# 15. Check Docker daemon logs for errors
print_info "15. Checking Docker daemon logs for recent errors..."
ERROR_COUNT=$(sudo journalctl -u docker --since "1 hour ago" | grep -i error | wc -l)
if [ "$ERROR_COUNT" -gt 0 ]; then
    print_warning "Found $ERROR_COUNT errors in last hour"
    print_info "View with: sudo journalctl -u docker -f"
else
    print_success "No recent errors in Docker daemon logs"
fi
echo ""

# 16. Check Spring Petclinic services (if compose file exists)
if [ -f "docker-compose.yml" ]; then
    print_info "16. Checking Spring Petclinic services..."
    
    SERVICES=("config-server" "discovery-server" "customers-service" "visits-service" "vets-service" "api-gateway")
    
    for service in "${SERVICES[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "$service"; then
            STATUS=$(docker inspect --format='{{.State.Status}}' $(docker ps -q -f name=$service) 2>/dev/null)
            if [ "$STATUS" = "running" ]; then
                print_success "$service: running"
            else
                print_warning "$service: $STATUS"
            fi
        else
            print_info "$service: not running"
        fi
    done
    echo ""
fi

# 17. Check connectivity to MySQL (if running)
if docker ps --format "{{.Names}}" | grep -q "mysql"; then
    print_info "17. Checking MySQL connectivity..."
    if docker exec $(docker ps -q -f name=mysql) mysqladmin ping -h localhost &>/dev/null; then
        print_success "MySQL is responding"
    else
        print_warning "MySQL is not responding"
    fi
    echo ""
fi

# 18. Check Prometheus (if running)
if docker ps --format "{{.Names}}" | grep -q "prometheus"; then
    print_info "18. Checking Prometheus..."
    PROM_HEALTH=$(docker exec $(docker ps -q -f name=prometheus) wget -qO- http://localhost:9090/-/healthy 2>/dev/null || echo "unhealthy")
    if [ "$PROM_HEALTH" = "Prometheus is Healthy." ]; then
        print_success "Prometheus is healthy"
    else
        print_warning "Prometheus health check failed"
    fi
    echo ""
fi

# 19. Check Grafana (if running)
if docker ps --format "{{.Names}}" | grep -q "grafana"; then
    print_info "19. Checking Grafana..."
    GRAFANA_HEALTH=$(docker exec $(docker ps -q -f name=grafana) wget -qO- http://localhost:3000/api/health 2>/dev/null | grep -o '"database":"ok"' || echo "unhealthy")
    if [ ! -z "$GRAFANA_HEALTH" ]; then
        print_success "Grafana is healthy"
    else
        print_warning "Grafana health check failed"
    fi
    echo ""
fi

# Summary
print_header "Health Check Complete"
echo ""

# Recommendations
print_info "Recommendations:"
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "  • Run 'docker system prune' to free up disk space"
fi
if [ "$STOPPED_COUNT" -gt 5 ]; then
    echo "  • Run 'docker container prune' to remove stopped containers"
fi
if [ "$DANGLING_COUNT" -gt 0 ]; then
    echo "  • Run 'docker image prune' to remove dangling images"
fi
if [ "$ERROR_COUNT" -gt 10 ]; then
    echo "  • Check Docker daemon logs: sudo journalctl -u docker -f"
fi

echo ""
print_info "For more commands, see: DOCKER_COMMAND_REFERENCE.md"
print_info "To start services: docker-compose up -d"
print_info "To view logs: docker-compose logs -f"
