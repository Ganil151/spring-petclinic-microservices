#!/bin/bash
# Hybrid Worker Node Bootstrap Script (Bash + Ansible)
# Target OS: Amazon Linux 2023
# Path: terraform/scripts/worker_bootstrap.sh

set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname worker-node
echo "Waiting 60 seconds for instance to stabilize..."
sleep 60

# 2. Disk Management (Mount Extra Volume)
echo "Configuring Extra Storage..."
DISK_DEVICE="/dev/sdb"
MOUNT_POINT="/mnt/data"

if [ -b "$DISK_DEVICE" ]; then
    # Only format if it doesn't already have a filesystem
    if ! sudo blkid "$DISK_DEVICE" >/dev/null 2>&1; then
        sudo mkfs -t xfs "$DISK_DEVICE"
    fi
    sudo mkdir -p "$MOUNT_POINT"
    # Mount and add to fstab for persistence
    if ! grep -qs "$MOUNT_POINT" /proc/mounts; then
        sudo mount "$DISK_DEVICE" "$MOUNT_POINT"
        echo "$DISK_DEVICE $MOUNT_POINT xfs defaults,nofail 0 2" | sudo tee -a /etc/fstab
    fi
    sudo chown -R ec2-user:ec2-user "$MOUNT_POINT"
fi

# 3. Install Baseline Dependencies
echo "Installing Python and Ansible dependencies..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip git jq unzip

# 4. Install Ansible
echo "Installing Ansible via Pip..."
sudo pip3 install ansible

# 5. Create local Ansible structure
echo "Creating local Ansible configuration..."
mkdir -p /tmp/ansible-setup/roles/worker/tasks

# --- Create Worker Role Tasks ---
cat <<'EOF' > /tmp/ansible-setup/roles/worker/tasks/main.yml
---
- name: Install Development Tools
  dnf:
    name:
      - git
      - docker
      - jq
      - unzip
      - fontconfig
      - java-21-amazon-corretto-devel
      - maven
    state: present

- name: Start and enable Docker
  systemd:
    name: docker
    state: started
    enabled: yes

- name: Add ec2-user to docker group
  user:
    name: ec2-user
    groups: docker
    append: yes

- name: Install AWS CLI v2
  shell: |
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -o awscliv2.zip
    ./aws/install --update
    rm -rf aws awscliv2.zip
  args:
    creates: /usr/local/bin/aws

- name: Install Kubectl
  get_url:
    url: "https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl"
    dest: /usr/local/bin/kubectl
    mode: '0755'

- name: Install Helm
  shell: |
    curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  args:
    creates: /usr/local/bin/helm

- name: Configure Docker to use extra volume (Optional but recommended)
  file:
    path: /etc/docker
    state: directory
  
- name: Create daemon.json for Docker
  copy:
    dest: /etc/docker/daemon.json
    content: |
      {
        "data-root": "/mnt/data/docker"
      }
  notify: Restart Docker
EOF

# --- Create Docker Handler ---
mkdir -p /tmp/ansible-setup/roles/worker/handlers
cat <<'EOF' > /tmp/ansible-setup/roles/worker/handlers/main.yml
---
- name: Restart Docker
  systemd:
    name: docker
    state: restarted
EOF

# --- Create Master Playbook ---
cat <<'EOF' > /tmp/ansible-setup/main.yml
---
- name: Setup Worker Node
  hosts: localhost
  connection: local
  become: yes
  roles:
    - worker
EOF

# 6. Run Ansible Playbook
echo "Running Ansible Playbook..."
cd /tmp/ansible-setup
ansible-playbook main.yml

# 7. Final Verification
echo "------------------------------------------------"
echo "✅ Worker Node Hybrid Setup Complete!"
echo "------------------------------------------------"
java -version 2>&1 | head -n 1
docker --version
docker info | grep "Docker Root Dir"
kubectl version --client
helm version --short
echo "Extra Storage: $(df -h | grep /mnt/data)"
echo "------------------------------------------------"