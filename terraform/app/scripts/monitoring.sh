#!/bin/bash

set -e

# Change Host Name
NEW_HOSTNAME="Monitor-Server"
echo "Changing Host Name..${NEW_HOSTNAME}"
sudo hostnamectl set-hostname ${NEW_HOSTNAME}

# Install dependencies and update system
echo "Installing dependencies and updating system...😎"
sudo yum update -y

# Install Java
echo "Installing Java..."
sudo yum install -y java-21-amazon-corretto-devel git wget

# Configure Java
echo "Configure Java"
JAVA_HOME="/usr/lib/jvm/java-21-amazon-corretto"
echo "export JAVA_HOME=$JAVA_HOME" | sudo tee -a ~/.bashrc
echo "export PATH=$PATH:$HOME/bin:$JAVA_HOME" | sudo tee -a ~/.bashrc

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker git

# Update system packages
echo "=== Updating system packages ==="
sudo yum update -y

# Ensure Docker is installed (optional, as it's a prerequisite)
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Define the Docker plugins directory (using the standard user directory)
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
PLUGINS_DIR="$DOCKER_CONFIG/cli-plugins"

# Create the plugins directory if it doesn't exist
echo "=== Creating Docker CLI plugins directory ==="
mkdir -p $PLUGINS_DIR

# Download the Docker Compose binary for Linux (x86_64)
COMPOSE_VERSION="v2.40.1" # You can update this to the latest version if needed
echo "=== Downloading Docker Compose binary ==="
curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" \
     -o "$PLUGINS_DIR/docker-compose"

# Make the binary executable
echo "=== Making Docker Compose binary executable ==="
chmod +x "$PLUGINS_DIR/docker-compose"

# Verify the installation
echo "=== Verifying Docker Compose installation ==="
if docker compose version; then
    echo "=== Docker Compose has been successfully installed! ==="
else
    echo "=== Error: Docker Compose verification failed. ==="
    exit 1
fi

echo '=== Verify Docker & Compose ==='
docker --version || { echo 'Docker not working'; exit 1; }
docker compose version || { echo 'Docker Compose V2 not working or not found in expected location'; exit 1; }

# Add the current user to the docker group
echo "Adding the current user to the docker group..."
sudo usermod -a -G docker ec2-user

# Configure Docker to start on boot
echo "Configuring Docker to start on boot..."
sudo systemctl enable docker
sudo systemctl start docker

# --- NEW SECTION: Install Prometheus ---
echo "=== Installing Prometheus ==="
PROMETHEUS_USER="prometheus"
PROMETHEUS_GROUP="prometheus"
PROMETHEUS_VERSION="2.55.0" # Check for the latest version on Prometheus releases page
PROMETHEUS_URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

# 1. Create Prometheus user and group
sudo useradd --no-create-home --shell /bin/false $PROMETHEUS_USER

# 2. Download and extract Prometheus
cd /tmp
wget $PROMETHEUS_URL
tar -xzf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64

# 3. Create directories and set ownership
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

sudo chown $PROMETHEUS_USER:$PROMETHEUS_GROUP /etc/prometheus
sudo chown $PROMETHEUS_USER:$PROMETHEUS_GROUP /var/lib/prometheus

# 4. Copy binaries and configuration
sudo cp ./prometheus /usr/local/bin/
sudo cp ./promtool /usr/local/bin/
sudo chown $PROMETHEUS_USER:$PROMETHEUS_GROUP /usr/local/bin/prometheus
sudo chown $PROMETHEUS_USER:$PROMETHEUS_GROUP /usr/local/bin/promtool

# 5. Copy default configuration (you will likely need to customize this later)
sudo cp ./prometheus.yml /etc/prometheus/
sudo chown $PROMETHEUS_USER:$PROMETHEUS_GROUP /etc/prometheus/prometheus.yml

# 6. Create systemd service file for Prometheus
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=$PROMETHEUS_USER
Group=$PROMETHEUS_GROUP
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

# 7. Start and enable Prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
echo "Prometheus installed and started. Access it at http://<your-server-ip>:9090"

# --- NEW SECTION: Install Grafana ---
echo "=== Installing Grafana ==="
# Add Grafana YUM repository
sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install Grafana
sudo yum install -y grafana

# Start and enable Grafana
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
echo "Grafana installed and started. Access it at http://<your-server-ip>:3000 (default login: admin/admin)"

# Increase /tmp file size persistently and remount
echo "Increasing /tmp file size to 1.5GB persistently..."
if ! grep -q "/tmp tmpfs" /etc/fstab; then
    echo "tmpfs /tmp tmpfs defaults,size=1500M 0 0" | sudo tee -a /etc/fstab
fi

echo "Remounting /tmp with the new size..."
if sudo mount -o remount /tmp; then
    echo "/tmp remounted successfully."
else
    echo "WARNING: Failed to remount /tmp immediately. A reboot is required for the change to take effect."
    exit 0
fi

echo "Docker, Docker Compose, Prometheus, and Grafana installation and configuration complete."
echo "Please ensure ports 9090 (Prometheus) and 3000 (Grafana) are open in your AWS security group."
echo "For Grafana, log in using the default credentials (admin/admin) and change the password immediately."
