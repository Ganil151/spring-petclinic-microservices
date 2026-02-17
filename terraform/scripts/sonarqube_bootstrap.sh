#!/bin/bash
# Hybrid SonarQube Server Bootstrap Script (Bash + Ansible)
# Target OS: Amazon Linux 2023
# Path: terraform/scripts/sonarqube_bootstrap.sh

set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname sonarqube-server
echo "Waiting 60 seconds for instance to stabilize..."
sleep 60

# 2. Install Baseline Dependencies
echo "Installing Python and Ansible dependencies..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip git jq unzip

# 3. Install Ansible
echo "Installing Ansible via Pip..."
sudo pip3 install --upgrade pip
sudo pip3 install ansible

# 4. Create local Ansible structure
echo "Creating local Ansible configuration..."
mkdir -p /tmp/ansible-setup/roles/sonarqube/{tasks,defaults}

# --- Create SonarQube Role Tasks ---
cat <<'EOF' > /tmp/ansible-setup/roles/sonarqube/tasks/main.yml
---
- name: Apply Kernel optimizations for Elasticsearch (SonarQube)
  sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    state: present
    reload: yes
  loop:
    - { name: 'vm.max_map_count', value: '524288' }
    - { name: 'fs.file-max', value: '131072' }

- name: Increase ulimits for SonarQube
  copy:
    dest: /etc/security/limits.d/99-sonarqube.conf
    content: |
      sonarqube   soft    nofile   131072
      sonarqube   hard    nofile   131072
      sonarqube   soft    nproc    8192
      sonarqube   hard    nproc    8192

- name: Install Docker and Docker Compose Plugin
  dnf:
    name:
      - docker
      - docker-compose-plugin
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

- name: Create SonarQube directory
  file:
    path: /home/ec2-user/sonarqube
    state: directory
    owner: ec2-user
    group: ec2-user

- name: Generate docker-compose.yml for SonarQube
  copy:
    dest: /home/ec2-user/sonarqube/docker-compose.yml
    owner: ec2-user
    group: ec2-user
    content: |
      version: "3.8"
      services:
        sonarqube:
          image: sonarqube:{{ sonarqube_version }}
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

- name: Start SonarQube containers
  command: docker compose up -d
  args:
    chdir: /home/ec2-user/sonarqube
  become: yes
  become_user: ec2-user

- name: Install Trivy
  yum:
    name: "https://github.com/aquasecurity/trivy/releases/download/v{{ trivy_version }}/trivy_{{ trivy_version }}_Linux-64bit.rpm"
    state: present
    disable_gpg_check: yes

- name: Install Checkov
  pip:
    name: checkov
    state: present
    executable: pip3

- name: Install Java 21 (for scanner support)
  dnf:
    name: java-21-amazon-corretto-devel
    state: present
EOF

# --- Create SonarQube Role Defaults ---
cat <<'EOF' > /tmp/ansible-setup/roles/sonarqube/defaults/main.yml
---
sonarqube_version: "lts-community"
trivy_version: "0.49.1"
EOF

# --- Create Master Playbook ---
cat <<'EOF' > /tmp/ansible-setup/main.yml
---
- name: Setup SonarQube Server
  hosts: localhost
  connection: local
  become: yes
  roles:
    - sonarqube
EOF

# 5. Run Ansible Playbook
echo "Running Ansible Playbook..."
cd /tmp/ansible-setup
ansible-playbook main.yml

# 6. Final Verification
echo "------------------------------------------------"
echo "✅ SonarQube Hybrid Setup Complete!"
echo "------------------------------------------------"
docker ps
trivy --version | head -n 1
checkov --version
echo "------------------------------------------------"
