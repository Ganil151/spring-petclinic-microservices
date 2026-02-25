# Ansible Configuration for Spring Petclinic Microservices

This directory contains the complete Ansible configuration for deploying and managing the Spring Petclinic microservices infrastructure.

## 📁 Directory Structure

```
ansible/
├── ansible.cfg # Ansible runtime configuration (production profile)
├── .ansible-lint.yml # Linting rules for code quality enforcement
├── requirements.yml # Ansible Galaxy collection dependencies
├── collections/
│ └── ansible_collections/
│ └── kubernetes/core/ # kubernetes.core collection for K8s module support
├── inventory/
│ ├── hosts # Static inventory (fallback)
│ ├── aws/ec2.yml # AWS EC2 dynamic inventory plugin config
│ └── plugins/aws_ec2.yml # Plugin configuration for auto-discovery
├── group_vars/
│ ├── all.yml # Global variables (project_name, aws_region, etc.)
│ ├── bastion_hosts.yml # Bastion host security & session config
│ ├── cicd.yml # CI/CD pipeline variables
│ ├── database.yml # RDS connection parameters
│ ├── dev.yml # Development environment overrides
│ ├── jenkins_masters.yml # Jenkins master configuration
│ ├── k8s_cluster.yml # EKS cluster connection details
│ ├── k8s_workers.yml # Worker node runtime config
│ ├── monitoring.yml # Prometheus/Grafana/CloudWatch settings
│ ├── production.yml # Production-hardened overrides
│ ├── sonarqube_servers.yml # SonarQube server configuration
│ └── staging.yml # Staging environment overrides
├── host_vars/
│ ├── jenkins-master.yml # Host-specific Jenkins config
│ ├── k8s-control.yml # Control plane node settings
│ ├── k8s-worker-01.yml # Worker node overrides
│ ├── sonarqube.yml # SonarQube host config
│ └── worker-node.yml # Generic worker template
├── playbooks/
│ ├── site.yml # Main orchestration playbook (entry point)
│ ├── deployment/
│ │ ├── bastion-setup.yml # Bastion host hardening
│ │ ├── jenkins-setup.yml # Jenkins CI/CD server deployment
│ │ ├── monitoring-stack.yml # Prometheus + Grafana + CloudWatch agent
│ │ └── security-hardening.yml # CIS benchmark compliance
│ ├── provisioning/
│ │ ├── prerequisites.yml # Pre-flight tool/version checks
│ │ ├── vpc-network.yml # VPC/subnet orchestration via Terragrunt
│ │ ├── rds-provision.yml # RDS MySQL provisioning
│ │ └── k8s-cluster.yml # EKS cluster provisioning
│ └── security/
│ ├── gitops-operator.yml # ArgoCD/FluxCD installation
│ ├── trivy-scan.yml # Container vulnerability scanning
│ └── vault-integration.yml # HashiCorp Vault secret injection
├── roles/
│ ├── awscli/ # AWS CLI v2 installation & config
│ ├── cloudwatch_agent/ # CloudWatch Logs/Metrics agent setup
│ ├── common/ # Base OS configuration (users, MOTD, bashrc)
│ ├── docker/ # Docker Engine installation & daemon.json
│ ├── git/ # Git installation & config
│ ├── gitops_operator/ # ArgoCD/FluxCD deployment
│ ├── helm/ # Helm 3 installation & repo management
│ ├── infracost/ # Infrastructure cost estimation
│ ├── java/ # Amazon Corretto 21 installation
│ ├── jenkins/ # Jenkins master deployment & JCasC
│ ├── kubectl/ # kubectl installation & kubeconfig setup
│ ├── kubernetes_setup/ # EKS worker node K8s configuration
│ ├── maven/ # Maven installation & settings.xml
│ ├── security_tools/ # fail2ban, auditd, CIS hardening
│ ├── sonarqube/ # SonarQube server deployment
│ ├── terraform/ # Terraform CLI installation
│ ├── terragrunt/ # Terragrunt CLI installation
│ ├── trivy_scan/ # Trivy container scanner setup
│ └── vault_integration/ # Vault agent & secret injection
├── templates/
│ ├── fail2ban_jail_local.j2 # Fail2ban jail configuration
│ └── motd.j2 # Custom message-of-the-day
├── scripts/
│ ├── bootstrap.sh # Initial environment setup
│ ├── vault-unseal.sh # Vault auto-unseal helper
│ ├── ansible/
│ │ ├── inventory-sync.sh # Sync Terraform outputs to Ansible inventory
│ │ └── run-playbook.sh # Wrapper for playbook execution
│ ├── deployment/
│ │ ├── deploy-app.sh # Application deployment helper
│ │ └── rollback-app.sh # Rollback helper script
│ ├── security/
│ │ ├── compliance-check.sh # CIS benchmark validation
│ │ ├── scan-images.sh # Container image scanning
│ │ └── validate-secrets.sh # Secret rotation validation
│ └── terraform/
│ ├── init-all.sh # Initialize all Terragrunt modules
│ ├── plan-all.sh # Plan all environments
│ ├── apply-all.sh # Apply all environments
│ ├── backend_setup.sh # S3 backend initialization
│ └── .terraform_bucket_name # Backend bucket name reference
├── tests/
│ └── integration/ # Molecule/pytest integration tests
├── vault/
│ ├── config/
│ │ └── vault-connection.yml # Vault connection parameters (encrypted)
│ ├── policies/ # Vault policy definitions
│ └── secrets/
│ ├── db-creds.yml # Database credentials (Ansible Vault)
│ └── prod-vault.yml # Production secrets (Ansible Vault)
├── .vault_pass # Vault password file reference (gitignored)
├── plugins/
│ ├── filter/ # Custom Jinja2 filters
│ └── lookup/ # Custom lookup plugins
├── meta/
│ └── runtime.yml # Collection runtime metadata
└── README.md # This file
```

## 🚀 Quick Start

### Prerequisites

| Requirement | Version | Verification |
|------------|---------|-------------|
| **Ansible** | ≥ 2.14 | `ansible --version` |
| **Python** | ≥ 3.9 | `python3 --version` |
| **AWS CLI** | ≥ 2.0 | `aws --version` |
| **Terraform** | ≥ 1.5 | `terraform version` |
| **Terragrunt** | ≥ 0.50 | `terragrunt --version` |
| **kubectl** | ≥ 1.28 | `kubectl version --client` |
| **helm** | ≥ 3.12 | `helm version` |

### Installation

```bash
# Navigate to ansible directory
cd ansible

# Install required collections (from requirements.yml)
ansible-galaxy install -r requirements.yml

# Verify collections installed correctly
ansible-galaxy collection list | grep -E "(kubernetes|amazon)"

# Verify inventory sources
ansible-inventory -i inventory/hosts --list --yaml | head -30

# Test connectivity to all hosts
ansible all -i inventory/hosts -m ping
```

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
