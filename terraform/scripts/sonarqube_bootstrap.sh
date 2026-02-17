#!/bin/bash
# Optimized SonarQube Server Bootstrap for AL2023
# Target: Static Analysis & Security Scanning for Spring Petclinic
set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname sonarqube-server
echo "Stabilizing instance for 60 seconds..."
sleep 60

# 2. System Updates & Baseline
sudo dnf update -y
sudo dnf install -y python3-pip git jq unzip wget docker

# 3. Kernel & System Limits (Critical for Elasticsearch)
echo "Applying SonarQube System Optimizations..."
cat <<EOF | sudo tee /etc/sysctl.d/99-sonarqube.conf
vm.max_map_count=524288
fs.file-max=131072
EOF
sudo sysctl --system

# Increase limits for both the user and the docker daemon
cat <<EOF | sudo tee /etc/security/limits.d/99-sonarqube.conf
* soft    nofile   131072
* hard    nofile   131072
* soft    nproc    8192
* hard    nproc    8192
EOF

# 4. Docker Setup
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# 5. SonarQube Deployment Configuration
SONAR_DIR="/home/ec2-user/sonarqube"
mkdir -p "$SONAR_DIR"

# Generate a random password if not provided via environment
DB_PASSWORD=${DB_PASSWORD:-"sonar_$(openssl rand -hex 4)"}

cat <<EOF > "$SONAR_DIR/docker-compose.yml"
services:
  sonarqube:
    image: sonarqube:lts-community
    container_name: sonarqube
    restart: unless-stopped
    stop_grace_period: 2m
    ports:
      - "9000:9000"
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://db:5432/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=$DB_PASSWORD
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:15-alpine
    container_name: sonarqube-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=$DB_PASSWORD
      - POSTGRES_DB=sonar
    volumes:
      - postgresql_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql_data:
EOF

# Fix ownership so ec2-user can manage the compose file
sudo chown -R ec2-user:ec2-user "$SONAR_DIR"

# 6. Start Stack (Using AL2023 Docker Compose Plugin)
cd "$SONAR_DIR"
sudo docker compose up -d
echo "Waiting 30 seconds for containers to start..."
sleep 30

# 7. Security Tooling (DevSecOps)
echo "Installing Security Scanners..."
# Trivy
TRIVY_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | jq -r .tag_name | sed 's/v//')
sudo dnf install -y "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.rpm"

# Checkov (IAAC Scanner)
pip3 install --user checkov

# Java 21 (Required for modern Sonar Scanners)
sudo dnf install -y java-21-amazon-corretto-devel

# 8. Verification
echo "------------------------------------------------"
echo "✅ SonarQube Stack is Deploying!"
echo "------------------------------------------------"
printf "SonarQube Port:  9000\n"
printf "DB Password:     %s\n" "$DB_PASSWORD"
printf "Checkov:        %s\n" "$(/home/ec2-user/.local/bin/checkov --version)"
echo "------------------------------------------------"
echo "Note: It may take 2-3 minutes for SonarQube to fully initialize Elasticsearch."