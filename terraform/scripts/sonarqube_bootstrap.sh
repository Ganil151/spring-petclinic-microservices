#!/bin/bash
# SonarQube Server Bootstrap Script for Spring Petclinic Microservices
# Target OS: Amazon Linux 2023
# Path: terraform/scripts/sonarqube_bootstrap.sh

set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname sonarqube-server

# Wait for instance to stabilize and cloud-init to settle
echo "Waiting 65 seconds for instance to stabilize..."
sleep 65

# 2. Kernel Optimizations (CRITICAL for SonarQube/Elasticsearch)
# SonarQube includes an embedded Elasticsearch which requires specific kernel settings
echo "Configuring kernel limits for SonarQube..."
sudo sysctl -w vm.max_map_count=524288
sudo sysctl -w fs.file-max=131072
echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=131072" | sudo tee -a /etc/sysctl.conf

# Increase ulimits
cat <<EOF | sudo tee /etc/security/limits.d/99-sonarqube.conf
sonarqube   soft    nofile   131072
sonarqube   hard    nofile   131072
sonarqube   soft    nproc    8192
sonarqube   hard    nproc    8192
EOF

# 3. Repository & System Updates
echo "Updating system packages..."
sudo dnf update -y
# Install core dependencies: Java (required for scanner), Docker, Git, etc.
sudo dnf install -y git docker python3 python3-pip unzip jq fontconfig java-17-amazon-corretto-devel

# 4. AWS CLI v2 Installation
echo "Installing/Updating AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf aws awscliv2.zip

# 5. Docker & Docker Compose Setup
echo "Configuring Docker..."
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user

# Install Docker Compose Plugin
echo "Installing Docker Compose..."
sudo dnf install -y docker-compose-plugin
# Alternative if dnf package not found (ensure version compatibility)
if ! docker compose version > /dev/null 2>&1; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# 6. Deploy SonarQube & PostgreSQL using Docker Compose
# Using Docker for SonarQube is the most reliable way to handle the DB dependency in a bootstrap script.
echo "Preparing SonarQube deployment directory..."
mkdir -p /home/ec2-user/sonarqube
cat <<EOF > /home/ec2-user/sonarqube/docker-compose.yml
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

# Ensure permissions
chown -R ec2-user:ec2-user /home/ec2-user/sonarqube

# Start SonarQube
echo "Starting SonarQube services..."
cd /home/ec2-user/sonarqube
sudo docker compose up -d

# 7. Install Additional DevOps Tools (Security & Compliance)
echo "Installing additional tools (Trivy, Checkov)..."

# Trivy (Container & FS vulnerability scanner)
rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.49.1/trivy_0.49.1_Linux-64bit.rpm

# Checkov (IaC security scanner)
sudo pip3 install --upgrade pip
sudo pip3 install checkov

# 8. Final Verification
echo "------------------------------------------------"
echo "✅ SonarQube Server Setup Complete!"
echo "------------------------------------------------"
printf "Java Version:    %s\n" "$(java -version 2>&1 | head -n 1)"
printf "Docker Version:  %s\n" "$(docker --version)"
printf "Trivy Version:   %s\n" "$(trivy --version | head -n 1)"
printf "Checkov Version: %s\n" "$(checkov --version)"
echo "------------------------------------------------"
echo "SonarQube is starting up. It may take 2-3 minutes to be accessible at port 9000."
echo "Docker containers status:"
sudo docker ps
echo "------------------------------------------------"
