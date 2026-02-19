# Spring PetClinic Microservices - Complete Deployment Checklist

## 📋 Table of Contents
1. [🏗️ System Architecture & Context](#system-architecture--context)
2. [🚀 Phase 0: Ground-Zero Setup (Bootstrapping)](#phase-0-ground-zero-setup-bootstrapping)
3. [🔐 Phase 1: Pre-Flight Essentials](#phase-1-pre-flight-essentials)
4. [🏗️ Phase 2: Infrastructure Provisioning (Terraform)](#phase-2-infrastructure-provisioning-terraform)
5. [🔧 Phase 3: Configuration & System Setup (Ansible & Jenkins)](#phase-3-configuration--system-setup-ansible--jenkins)
6. [🚢 Phase 4: CI/CD & Application Deployment (Helm)](#phase-4-cicd--application-deployment-helm)
7. [🧪 Phase 5: Validation & Health Checks](#phase-5-validation--health-checks)
8. [🛠️ Phase 6: Continuous Maintenance & Lifecycle](#phase-6-continuous-maintenance--lifecycle)
9. [📑 Troubleshooting & Procedures](#troubleshooting--procedures)

---

## 🏗️ System Architecture & Context
*Understanding the foundation before pulling the trigger.*

### 1. Deployment Flow Diagram
```
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1: PRE-FLIGHT                          │
│  AWS Credentials → Tool Versions → State Backend Setup         │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│         PHASE 2: INFRASTRUCTURE (Terraform)                     │
│  VPC → SG → EC2 (Jenkins/Worker/SonarQube) → EKS → RDS         │
│  ├─► user_data: hostname + python3 + disk mgmt (bare minimum)  │
│  └─► local_file: auto-generates ansible/inventory/dynamic_hosts │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│         PHASE 3: CONFIGURATION (Ansible — 5 Plays)              │
│  Play 1 (all):     Java 21 → Docker + Compose → AWS CLI v2     │
│  Play 2 (jenkins): Jenkins install → Plugins → SSH keygen      │
│  Play 3 (workers): Maven → Kubectl → Helm                      │
│  Play 4 (sonar):   Kernel tuning → Docker Compose stack        │
│  Play 5 (devops):  Trivy → Checkov                             │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│              PHASE 4: BUILD & DEPLOY                            │
│  Maven Build → Docker Build → ECR Push → K8s Deploy            │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│              PHASE 5: VALIDATION & MONITORING                   │
│  Health Checks → DNS → Database → Metrics → Logs               │
└─────────────────────────────────────────────────────────────────┘
```

### 2. EC2 Instance Topology & Resource Allocation
| Role | Count | Instance Type | vCPU / RAM | Role Detail |
| :--- | :---: | :--- | :--- | :--- |
| **Jenkins Master** | 1 | `t3.large` | 2 / 8GB | Orchestration & Global Config Controller |
| **EKS Worker Nodes (Slaves)** | 3 | `t3.medium` | 2 / 4GB | Application Hosting (Legacy EC2 Mode) |
| **EKS Fargate (Serverless)** | N/A | Serverless | Pod-based | Cost-optimized, zero-management compute |
| **SonarQube Server** | 1 | `t2.medium` | 2 / 4GB | Static Code Analysis (External Node) |

### 3. Tool Chain Integration Matrix
| Phase | Tool | Input | Output | Next Phase Uses |
| :--- | :--- | :--- | :--- | :--- |
| Infra | Terraform | `backend.tf`, `tfvars` | ECR URLs, RDS, EKS Config | Infracost, Ansible, Maven |
| CI/CD | Jenkins | `Jenkinsfile`, Git | Automated Artifacts/Deploys | Continuous Delivery |
| Quality | SonarQube | Maven Source | Quality Gate Results | Security Check |
| Security | Trivy / Checkov | Docker Images / IaC | Vulnerability Reports | Registry Management |
| Compute | EKS Fargate | Pod Specs | Serverless Runtime | Scaling / Cost Mgmt |
| Config | Ansible | EC2 IPs | Configured nodes with tools | Pytest, Maven, Docker |

### 4. Detailed Infrastructure Breakdown (Layer 1-4)
- **Layer 1: Terraform** (Networking, Compute, RDS, WAF, Route53, Monitoring)
- **Layer 2: Ansible** (Java 21, Docker, Maven, Jenkins, SonarQube)
- **Layer 3: Helm** (Microservices packaging & orchestration)
- **Layer 4: Scripts** (Lifecycle automation, Shift-Left security)

---

## 🚀 Phase 0: Ground-Zero Setup (Bootstrapping)
*Only required when initializing the repository or adding new modules.*

### 0.1 Terraform Structure
```bash
mkdir -p terraform/modules/{vpc,eks,rds,alb,ecr,ec2,waf,monitoring} && \
mkdir -p terraform/environments/{dev,staging,prod} && \
mkdir -p terraform/global/{route53,iam} && \
mkdir -p terraform/scripts && \
touch terraform/modules/vpc/{main,variables,outputs}.tf && \
touch terraform/modules/eks/{main,variables,addons,irsa,outputs}.tf && \
touch terraform/modules/rds/{main,variables,outputs,security-group}.tf && \
touch terraform/modules/alb/{main,variables,outputs}.tf && \
touch terraform/modules/ecr/{main,variables,outputs}.tf && \
touch terraform/modules/ec2/{main,variables,outputs}.tf && \
touch terraform/modules/waf/{main,variables,outputs}.tf && \
touch terraform/environments/dev/{main,backend,providers,variables,versions}.tf && \
touch terraform/environments/dev/terraform.tfvars
```

### 0.2 Ansible Structure
```bash
mkdir -p ansible/{inventory,playbooks} && \
mkdir -p ansible/roles/{java,docker,awscli,maven,kubectl,helm,security_tools}/tasks && \
mkdir -p ansible/roles/jenkins/{tasks,handlers} && \
mkdir -p ansible/roles/sonarqube/{tasks,templates} && \
touch ansible/ansible.cfg && \
touch ansible/playbooks/install-tools.yml
```

### 0.3 Helm & Lifecycle Structure
```bash
mkdir -p helm/microservices/{templates,overrides} && \
touch helm/microservices/{Chart.yaml,values.yaml} && \
mkdir -p scripts testing/{infra,smoke,security,quality} && \
touch scripts/{build-and-push,deploy,aws-auth,cleanup}.sh && \
chmod +x scripts/*.sh
```

---

## 🔐 Phase 1: Pre-Flight Essentials
*Verification of Identity, Tools, and Remote State.*

### 1.1 Cloud Identity Verification
- [ ] **Verify AWS CLI credentials:** `aws sts get-caller-identity` (Check Account/User)
- [ ] **Verify active AWS region:** `aws configure get region` (Should be `us-east-1`)
- [ ] **Test AWS permissions:** `aws ec2 describe-vpcs --max-items 1`

### 1.2 Tool Version Verification
- [ ] **Terraform:** `terraform version` (Expected: v1.6.0+)
- [ ] **Ansible:** `ansible --version` (Expected: v2.14.0+)
- [ ] **kubectl:** `kubectl version --client` (Expected: v1.29.0)
- [ ] **Java:** `java -version` (Expected: OpenJDK 21)
- [ ] **Docker & Maven:** `docker --version` && `mvn -version`

### 1.3 State Backend Initialization (S3 + Native Locking)
1. **Create S3 Bucket:** `aws s3 mb s3://petclinic-terraform-state-RANDOM_SUFFIX`
2. **Enable Versioning:** `aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled`
3. **Enable Encryption:** `aws s3api put-bucket-encryption --bucket $BUCKET_NAME ...`
4. **Configure Backend.tf:** Ensure `use_lockfile = true` is set for native S3 locking.
5. **Migrate State:** `terraform init` (Select **yes** to migrate local state).

---

## 🏗️ Phase 2: Infrastructure Provisioning (Terraform)
*Deploying the cloud foundation module-by-module.*

### 2.1 Deployment Strategy & Security
- [ ] **Dependency Order:** Networking -> ECR -> RDS -> EKS -> ALB -> WAF -> Route53 -> Monitoring.
- [ ] **Infrastructure Audit:** `checkov -d . --framework terraform` (Ensure 0 Critical failures).
- [ ] **Cost Estimation:** `infracost breakdown --path tfplan.json` (Verify budget).

### 2.2 Provisioning Steps
- [ ] **Networking:** `terraform apply -target=module.networking` (VPC, Subnets, NAT).
- [ ] **ECR:** `terraform apply -target=module.ecr` (Microservice Registries).
- [ ] **RDS (Database):**
  - `export TF_VAR_db_password="YourSecurePassword123"`
  - `terraform apply -target=module.rds`
- [ ] **EKS (Kubernetes):** `terraform apply -target=module.eks` (Control plane & node groups).
- [ ] **ALB & WAF:** `terraform apply -target=module.alb` then `target=module.waf`.
- [ ] **Route53 & Monitoring:** Assign DNS alias and configure CloudWatch Alarms.

---

## 🔧 Phase 3: Configuration & System Setup (Ansible & Jenkins)
*Setting up the internal plumbing and CI/CD tools.*

### 3.1 Establishing Connectivity
- [ ] **Extract Node IPs:** Pull Jenkins Master and EKS worker IPs via AWS CLI/kubectl.
- [ ] **Run SSH Config:** `cd terraform/scripts && ./configure_ssh.sh` (Automates key exchange).
- [ ] **Ansible Ping:** `ansible all -m ping -i inventory/dynamic_hosts`

### 3.2 System Configuration (5 Plays)
- [ ] **Install Tools:** `ansible-playbook -i inventory/dynamic_hosts playbooks/install-tools.yml`
- [ ] **Verify Core:** Java 21, Docker, Maven, and AWS CLI v2 verified on all nodes.
- [ ] **Secure Jenkins Master:** Deploy Nginx Reverse Proxy with SSL termination.

### 3.3 Jenkins Global Setup
- [ ] **Plugin Checklist:** (Pipeline, ECR, AWS Steps, Docker, SonarQube, Dependency Check).
- [ ] **Tool Config:** Map `jdk-21` and `maven-3.9` in Global Tool Configuration.
- [ ] **Secrets:** Add `aws-creds` and `sonarqube-token` to the Jenkins Credential Store.

---

## 🚢 Phase 4: CI/CD & Application Deployment (Helm)
*Delivering the code from source to production.*

### 4.1 Build & Security Gates (Shift-Left)
- [ ] **Local Maven Clean:** `./mvnw clean install -DskipTests`
- [ ] **Unit Tests:** `./mvnw clean test` (Verify 100% pass rate).
- [ ] **Security Scans:** Use SonarQube for static analysis and OWASP for dependency CVEs.

### 4.2 Artifact Preparation
- [ ] **Docker Build:** `./mvnw install -P buildDocker` (Packages microservices).
- [ ] **Container Scanning:** `trivy image --severity HIGH,CRITICAL petclinic-api-gateway:latest`
- [ ] **ECR Push:** Push images to Private AWS ECR with semantic versioning (`v1.0.0`).

### 4.3 Kubernetes Rollout (Helm)
- [ ] **Create Namespace:** `kubectl create namespace petclinic`
- [ ] **Inject Database Secret:** Create generic secret with RDS endpoints and passwords.
- [ ] **Helm Installation:**
  ```bash
  helm upgrade --install petclinic ./helm/microservices \
    -f ./helm/microservices/overrides/dev.yaml \
    --set global.ecrRegistry=${ECR_REGISTRY} --wait
  ```

---

## 🧪 Phase 5: Validation & Health Checks
*Proving the system is operational.*

### 5.1 System Health
- [ ] **Pod Status:** `kubectl get pods -n petclinic` (Verify `Running` status).
- [ ] **Actuator Health:** Access `/actuator/health` via port-forwarding.
- [ ] **RDS Probe:** `kubectl exec` into a pod and test MySQL connectivity.

### 5.2 End-to-End & Stress Testing
- [ ] **Smoke Test (Pytest):** `pytest -v tests/smoke/test_endpoints.py --base-url=${ALB_DNS}`
- [ ] **Load Test (JMeter):** Stress test the HPA (Horizontal Pod Autoscaler).
- [ ] **Chaos Engineering:** Inject pod failures and verify K8s self-healing.

---

## 🛠️ Phase 6: Continuous Maintenance & Lifecycle
*Day-2 Operations and Cost Optimization.*

### 6.1 Cost & Storage Management
- [ ] **ECR Lifecycle:** Set policies to delete untagged/old images (> 5 versions).
- [ ] **Log Retention:** Set CloudWatch logs to expire after 30 days.

### 6.2 Resilience
- [ ] **RDS Backups:** Verify Multi-AZ standby and snapshot schedules.
- [ ] **Monitoring:** Ensure Prometheus/Grafana dashboards are receiving pod metrics.

---

## 📑 Troubleshooting & Procedures

### Common Resolutions
| Issue | Solution |
| :--- | :--- |
| **State Lock** | `terraform force-unlock <ID>` |
| **EKS Nodes** | Wait 5m, check IAM role attachment |
| **ALB 503** | Verify target group health checks |
| **ECR Auth** | Re-run `aws ecr get-login-password` |

### System Decision Record (SDR): OS Selection
**Recommendation: Amazon Linux 2023 (AL2023)**
1. **AWS Optimization:** 15-20% faster boot times for EKS.
2. **Security:** Pre-hardened SELinux & minimal package set.
3. **Support:** Predictable 5-year lifecycle.

### Cleanup Procedure
```bash
# Delete K8s
kubectl delete namespace petclinic
# Destroy Infra
terraform destroy -auto-approve
```

---
**Last Updated:** 2026-02-19
**Status:** ✅ Fully Refactored & Optimized (Detail Preserved)
