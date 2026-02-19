# Spring PetClinic Microservices - Complete Deployment Checklist

## 📋 Table of Contents
1. [🏗️ System Architecture & Layered Breakdown](#system-architecture--layered-breakdown)
2. [🚀 Phase 0: Ground-Zero Setup (Bootstrapping)](#phase-0-ground-zero-setup-bootstrapping)
3. [🔐 Phase 1: Pre-Flight Essentials](#phase-1-pre-flight-essentials)
4. [🏗️ Phase 2: Infrastructure Provisioning (Terraform)](#phase-2-infrastructure-provisioning-terraform)
5. [🔧 Phase 3: Configuration & System Setup (Ansible & Jenkins)](#phase-3-configuration--system-setup-ansible--jenkins)
6. [🚢 Phase 4: CI/CD & Application Deployment (Helm)](#phase-4-cicd--application-deployment-helm)
7. [🧪 Phase 5: Validation & Health Checks](#phase-5-validation--health-checks)
8. [🛠️ Phase 6: Continuous Maintenance & Lifecycle](#phase-6-continuous-maintenance--lifecycle)
9. [📑 Troubleshooting & Procedures](#troubleshooting--procedures)

---

## 🏗️ System Architecture & Layered Breakdown
*Building a scalable foundation using Separation of Concerns.*

### 1. Detailed Layered Architecture
- **Layer 1: Terraform** (Networking, Compute, Persistence, Security, Observability)
- **Layer 2: Ansible** (Tooling: Java 21, Docker, Maven, Jenkins, SonarQube)
- **Layer 3: Helm** (Orchestration: Kubernetes Pods, Services, HPAs, Ingress)
- **Layer 4: Automation** (CI/CD Pipelines, Smoke Tests, Security Gates)

### 2. EC2 Instance Topology & Resource Allocation
| Role | Count | Instance Type | vCPU / RAM | Role Detail |
| :--- | :---: | :--- | :--- | :--- |
| **Jenkins Master** | 1 | `t3.large` | 2 / 8GB | Orchestration & Global Config Controller |
| **EKS Worker Nodes (Slaves)** | 3 | `t3.medium` | 2 / 4GB | Application Hosting (Managed Node Group) |
| **EKS Fargate (Serverless)** | N/A | Serverless | Pod-based | Cost-optimized compute for microservices |
| **SonarQube Server** | 1 | `t2.medium` | 2 / 4GB | Static Code Analysis (External Node) |

### 3. Tool Chain Integration Matrix
| Phase | Tool | Input | Output | Next Phase Uses |
| :--- | :--- | :--- | :--- | :--- |
| Infra | Terraform | `backend.tf`, `tfvars` | ECR URLs, RDS, EKS Config | Ansible, Infracost, Maven |
| CI/CD | Jenkins | `Jenkinsfile`, Git | Automated Artifacts/Deploys | Continuous Delivery |
| Quality | SonarQube | Maven Source | Quality Gate Results | Security Check |
| Security | Trivy / Checkov | Docker Images / IaC | Vulnerability Reports | Registry Management |
| Compute | EKS Fargate | Pod Specs | Serverless Runtime | Scaling / Cost Mgmt |
| Config | Ansible | EC2 IPs | Configured nodes with tools | Pytest, Maven, Docker |

---

## 🚀 Phase 0: Ground-Zero Setup (Bootstrapping)
*Only required when initializing the repository or adding new modules.*

### 0.1 Infrastructure Directory Structure
```bash
# Initialize Terraform Modules
mkdir -p terraform/modules/{vpc,eks,rds,alb,ecr,ec2,waf,monitoring,keys} && \
mkdir -p terraform/environments/{dev,staging,prod} && \
mkdir -p terraform/global/{route53,iam} && \
mkdir -p terraform/scripts

# Initialize Ansible Structure
mkdir -p ansible/{inventory,playbooks} && \
mkdir -p ansible/roles/{java,docker,awscli,maven,kubectl,helm,jenkins,sonarqube,security_tools}/tasks

# Initialize Helm & Testing
mkdir -p helm/microservices/{templates,overrides} && \
mkdir -p scripts testing/{infra,smoke,security,quality}
```

### 0.2 System Decision Record (SDR): OS Selection
**Recommendation: Amazon Linux 2023 (AL2023)**
1. **AWS Optimization:** 15-20% faster boot times for EKS nodes.
2. **Security:** SELinux pre-hardened; minimal attack surface.
3. **Efficiency:** Optimized binary set for cloud-native workloads.

---

## 🔐 Phase 1: Pre-Flight Essentials
*Verification of Identity, Tools, and Remote State.*

### 1.1 Identity & Permissions
- [ ] **AWS CLI Identity:** `aws sts get-caller-identity` (Verify Account/User)
- [ ] **AWS Region:** `aws configure get region` (Should be `us-east-1`)
- [ ] **Permission Probe:** `aws ec2 describe-vpcs --max-items 1`

### 1.2 Tool Version Verification
- [ ] **Terraform:** `terraform version` (v1.6.0+)
- [ ] **Ansible:** `ansible --version` (v2.14.0+)
- [ ] **kubectl:** `kubectl version --client` (v1.29.0)
- [ ] **Java:** `java -version` (OpenJDK 21)

### 1.3 State Backend (S3 + Native Locking)
1. **Bucket Creation:** `aws s3 mb s3://petclinic-terraform-state-RANDOM_SUFFIX`
2. **Hardening:** Enable Versioning, AES-256 Encryption, and Block Public Access.
3. **Locking:** Use `use_lockfile = true` in `backend.tf` for native S3 locking.
4. **Initialization:** `terraform init` -> Migrate local state to S3.

---

## 🏗️ Phase 2: Infrastructure Provisioning (Terraform)
*Deploying the cloud foundation with surgical precision.*

### 2.1 Dependency Order & Security
- [ ] **Audit:** `checkov -d . --framework terraform` (Ensuring 0 security failures).
- [ ] **Costing:** `infracost breakdown --path tfplan.json` (Monthly budget verification).

### 2.2 Provisioning Sequence
1. **Networking:** `terraform apply -target=module.networking` (VPC/NAT).
2. **ECR:** `terraform apply -target=module.ecr` (Private Registries).
3. **RDS (Database):**
   - `export TF_VAR_db_password="YourSecurePassword"`
   - `terraform apply -target=module.rds`
4. **EKS (Kubernetes):** 
   - `terraform apply -target=module.eks`
   - **Critical Fix:** Includes IRSA for EBS CSI Driver to prevent timeout/failed PVCs.
5. **Ingress & Security:** `terraform apply -target=module.alb` and `target=module.waf`.
6. **DNS & Monitoring:** `terraform apply -target=module.route53` and `target=module.monitoring`.

### 2.3 Post-Provisioning Verification
- [ ] **Configure Context:** `aws eks update-kubeconfig --name petclinic-dev-cluster`
- [ ] **Probe Nodes:** `kubectl get nodes` (Expected: 3 nodes in `Ready` state).
- [ ] **Secrets Verification:** Ensure `dev_secrets.json` is encrypted in S3.

---

## 🔧 Phase 3: Configuration & System Setup (Ansible & Jenkins)
*Internal plumbing and CI/CD controller initialization.*

### 3.1 Establishing Secure Connectivity
- [ ] **Extract IPs:** Gather Jenkins Master and EKS worker IPs via AWS CLI.
- [ ] **Key Exchange:** `cd terraform/scripts && ./configure_ssh.sh`
- [ ] **Connectivity Test:** `ansible all -m ping -i inventory/dynamic_hosts`

### 3.2 Automated Tool Installation (The 5 Plays)
- [ ] **Run Playbook:** `ansible-playbook -i inventory/dynamic_hosts playbooks/install-tools.yml`
- [ ] **Targets:** Java 21, Docker, Maven, Kubectl, and Helm installed across the fleet.

### 3.3 Jenkins Global Configuration
- [ ] **Plugin Installation:** (Pipeline, ECR, AWS Steps, Docker, SonarQube).
- [ ] **Controller Hardening:** Deploy Nginx Reverse Proxy with SSL termination.
- [ ] **Global Tool Config:** Define `jdk-21` and `maven-3.9`.
- [ ] **Credentials:** Store `aws-creds` and `sonarqube-token` securely.

---

## 🚢 Phase 4: CI/CD & Application Deployment (Helm)
*Delivering the code from source to production.*

### 4.1 Shift-Left Security Gates
- [ ] **Unit Tests:** `./mvnw clean test` (Verify business logic).
- [ ] **Static Analysis:** Trigger SonarQube scan; verify quality gate.
- [ ] **Vulnerability Scan:** `trivy image` scan for microservice Docker images.

### 4.2 Artifact Rollout
- [ ] **Docker Packaging:** `./mvnw install -P buildDocker`
- [ ] **Registry Sync:** Push images to ECR repositories with semantic tagging.
- [ ] **Namespace Setup:** `kubectl create namespace petclinic`

### 4.3 Helm Deployment
```bash
helm upgrade --install petclinic ./helm/microservices \
  -f ./helm/microservices/overrides/dev.yaml \
  --set global.ecrRegistry=${ECR_REGISTRY} --wait --timeout 300s
```

---

## 🧪 Phase 5: Validation & Health Checks
*Proving the system is operational.*

### 5.1 System Probes
- [ ] **Pod Stability:** `kubectl get pods -n petclinic` (Verify zero restarts).
- [ ] **Database Link:** Test RDS connection from a running microservice pod.
- [ ] **Load Balancer:** Access the ALB DNS and verify HTTP 200 responses.

### 5.2 Quality Assurance
- [ ] **Smoke Tests:** `pytest -v tests/smoke/test_endpoints.py --base-url=${ALB_DNS}`
- [ ] **Metrics:** Verify Prometheus/Grafana dashboards are receiving data.
- [ ] **Auto-Scaling:** Validate HPA (Horizontal Pod Autoscaler) behavior under simulated load.

---

## 🛠️ Phase 6: Continuous Maintenance & Lifecycle
*Day-2 Operations and Cost Optimization.*

### 6.1 Lifecycle Management
- [ ] **ECR Cleanup:** Set policies to expire untagged/old images (> 5 versions).
- [ ] **Log Retention:** Set CloudWatch log groups to expire after 30 days.

### 6.2 Reliability
- [ ] **Snapshots:** Verify RDS automated backup windows and snapshot availability.
- [ ] **Drift Detection:** Run `terraform plan` periodically to detect infrastructure drift.

---

## 📑 Troubleshooting & Procedures

### Common Resolutions
| Issue | Solution |
| :--- | :--- |
| **State Lock** | `terraform force-unlock <LOCK_ID>` |
| **PVC Pending** | Ensure `aws-ebs-csi-driver` add-on is ACTIVE with IRSA |
| **ALB 503** | Verify Service/TargetGroup health check mappings |
| **ECR 403** | Run `aws ecr get-login-password` to refresh token |

### Cleanup Procedure
```bash
# Delete K8s Resources
kubectl delete namespace petclinic
# Destroy Infrastructure
terraform destroy -auto-approve
```

---
**Last Updated:** 2026-02-19
**Status:** ✅ Fully Refactored & IRSA-Fixed
