#!/bin/bash

# Define the .env file path
ENV_FILE=".env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found."
    exit 1
fi

# Extract values from .env
# We use grep and cut because the variable names in .env contain dashes, 
# which are not valid for standard shell variable assignment via 'source'.
DOCKER_IP=$(grep "^docker-server-ip=" "$ENV_FILE" | cut -d'=' -f2)
WORKER_IP=$(grep "^worker-server-ip=" "$ENV_FILE" | cut -d'=' -f2)
MYSQL_IP=$(grep "^mysql-server-ip=" "$ENV_FILE" | cut -d'=' -f2)
MONITOR_IP=$(grep "^monitor-server-ip=" "$ENV_FILE" | cut -d'=' -f2)

# Generate hosts.ini
cat > hosts.ini <<EOF
[docker]
docker-server ansible_host=${DOCKER_IP} ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/.ssh/master_keys.pem

[worker]
worker-server ansible_host=${WORKER_IP} ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/.ssh/master_keys.pem

[mysql]
mysql-server ansible_host=${MYSQL_IP} ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/.ssh/master_keys.pem

[monitor]
monitor-server ansible_host=${MONITOR_IP} ansible_user=ec2-user ansible_ssh_private_key_file=/home/ec2-user/.ssh/master_keys.pem

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

echo "hosts.ini has been successfully generated from $ENV_FILE"
