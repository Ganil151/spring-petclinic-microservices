# Spring PetClinic Microservices - Ansible Automation

## Overview
Ansible playbooks for installing and configuring tools required for Spring PetClinic Microservices.

## Prerequisites
- Ansible >= 2.14
- SSH access to target servers
- sudo privileges

## Installation

### Install Ansible
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install ansible -y

# RHEL/Amazon Linux
sudo yum install ansible -y

# macOS
brew install ansible
```

## Quick Start

### 1. Configure Inventory
Edit `inventory/hosts` with your server details:
```ini
[dev_servers]
dev-server-1 ansible_host=10.0.1.10 ansible_user=ec2-user
```

### 2. Install All Tools
```bash
cd ansible
ansible-playbook playbooks/install-tools.yml
```

### 3. Install Specific Tool
```bash
# Java only
ansible-playbook playbooks/install-java.yml

# Docker only
ansible-playbook -i inventory/hosts playbooks/install-tools.yml --tags docker
```

## Playbooks

### install-tools.yml
Installs all development tools:
- Java 21 (Amazon Corretto)
- Maven 3.9.6
- Docker
- kubectl 1.29
- AWS CLI v2

### install-java.yml
Installs only Java 21.

## Roles

### java
- Installs Amazon Corretto 21
- Sets JAVA_HOME
- Supports RedHat/Debian families

### maven
- Downloads and installs Maven
- Creates symlinks
- Sets environment variables

### docker
- Installs Docker CE
- Adds users to docker group
- Enables Docker service

### kubectl
- Downloads kubectl binary
- Installs to /usr/local/bin

### awscli
- Installs AWS CLI v2
- Supports both package managers

## Usage Examples

### Local Installation
```bash
ansible-playbook -i inventory/hosts playbooks/install-tools.yml --limit local
```

### Remote Servers
```bash
ansible-playbook -i inventory/hosts playbooks/install-tools.yml --limit dev_servers
```

### Check Mode (Dry Run)
```bash
ansible-playbook playbooks/install-tools.yml --check
```

### Specific Tags
```bash
# Install only Java and Maven
ansible-playbook playbooks/install-tools.yml --tags "java,maven"
```

## Customization

### Override Variables
Create `group_vars/all.yml`:
```yaml
java_version: "21"
maven_version: "3.9.6"
kubectl_version: "1.29.0"
```

### Per-Environment Variables
Create `group_vars/dev_servers.yml`:
```yaml
docker_users:
  - developer
  - jenkins
```

## Verification

After installation, verify:
```bash
ansible all -i inventory/hosts -m shell -a "java -version"
ansible all -i inventory/hosts -m shell -a "mvn -version"
ansible all -i inventory/hosts -m shell -a "docker --version"
ansible all -i inventory/hosts -m shell -a "kubectl version --client"
ansible all -i inventory/hosts -m shell -a "aws --version"
```

## Troubleshooting

### Connection Issues
```bash
ansible all -i inventory/hosts -m ping
```

### Verbose Output
```bash
ansible-playbook playbooks/install-tools.yml -vvv
```

### Skip Specific Hosts
```bash
ansible-playbook playbooks/install-tools.yml --limit '!prod_servers'
```

## Best Practices
- Always run in check mode first
- Use inventory groups for different environments
- Store sensitive data in Ansible Vault
- Tag tasks for selective execution
- Test on dev before prod
