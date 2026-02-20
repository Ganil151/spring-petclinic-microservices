# 📋 Spring PetClinic Microservices - Complete Deployment Checklist

## 🛡️ Pre-Deployment Audit Status (DevSecOps Review)
**Lead Auditor:** Principal DevSecOps & Platform Engineer  
**Status:** ⚠️ **REMEDIATION REQUIRED** (High-Priority Security & Reliability Findings)

| Category | Finding | Recommended Action | Status |
| :--- | :--- | :--- | :--- |
| **Security** | RDS Port `3306` is open to `0.0.0.0/0` in `terraform.tfvars`. | Restrict access to VPC CIDR or EC2 Security Groups ONLY. | ❌ CRITICAL |
| **Integrity** | Terraform uses `use_lockfile` (S3 native) instead of DynamoDB. | Standardize to S3 + DynamoDB locking for production state. | ⚠️ MEDIUM |
| **Reliability** | Kubernetes manifests lack `liveness` and `readiness` probes. | Implement HTTP probes to `/actuator/health`. | ⚠️ HIGH |
| **Secrets** | Jenkinsfile uses auto-detected ECR Registry via AWS CLI. | Ensure IAM roles follow 'Least Privilege' strictly. | ✅ PASS |

---

## Overview
This checklist provides a comprehensive, step-by-step guide for deploying the Spring PetClinic Microservices application to AWS using Terraform, Ansible, and Kubernetes.

---

## 🏗️ Detailed Project Infrastructure Breakdown
This repository is architected following the **Separation of Concerns** principle, ensuring each layer of the stack is modular, testable, and independently scalable.

### Part 1: Layer 1 - Infrastructure Provisioning (Terraform)
*Deep-dive into the "Hard" hardware that forms the foundation of the cloud environment.*

```text
terraform/
├── modules/                              # Reusable, parameterized components (SRE-Grade)
│   ├── networking/                       # Connectivity & Traffic Control (VPC, SG, ALB)
│   ├── compute/                          # Processing & Orchestration (EKS, EC2)
│   ├── database/                         # Persistence & Data Storage (RDS)
│   ├── ecr/                              # Container Artifact Storage
│   ├── waf/                              # Perimeter Security (Web Application Firewall)
│   ├── keys/                             # SSH Key Management
│   └── monitoring/                       # Observability (Health & Performance)
├── environments/                         # Environment-Specific Workspaces
│   ├── dev/                              # Sandbox: Cost-Optimized settings
│   │   ├── main.tf                       # Composes modules (Low-Scale)
│   │   ├── backend.tf                    # Remote State: s3://petclinic-terraform-state-17a538b3/tfstate/dev/
│   │   ├── keypair.tf                    # Key pair instantiation
│   │   ├── providers.tf                  # Region + Default Tags
│   │   ├── terraform.tfvars              # Dev params (t3.medium nodes)
│   │   └── ...
```

### 🛠️ Bootstrapping the Terraform Structure
Run the following command to initialize the directory structure and placeholder files:
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
touch terraform/environments/dev/terraform.tfvars && \
touch terraform/environments/staging/{main,backend,providers,variables,versions}.tf && \
touch terraform/environments/staging/terraform.tfvars && \
touch terraform/environments/prod/{main,backend,providers,variables,versions}.tf && \
touch terraform/environments/prod/terraform.tfvars
```


### Part 2: Layer 2 - Configuration Management (Ansible)
*The "Last Mile" of server setup, hardening the AL2023 OS and configuring the devops toolbelt.*

```text
ansible/
├── ansible.cfg                   # SSH Multiplexing & Pipelining optimizations
├── inventory/                    # Target definitions & Environment mapping
│   ├── hosts                     # Target IPs for Development nodes
│   └── group_vars/               # Global vars (JAVA_HOME, DOCKER_VERSION)
├── roles/                        # Self-contained "Configuration Blocks"
│   ├── docker/                   # Container engine setup
│   ├── eks_setup/                # EKS node initialization
│   ├── java/                     # JDK 21 installation
│   └── sonarqube/                # SonarQube container deployment
└── playbooks/                    # The Execution Mastermind
    └── site.yml                  # Entry point mapping roles to specific node groups
```

### 🛠️ Bootstrapping the Ansible Structure
Run the following command to initialize the Ansible directory structure and role skeleton:
```bash
mkdir -p ansible/{inventory/group_vars,roles/security_hardening/tasks,roles/install_tools/{tasks,vars},playbooks} && \
touch ansible/ansible.cfg && \
touch ansible/inventory/dev.ini && \
touch ansible/roles/security_hardening/tasks/main.yml && \
touch ansible/roles/install_tools/tasks/{java,docker,kubernetes}.yml && \
touch ansible/roles/install_tools/vars/main.yml && \
touch ansible/playbooks/site.yml
```

### Part 3: Layer 3 - Container Orchestration (Helm & Microservices)
*Governs the packaging, scaling, and traffic routing for the PetClinic microservices.*

```text
helm/
└── microservices/
    ├── Chart.yaml                # Standardized metadata
    ├── values.yaml               # Default service values
    ├── templates/                # Reusable YAML blueprints
    │   ├── deployment.yaml       # Scaling & Health Check logic
    │   ├── service.yaml          # ClusterIP/LoadBalancer exposing
    │   ├── ingress.yaml          # L7 routing rules
    │   └── hpa.yaml              # Auto-scaling triggers
    └── overrides/                # Env-specific tuning
        ├── dev.yaml              # Debugging & minimal resources
        └── prod.yaml             # HA & strict resource limits
```

### 🛠️ Bootstrapping the Helm Structure
Run the following command to initialize the Helm chart structure and templates:
```bash
mkdir -p helm/microservices/{templates,overrides} && \
touch helm/microservices/{Chart.yaml,values.yaml} && \
touch helm/microservices/templates/{deployment,service,ingress,hpa}.yaml && \
touch helm/microservices/templates/_helpers.tpl && \
touch helm/microservices/overrides/{dev,prod}.yaml
```

### Part 4: Layer 4 - Lifecycle Automation (Scripts & Quality)
*The connective tissue that enforces the CI/CD workflow and production standards.*

```text
scripts/
├── build-and-push.sh             # Maven artifacting → ECR Registry
├── deploy.sh                     # AWS Auth → Kubeconfig → Helm Upgrade
├── aws-auth.sh                   # Dynamic STS/ECR Auth
└── cleanup.sh                    # FinOps: Remove unused resources
testing/
├── infra/                        # Testinfra verification for EC2/Nodes
│   └── test_nodes.py
├── smoke/                        # Requests-based endpoint verification
│   └── test_endpoints.py
├── security/                     # Trivy / Checkov scan reports
└── quality/                      # SonarQube metric exports
```

### 🛠️ Bootstrapping the Lifecycle & Quality Structure
Run the following command to initialize the automation scripts and testing framework:
```bash
mkdir -p scripts testing/{infra,smoke,security,quality} && \
touch scripts/{build-and-push,deploy,aws-auth,cleanup}.sh && \
chmod +x scripts/*.sh && \
touch testing/infra/test_nodes.py && \
touch testing/smoke/test_endpoints.py
```

---

## 🏛️ System Decision Record (SDR): OS Selection
**Recommendation: Amazon Linux 2023 (AL2023)**

For this enterprise microservices project, **Amazon Linux 2023** is the preferred distribution over Ubuntu for the following reasons:
1.  **AWS Optimization:** AL2023 includes pre-installed AWS tools (CLI, SSM, CloudWatch Agent) and an optimized kernel for EC2, resulting in **15-20% faster boot times** during EKS auto-scaling.
2.  **Security Baseline:** It comes pre-hardened with SELinux in permissive mode by default and a minimal package set to reduce the attack surface.
3.  **Support Lifecycle:** Direct integration with AWS Support and a predictable 5-year support window specifically for AWS infrastructure.
4.  **License:** No additional costs for ESM/Pro patches, unlike Ubuntu for long-term production use.

---

## 🖥️ EC2 Instance Topology & Resource Allocation
To ensure high-availability and build performance, we utilize the following compute distribution:

### 1. Compute Distribution (Master vs. Slaves)
| Role | Count | Instance Type | vCPU / RAM | Role Detail |
| :--- | :---: | :--- | :--- | :--- |
| **Jenkins Master** | 1 | `t3.large` | 2 / 8GB | Orchestration & Global Config Controller |
| **EKS Worker Nodes** | 3 | `t3.medium` | 2 / 4GB | Application Hosting (Legacy EC2 Mode) |
| **EKS Fargate** | N/A | Serverless | Pod-based | Cost-optimized, zero-management compute |
| **SonarQube Server** | 1 | `t2.medium` | 2 / 4GB | Static Code Analysis (External Node) |

### 2. Architectural Hierarchy
*   **Jenkins Controller:** Functions as the **Master node**. It manages the pipeline state, credentials, and plugin ecosystem.
*   **EKS Node Group:** Functions as the **Slave/Worker nodes**. Kubernetes schedules microservice pods here. These nodes also act as "Ephemeral Build Agents" for Docker image packaging.
*   **AWS Managed Master:** The Kubernetes Control Plane is managed by AWS EKS. We do not provision EC2s for the K8s master; AWS ensures its 99.95% availability.
*   **Fargate Profiles:** Allows running pods without managing EC2 instances. Pods are billed per vCPU/RAM per second.

### 3. High Availability & Persistence
*   **Multi-AZ Strategy:** The 3 Worker Nodes are distributed across `us-east-1a`, `us-east-1b`, and `us-east-1c`. This ensures that even if an entire AWS Data Center fails, 66% of your application capacity remains online.
*   **DNS Resolution (Route53):** Provides global traffic routing and failover between regions using health checks.
*   **Storage (EBS/EFS):** EC2 nodes use GP3 EBS. Fargate pods utilize **Amazon EFS** for cross-node persistent storage.
*   **Database Resilience:** The RDS instance uses **Multi-AZ Replication**, providing a synchronous standby for automatic failover.

---

## Deployment Flow Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1: PRE-FLIGHT                          │
│  AWS Credentials → Tool Versions → State Backend Setup         │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│              PHASE 2: INFRASTRUCTURE (Terraform)                │
│  VPC → ECR → RDS → EKS → ALB → WAF → Route53 → Monitoring       │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│           PHASE 3: CONFIGURATION (Ansible)                      │
│  SSH Wait → Install Java → Maven → Docker → kubectl → AWS CLI  │
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

---

## Tool Chain Integration Matrix

| Phase    | Tool               | Input                            | Output                             | Next Phase Uses              |
| -------- | ------------------ | -------------------------------- | ---------------------------------- | ---------------------------- |
| Infra    | Terraform          | `backend.tf`, `terraform.tfvars` | ECR URLs, RDS Endpoint, EKS Config | Infracost, Ansible, Maven    |
| Cost     | Infracost          | `tfplan.json`                    | Cost Breakdown/Diff                | Budget Approval              |
| CI/CD    | Jenkins            | `Jenkinsfile`, Git Source        | Automated Artifacts/Deploys        | Continuous Delivery          |
| Quality  | SonarQube          | Maven Source                     | Quality Gate Results               | Security/Vulnerability Check |
| Testing  | JUnit/Mockito      | Java Source                      | Test Reports (XML)                 | Build/Package Stage          |
| Security | Trivy / Checkov    | Docker Images / IaC              | Vulnerability Reports              | Registry Management          |
| Firewall | AWS WAF            | ALB Traffic                      | Blocked/Allowed Requests          | Security Auditing           |
| DNS      | Route53            | Domain Name, ALB DNS             | Alias Records, Health Checks      | End-User Access             |
| Compute  | EKS Fargate        | Pod Resource Requirements        | Elastic, Serverless Runtime       | Scaling / Cost Mgmt         |
| Stress   | Apache JMeter      | User Scenarios                   | Performance Baseline               | SRE Scaling Policy           |
| Chaos    | AWS FIS / Litmus   | EKS Pods/Nodes                   | Resilience Report                  | DR Strategy                  |
| Config   | Ansible            | EC2 IPs from Terraform           | Configured nodes with tools        | Pytest, Maven, Docker        |
| Verify   | Pytest (Testinfra) | EC2 IPs                          | Node Configuration Report          | Production Readiness         |
| Build    | Maven              | Source code, `pom.xml`           | JAR files                          | Docker                       |
| Package  | Docker             | JARs, `Dockerfile`               | Container images                   | ECR                          |
| Deploy   | kubectl            | K8s manifests, ECR images        | Running pods                       | Monitoring                   |
| Smoke    | Pytest (Requests)  | Load Balancer DNS                | Health/API Verification            | User Traffic                 |
| Monitor  | Prometheus         | Pod metrics                      | Dashboards / Alerts                | Operations                   |

---

## PHASE 1: Pre-Flight Essentials

### 1.1 Cloud Identity Verification

- [x] **Verify AWS CLI credentials**
  ```bash
  aws sts get-caller-identity
  ```
  **Current Identity:** `arn:aws:iam::365269738775:root`

- [x] **Verify active AWS region**
  ```bash
  aws configure get region
  ```
  **Result:** `us-east-1`

### 1.2 SSH Key Strategy
*   **Automation:** The Terraform configuration automatically manages the SSH key pair (`spms-dev`) for secure node access.
*   **Action Required:** Ensure `terraform/environments/dev/spms-dev.pem` has `0400` permissions after provisioning.

### 1.3 Tool Version Verification

- [ ] **Check Terraform version** (`v1.6.0+`)
- [ ] **Check Ansible version** (`core 2.14.0+`)
- [ ] **Check kubectl version** (`v1.29.0+`)
- [ ] **Check Java version** (`OpenJDK 21`)
- [ ] **Check Maven version** (`3.9.x`)
- [ ] **Check Docker version** (`24.x.x`)

### 1.4 State Backend Preparation
A reliable "Source of Truth" for Terraform is critical.

- [x] **S3 Bucket (Storage Layer)**: `petclinic-terraform-state-17a538b3` (Region: `us-east-1`)
- [x] **Versioning**: Enabled on bucket.
- [x] **Locking**: Native S3 locking (`use_lockfile = true`) configured in `backend.tf`.

---

## PHASE 2: Infrastructure Provisioning (Terraform)

### 2.1 Deployment Order
`Networking → ECR → RDS → EKS → ALB → WAF → Route53 → Monitoring`

### 2.2 Provisioning Commands
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply -auto-approve
```

### 2.3 Current Infrastructure Endpoints (Live)
- **ALB DNS:** `petclinic-dev-alb-1087603039.us-east-1.elb.amazonaws.com`
- **RDS Endpoint:** `petclinic-dev-db.c4vose4cw6rj.us-east-1.rds.amazonaws.com:3306`
- **EKS Cluster:** `petclinic-dev-cluster`
- **Account ID:** `365269738775`

---

## PHASE 3: Configuration Management (Ansible)

### 3.1 Run Site Playbook
```bash
cd ansible
ansible-playbook playbooks/site.yml
```

### 3.2 Verification
- [ ] **Java 21** installed on all nodes.
- [ ] **Docker** daemon active.
- [ ] **CloudWatch Agent** pushing logs.

---

## PHASE 4: Build & Deployed (Jenkins)

### 4.1 Execute Jenkinsfile Pipeline
1. Build Maven Artifacts (`./mvnw clean install`)
2. Build & Tag Docker Images (`docker build`)
3. Security Scan (`trivy image`)
4. Push to Amazon ECR (`docker push`)
5. Deploy to EKS (`helm upgrade --install`)

---

## PHASE 5: Validation & Maintenance

### 5.1 Final Health Checks
- [ ] **Actuator Health**: `curl http://${ALB_DNS}/actuator/health` returns `UP`.
- [ ] **Database Connectivity**: Microservices successfully connect to RDS.
- [ ] **HPA Scaling**: Pods scale under stress test.

---

## Cleanup Procedure
```bash
# Full resource teardown
cd terraform/environments/dev
terraform destroy -auto-approve
```

---
*Generated & Audited by Antigravity AI - Principal DevSecOps Persona*
