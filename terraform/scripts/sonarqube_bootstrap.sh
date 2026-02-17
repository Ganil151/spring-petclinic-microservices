#!/bin/bash
# Pure Bash SonarQube Server Bootstrap Script for Spring Petclinic Microservices
# Target OS: Amazon Linux 2023
# Path: terraform/scripts/sonarqube_bootstrap.sh

set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname sonarQube-server
echo "Waiting 60 seconds for instance to stabilize..."
sleep 60

# 2. System Updates & Baseline Dependencies
echo "Updating system packages..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip git jq unzip wget

# 3. Kernel Optimizations for Elasticsearch (SonarQube)
echo "Applying Kernel optimizations..."
cat <<EOF | sudo tee /etc/sysctl.d/99-sonarqube.conf
vm.max_map_count=524288
fs.file-max=131072
EOF
sudo sysctl --system

# 4. Increase ulimits for SonarQube
echo "Increasing ulimits..."
cat <<EOF | sudo tee /etc/security/limits.d/99-sonarqube.conf
sonarqube   soft    nofile   131072
sonarqube   hard    nofile   131072
sonarqube   soft    nproc    8192
sonarqube   hard    nproc    8192
EOF

# 5. Install Docker and Docker Compose Plugin
echo "Installing Docker..."
sudo dnf install -y docker docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# 6. SonarQube Deployment (Docker Compose)
echo "Setting up SonarQube directory..."
SONAR_DIR="/home/ec2-user/sonarqube"
mkdir -p "$SONAR_DIR"
cd "$SONAR_DIR"

cat <<EOF > docker-compose.yml
version: "3.8"
services:
  sonarqube:
    image: sonarqube:lts-community
    container_name: sonarqube
    restart: always
    ports:
      - "9000:9000"
    networks:
      - sonarnet
    environment:
      - SONAR_JDBC_URL=jdbc:postgresql://db:5432/sonar
      - SONAR_JDBC_USERNAME=sonar
      - SONAR_JDBC_PASSWORD=sonar
    volumes:
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
    depends_on:
      - db

  db:
    image: postgres:15
    container_name: sonarqube-db
    restart: always
    networks:
      - sonarnet
    environment:
      - POSTGRES_USER=sonar
      - POSTGRES_PASSWORD=sonar
      - POSTGRES_DB=sonar
    volumes:
      - postgresql_data:/var/lib/postgresql/data

networks:
  sonarnet:

volumes:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  postgresql_data:
EOF

echo "Starting SonarQube containers..."
sudo docker compose up -d

# 7. Install DevOps Security Tools
echo "Installing Trivy..."
TRIVY_VERSION="0.49.1"
sudo yum install -y "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.rpm"

echo "Installing Checkov..."
sudo pip3 install checkov

echo "Installing Java 21 (for scanner support)..."
sudo dnf install -y java-21-amazon-corretto-devel

# 8. Final Verification
echo "------------------------------------------------"
echo "✅ SonarQube Pure Bash Setup Complete!"
echo "------------------------------------------------"
sudo docker ps
trivy --version | head -n 1
checkov --version
echo "------------------------------------------------"
