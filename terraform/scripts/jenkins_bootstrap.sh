#!/bin/bash
# Hybrid Jenkins Master Bootstrap Script (Bash + Ansible)
# Target OS: Amazon Linux 2023
# Path: terraform/scripts/jenkins_bootstrap.sh

set -e

# 1. Identity & Initialization
sudo hostnamectl set-hostname jenkins-master

# 2. Wait for instance to stabilize
echo "Waiting 60 seconds for instance to stabilize..."
sleep 60

# 3. Install Baseline Dependencies
echo "Installing Python and Ansible dependencies..."
sudo dnf update -y
sudo dnf install -y python3 python3-pip git jq unzip

# 3. Install Ansible
echo "Installing Ansible via Pip..."
sudo pip3 install --upgrade pip
sudo pip3 install ansible

# 4. Create local Ansible structure
# Instead of cloning the whole repo, we recreate what we need for a fast boot
echo "Creating local Ansible configuration..."
mkdir -p /tmp/ansible-setup/roles/jenkins/tasks
mkdir -p /tmp/ansible-setup/roles/jenkins/handlers
mkdir -p /tmp/ansible-setup/roles/jenkins/defaults

# --- Create Jenkins Role Tasks ---
cat <<'EOF' > /tmp/ansible-setup/roles/jenkins/tasks/main.yml
---
- name: Add Jenkins repository
  get_url:
    url: https://pkg.jenkins.io/redhat-stable/jenkins.repo
    dest: /etc/yum.repos.d/jenkins.repo

- name: Import Jenkins GPG key
  rpm_key:
    state: present
    key: https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

- name: Install Jenkins
  dnf:
    name: jenkins
    state: present

- name: Start and enable Jenkins
  systemd:
    name: jenkins
    state: started
    enabled: yes

- name: Ensure Jenkins plugin directory exists
  file:
    path: /var/lib/jenkins/plugins
    state: directory
    owner: jenkins
    group: jenkins
    mode: '0755'

- name: Install Jenkins Plugin CLI
  get_url:
    url: "https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/{{ plugin_manager_version }}/jenkins-plugin-manager-{{ plugin_manager_version }}.jar"
    dest: /opt/jenkins-plugin-manager.jar

- name: Install recommended Jenkins plugins
  command: >
    java -jar /opt/jenkins-plugin-manager.jar
    --war /usr/share/java/jenkins.war
    --plugin-download-directory /var/lib/jenkins/plugins
    --plugins {{ jenkins_plugins | join(' ') }}
  become: yes
  become_user: jenkins
  notify: Restart Jenkins
  register: plugin_install
  changed_when: "'Downloaded' in plugin_install.stdout"

- name: Add users to docker group
  user:
    name: "{{ item }}"
    groups: docker
    append: yes
  loop:
    - ec2-user
    - jenkins
EOF

# --- Create Jenkins Role Handlers ---
cat <<'EOF' > /tmp/ansible-setup/roles/jenkins/handlers/main.yml
---
- name: Restart Jenkins
  systemd:
    name: jenkins
    state: restarted
EOF

# --- Create Jenkins Role Defaults ---
cat <<'EOF' > /tmp/ansible-setup/roles/jenkins/defaults/main.yml
---
plugin_manager_version: "2.13.0"
jenkins_plugins:
  - workflow-aggregator
  - git
  - github-branch-source
  - docker-workflow
  - sonar
  - maven-plugin
  - eclipse-temurin-installer
  - credentials-binding
  - dependency-check-jenkins-plugin
  - aws-credentials
  - pipeline-utility-steps
EOF

# --- Create Master Playbook ---
cat <<'EOF' > /tmp/ansible-setup/main.yml
---
- name: Setup Jenkins Master
  hosts: localhost
  connection: local
  become: yes
  tasks:
    - name: Install Java 21
      dnf:
        name: java-21-amazon-corretto-devel
        state: present

    - name: Install Docker
      dnf:
        name: docker
        state: present

    - name: Start Docker
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Install DevOps Tools (AWS CLI)
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

  roles:
    - jenkins
EOF

# 5. Run Ansible Playbook
echo "Running Ansible Playbook..."
cd /tmp/ansible-setup
ansible-playbook main.yml

# 6. Final Verification
echo "------------------------------------------------"
echo "✅ Jenkins Master Hybrid Setup Complete!"
echo "------------------------------------------------"
java -version 2>&1 | head -n 1
docker --version
jenkins --version || echo "Jenkins service is active"
aws --version
kubectl version --client
echo "------------------------------------------------"