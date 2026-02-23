# Terraform & Bootstrap Scripts for Spring Petclinic

This directory contains scripts for automating infrastructure deployment and instance bootstrapping.

## 📁 Script Overview

| Script | Purpose | Target |
|--------|---------|--------|
| `bastion_bootstrap.sh` | Configures bastion host with all required tools | Bastion EC2 |
| `run_bastion_bootstrap.sh` | Copies and executes bastion bootstrap | Local → Bastion |
| `jenkins_bootstrap.sh` | Configures Jenkins master instance | Jenkins EC2 |
| `sonarqube_bootstrap.sh` | Configures SonarQube server | SonarQube EC2 |
| `worker_bootstrap.sh` | Configures Kubernetes worker nodes | Worker EC2 |

## 🚀 Quick Start

### 1. Deploy Infrastructure with Terraform

```bash
cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/live/dev/ec2-instances
terragrunt init
terragrunt apply -auto-approve
```

### 2. Bootstrap Bastion Host

```bash
cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/scripts
./run_bastion_bootstrap.sh
```

### 3. Connect to Bastion

```bash
# SSH to bastion
ssh -i ../live/dev/key-pair/spms-dev.pem ec2-user@<bastion-public-ip>

# From bastion, SSH to private instances
ssh ec2-user@<private-instance-ip>
```

## 📋 Bootstrap Scripts Details

### bastion_bootstrap.sh

**Installs and configures:**
- Docker
- AWS CLI v2
- Git
- Terraform
- Terragrunt
- kubectl
- helm
- fail2ban (security)
- CloudWatch Logs Agent

**Security hardening:**
- SSH configuration (no root login, key-based auth)
- fail2ban for intrusion prevention
- Audit logging

**Ansible Roles:** `docker`, `git`, `awscli`, `security_tools`

### jenkins_bootstrap.sh

**Installs and configures:**
- Docker
- Jenkins (via Docker)
- Java 17
- AWS CLI
- Maven

**Ansible Roles:** `java`, `docker`, `awscli`, `jenkins`, `security_tools`

### sonarqube_bootstrap.sh

**Installs and configures:**
- Docker
- SonarQube (via Docker)
- Java 17

**Ansible Roles:** `java`, `docker`, `awscli`, `sonarqube`, `security_tools`

### worker_bootstrap.sh

**Installs and configures:**
- Docker
- Kubernetes tools (kubelet, kubeadm, kubectl)
- Maven
- AWS CLI
- Git

**Ansible Roles:** `java`, `docker`, `awscli`, `maven`, `kubectl`, `helm`

## 🔧 Manual Execution

If you prefer to run bootstrap scripts manually:

```bash
# Copy script to instance
scp -i <key.pem> scripts/bastion_bootstrap.sh ec2-user@<instance-ip>:/tmp/

# SSH to instance
ssh -i <key.pem> ec2-user@<instance-ip>

# Execute script
sudo bash /tmp/bastion_bootstrap.sh
```

## 📊 Ansible Inventory

After running `terraform apply`, an Ansible inventory file is automatically generated at:

```
/home/gsmash/Documents/spring-petclinic-microservices/ansible/inventory/hosts
```

This inventory includes all EC2 instances with their:
- Public IPs
- Private IPs
- Assigned Ansible roles
- Environment variables

### Example Inventory Output

```ini
[jenkins_masters]
jenkins-master ansible_host=54.82.175.129 private_ip=10.0.1.73

[sonarqube_servers]
sonarqube-server ansible_host=54.167.239.11 private_ip=10.0.1.245

[k8s_workers]
worker-node-1 ansible_host=184.73.71.253 private_ip=10.0.1.116
worker-node-2 ansible_host=44.222.244.48 private_ip=10.0.2.134

[bastion_hosts]
bastion-host ansible_host=35.172.255.177 private_ip=10.0.1.131
```

## 🔍 Troubleshooting

### Bootstrap Script Fails

1. Check the log file on the instance:
   ```bash
   cat /var/log/bastion_bootstrap.log
   ```

2. Verify instance has internet connectivity:
   ```bash
   ping -c 3 google.com
   ```

3. Check IAM role permissions:
   ```bash
   aws iam get-role --role-name <instance-role>
   ```

### SSH Connection Issues

1. Verify security group allows SSH (port 22):
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

2. Check key permissions:
   ```bash
   chmod 600 /path/to/key.pem
   ```

3. Verify instance is running:
   ```bash
   aws ec2 describe-instances --instance-ids <instance-id>
   ```

## 📝 Best Practices

1. **Always run bootstrap scripts with `sudo`** - They install system packages
2. **Review scripts before execution** - Understand what changes will be made
3. **Keep scripts version controlled** - Track changes in Git
4. **Test in dev environment first** - Before applying to staging/prod
5. **Monitor CloudWatch Logs** - Bootstrap logs are sent to CloudWatch

## 📚 Related Documentation

- [DEPLOYMENT_CHECKLIST.md](../../docs/DEPLOYMENT_CHECKLIST.md)
- [TERRAFORM_DEPLOYMENT.md](../../docs/TERRAFORM_DEPLOYMENT.md)
- [Ansible Playbooks](../../ansible/README.md)
