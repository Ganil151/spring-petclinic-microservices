# Ansible Configuration for Spring Petclinic Microservices

This directory contains the complete Ansible configuration for deploying and managing the Spring Petclinic microservices infrastructure.

## 📁 Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── requirements.yml            # Collection dependencies
├── inventory/
│   ├── hosts                  # Auto-generated inventory (from Terraform)
│   └── plugins/
│       └── aws_ec2.yml        # AWS dynamic inventory plugin
├── group_vars/
│   ├── all.yml               # Global variables
│   ├── jenkins_masters.yml   # Jenkins-specific variables
│   ├── sonarqube_servers.yml # SonarQube-specific variables
│   ├── k8s_workers.yml       # Kubernetes worker variables
│   └── bastion_hosts.yml     # Bastion host variables
├── host_vars/                 # Host-specific variables
├── playbooks/
│   ├── site.yml              # Main deployment playbook
│   ├── deployment/
│   │   └── security-hardening.yml  # Security hardening playbook
│   ├── provisioning/         # Infrastructure provisioning
│   └── security/             # Security-related playbooks
├── roles/
│   ├── awscli/               # AWS CLI installation
│   ├── docker/               # Docker installation & configuration
│   ├── git/                  # Git installation
│   ├── gitops_operator/      # ArgoCD/Flux installation
│   ├── helm/                 # Helm installation
│   ├── java/                 # Java installation
│   ├── jenkins/              # Jenkins deployment
│   ├── kubectl/              # kubectl installation
│   ├── kubernetes_setup/     # Kubernetes cluster setup
│   ├── security_tools/       # Security hardening tools
│   ├── trivy_scan/           # Trivy vulnerability scanner
│   └── vault_integration/    # HashiCorp Vault integration
├── templates/
│   └── fail2ban_jail_local.j2  # Fail2ban configuration template
├── tests/                     # Ansible test files
├── scripts/                   # Helper scripts
└── vault/                     # Encrypted secrets (Ansible Vault)
```

## 🚀 Quick Start

### Prerequisites

1. **Ansible** installed (version 2.14+)
2. **Terraform** outputs available (for inventory)
3. **SSH key** for instance access
4. **AWS credentials** configured

### Installation

```bash
# Install Ansible collections
cd ansible
ansible-galaxy install -r requirements.yml

# Verify inventory
ansible-inventory -i inventory/hosts --list

# Test connectivity
ansible all -i inventory/hosts -m ping
```

### Deploy Infrastructure

```bash
# Full deployment
ansible-playbook -i inventory/hosts playbooks/site.yml

# Deploy to specific environment
ansible-playbook -i inventory/hosts playbooks/site.yml -e environment=staging

# Deploy specific component (Jenkins only)
ansible-playbook -i inventory/hosts playbooks/site.yml --limit jenkins_masters

# Dry run (check mode)
ansible-playbook -i inventory/hosts playbooks/site.yml --check

# Verbose output
ansible-playbook -i inventory/hosts playbooks/site.yml -vvv
```

### Security Hardening

```bash
# Apply security hardening only
ansible-playbook -i inventory/hosts playbooks/deployment/security-hardening.yml

# Security hardening with specific tags
ansible-playbook -i inventory/hosts playbooks/deployment/security-hardening.yml \
  --tags ssh,firewall,fail2ban
```

## 📋 Playbooks

### site.yml - Main Deployment

The main entry point for all deployments. Orchestrates:
- Security hardening
- Infrastructure provisioning
- Jenkins deployment
- SonarQube deployment
- Kubernetes worker setup
- GitOps operators
- Security tools

### deployment/security-hardening.yml

Applies security hardening to all instances:
- SSH hardening
- Firewall configuration (firewalld)
- Fail2ban installation
- Audit logging
- User security
- Kernel hardening

**Tags:** `security`, `ssh`, `firewall`, `fail2ban`, `audit`, `users`, `hardening`

## 🔧 Roles

| Role | Description | Tags |
|------|-------------|------|
| `awscli` | AWS CLI v2 installation | `aws`, `cli` |
| `docker` | Docker installation & configuration | `docker`, `containers` |
| `git` | Git installation | `git`, `vcs` |
| `gitops_operator` | ArgoCD/FluxCD installation | `gitops`, `argocd` |
| `helm` | Helm 3 installation | `helm`, `k8s` |
| `java` | Java 21 (Amazon Corretto) | `java`, `jdk` |
| `jenkins` | Jenkins master deployment | `jenkins`, `cicd` |
| `kubectl` | kubectl installation | `kubectl`, `k8s` |
| `kubernetes_setup` | Kubernetes worker configuration | `kubernetes`, `k8s` |
| `security_tools` | Security hardening tools | `security`, `hardening` |
| `trivy_scan` | Trivy vulnerability scanner | `trivy`, `security` |
| `vault_integration` | HashiCorp Vault integration | `vault`, `secrets` |

## 📊 Group Variables

### all.yml - Global Configuration

```yaml
project_name: "spring-petclinic"
environment: "dev"
aws_region: "us-east-1"

# Security
security:
  ssh:
    permit_root_login: "no"
    password_authentication: "no"
  fail2ban:
    enabled: true
    bantime: 3600

# Docker
docker:
  version: "latest"
  storage_driver: "overlay2"

# Java
java:
  version: "17"
  distribution: "amazon"
```

### jenkins_masters.yml

Jenkins-specific configuration including plugins, Maven, Gradle.

### sonarqube_servers.yml

SonarQube configuration including quality gates and profiles.

### k8s_workers.yml

Kubernetes worker node configuration.

### bastion_hosts.yml

Bastion host security and session management.

## 🔐 Security

### Ansible Vault

Sensitive data is encrypted using Ansible Vault:

```bash
# Create encrypted file
ansible-vault create vault/secrets.yml

# Edit encrypted file
ansible-vault edit vault/secrets.yml

# View encrypted file
ansible-vault view vault/secrets.yml

# Run playbook with vault
ansible-playbook -i inventory/hosts playbooks/site.yml --ask-vault-pass
```

### SSH Key Management

SSH keys are managed via Terraform and stored in SSM Parameter Store.

## 📈 Monitoring & Logging

### CloudWatch Integration

All instances send logs to CloudWatch:
- `/spring-petclinic/{environment}/bastion`
- `/spring-petclinic/{environment}/jenkins`
- `/spring-petclinic/{environment}/sonarqube`
- `/spring-petclinic/{environment}/workers`

### Prometheus Metrics

Node exporter is installed on all instances for Prometheus scraping.

## 🔍 Troubleshooting

### Inventory Issues

```bash
# Regenerate inventory from Terraform
cd terraform/live/dev/ec2-instances
terragrunt apply -auto-approve

# Verify inventory
ansible-inventory -i ../ansible/inventory/hosts --graph
```

### Connection Issues

```bash
# Test SSH connectivity
ansible all -i inventory/hosts -m ping -vvv

# Check SSH key permissions
chmod 600 /path/to/spms-dev.pem
```

### Role Failures

```bash
# Run specific role with verbose output
ansible-playbook -i inventory/hosts playbooks/site.yml \
  --limit jenkins_masters \
  -e "ansible_verbosity=3" \
  --tags docker
```

## 📚 Related Documentation

- [DEPLOYMENT_CHECKLIST.md](../docs/DEPLOYMENT_CHECKLIST.md)
- [TERRAFORM_DEPLOYMENT.md](../docs/TERRAFORM_DEPLOYMENT.md)
- [Terraform Scripts](../terraform/scripts/README.md)

## 🎯 Best Practices

1. **Always use tags** to limit playbook scope
2. **Test in dev** before applying to staging/prod
3. **Use `--check`** for dry runs
4. **Encrypt secrets** with Ansible Vault
5. **Version control** all changes
6. **Review diffs** before applying
