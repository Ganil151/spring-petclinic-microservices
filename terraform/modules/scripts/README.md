# Spring Petclinic - Cloud-Init Bootstrap Handshake

This directory contains the **Minimal Handshake** scripts used by Terraform to prepare EC2 instances for automated configuration management via **Ansible**.

## 🏗️ Architecture: The Ansible Handshake
We use an "Industrial Rigor" approach where Terraform handles the infrastructure (Hardware) and Ansible handles the software (Configuration). 

The scripts in this directory are intentionally minimalist. They perform only the absolute necessities required at first boot:
1.  **Identity**: Sets the system hostname.
2.  **Connectivity**: Ensures Python 3 is installed so Ansible can connect.
3.  **Environment**: Injects a standardized `.bashrc` for developer experience.
4.  **Disk Prep**: Handles physical volume mounting (on worker nodes) before Docker is installed.

**All tool installations (Java 21, Docker, Kubernetes, etc.) are deferred to the Ansible `site.yml` playbook.**

## 📁 File Manifest

| File | Purpose |
|------|---------|
| `bastion_bootstrap.sh.tftpl` | Prepares the jump box for SSH tunneling and Ansible orchestration. |
| `jenkins_bootstrap.sh.tftpl` | Prepares the CI/CD master node. |
| `sonarqube_bootstrap.sh.tftpl` | Prepares the quality analysis node. |
| `worker_bootstrap.sh.tftpl` | Prepares Kubernetes worker nodes, including NVMe/EBS disk mounting. |
| `.bashrc` | The "Industrial Rigor" bash configuration injected into all nodes. |

## 🚀 Deployment Flow

1. **Terraform Apply**: 
   Terraform provisions the EC2 instances and executes these scripts via AWS User Data (Cloud-Init).
   
2. **The Wait**:
   The Terraform `ansible` module waits for these scripts to finish and for SSH to become reachable.
   
3. **Ansible Takeover**:
   Once reached, Ansible automatically triggers the `playbooks/site.yml` to install the full stack.

## 🔍 Troubleshooting
If an instance fails to join the Ansible inventory, check the cloud-init logs on the target host:
```bash
tail -f /var/log/cloud-init-output.log
```

## 🛡️ Security
These scripts ensure that from the very first second of life, the instances have:
- No root login.
- Key-based authentication requirements.
- Standardized audit trails.
