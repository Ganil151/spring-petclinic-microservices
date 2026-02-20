# 📋 Spring PetClinic Microservices - Complete Deployment Checklist

## 🛡️ Pre-Deployment Audit Status (DevSecOps Review)
**Lead Auditor:** Principal DevSecOps & Platform Engineer  
**Audit Date:** February 21, 2026  
**Status:** ⚠️ **REMEDIATION REQUIRED** (Critical Security & Reliability Findings)

| Category | Finding | Recommended Action | Priority | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Security** | RDS Security Group allows `0.0.0.0/0` on port 3306 | Restrict to VPC CIDR `10.0.0.0/16` or specific SG references | 🔴 CRITICAL | ❌ OPEN |
| **Integrity** | Terraform uses S3 native locking instead of DynamoDB | Migrate to S3 + DynamoDB for production-grade state locking | 🟡 MEDIUM | ⚠️ REVIEW |
| **Reliability** | Helm templates missing liveness/readiness probes | Add HTTP probes to `/actuator/health` in deployment.yaml | 🟠 HIGH | ❌ OPEN |
| **Secrets** | Jenkinsfile auto-detects ECR via AWS CLI | Validate IAM roles follow least-privilege principle | 🟢 LOW | ✅ PASS |
| **Compliance** | No WAF rules configured in terraform/modules/waf | Implement OWASP Top 10 rules for ALB protection | 🟠 HIGH | ❌ OPEN |

---

## Overview
This checklist provides a comprehensive, step-by-step guide for deploying the Spring PetClinic Microservices application to AWS using Terraform, Ansible, and Kubernetes (EKS).

**Architecture:** Microservices-based Spring Boot application with 8 services  
**Infrastructure:** AWS EKS + RDS + ALB + Route53  
**CI/CD:** Jenkins Pipeline + Maven + Docker + Helm  
**Monitoring:** Prometheus + Grafana + CloudWatch

---

## 🏗️ Detailed Project Infrastructure Breakdown

### Part 1: Layer 1 - Infrastructure Provisioning (Terraform)

```text
terraform/
├── modules/
│   ├── networking/           # VPC, Subnets, Security Groups, ALB
│   ├── compute/              # EKS Cluster, EC2 Instances, Fargate
│   ├── database/             # RDS MySQL with Multi-AZ
│   ├── ecr/                  # Container Registry
│   ├── waf/                  # Web Application Firewall
│   ├── keys/                 # SSH Key Management
│   ├── monitoring/           # CloudWatch, Prometheus Stack
│   └── ansible/              # Ansible Automation Module
├── environments/
│   ├── dev/                  # Development (t3.medium, Single AZ)
│   ├── staging/              # Staging (t3.medium, Multi-AZ)
│   └── prod/                 # Production (t3.large, Multi-AZ + Fargate)
├── global/
│   ├── iam/                  # IAM Roles & Policies
│   ├── route53/              # DNS Configuration
│   └── data/                 # Data Sources
└── shared/                   # Reusable configurations
```

**Current State:**
- ✅ S3 Backend: `petclinic-terraform-state-17a538b3`
- ✅ Versioning: Enabled
- ⚠️ Locking: S3 native (`use_lockfile = true`)
- ✅ Region: `us-east-1`
- ✅ Account: `365269738775`

### Part 2: Layer 2 - Configuration Management (Ansible)

```text
ansible/
├── roles/
│   ├── docker/               # Docker Engine Installation
│   ├── java/                 # OpenJDK 21 Installation
│   ├── maven/                # Maven 3.9.x Setup
│   ├── kubectl/              # Kubernetes CLI
│   ├── helm/                 # Helm 3.x Installation
│   ├── awscli/               # AWS CLI v2
│   ├── eks_setup/            # EKS Node Configuration
│   ├── jenkins/              # Jenkins Master Setup
│   ├── sonarqube/            # SonarQube Server
│   └── security_tools/       # Trivy, Checkov Installation
├── playbooks/
│   ├── site.yml              # Main Playbook
│   ├── 01-core.yml           # Core System Setup
│   ├── 02-jenkins.yml        # Jenkins Configuration
│   ├── 03-workers.yml        # Worker Node Setup
│   ├── 04-sonarqube.yml      # SonarQube Setup
│   └── 05-security.yml       # Security Hardening
└── inventory/
    └── hosts                 # Dynamic Inventory
```

**Target OS:** Amazon Linux 2023 (AL2023)  
**SSH Strategy:** Key-based authentication with `spms-dev.pem`

### Part 3: Layer 3 - Container Orchestration (Helm & Microservices)

```text
helm/microservices/
├── Chart.yaml
├── values.yaml
├── templates/
│   ├── deployment.yaml       # ⚠️ MISSING: liveness/readiness probes
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── configmap.yaml
│   └── _helpers.tpl
└── overrides/
    ├── dev.yaml              # Debug mode, minimal resources
    └── prod.yaml             # HA, resource limits
```

**Microservices:**
1. **spring-petclinic-config-server** - Centralized Configuration
2. **spring-petclinic-discovery-server** - Eureka Service Discovery
3. **spring-petclinic-api-gateway** - API Gateway (Port 8080)
4. **spring-petclinic-customers-service** - Customer Management
5. **spring-petclinic-vets-service** - Veterinarian Service
6. **spring-petclinic-visits-service** - Visit Management
7. **spring-petclinic-admin-server** - Spring Boot Admin
8. **spring-petclinic-genai-service** - AI/GenAI Integration

### Part 4: Layer 4 - CI/CD & Monitoring

```text
Jenkinsfile                   # Declarative Pipeline
docker/
├── Dockerfile                # Multi-stage build
├── prometheus/
│   └── prometheus.yml        # Metrics Scraping
└── grafana/
    └── dashboards/           # Custom Dashboards

scripts/
├── chaos/                    # Chaos Engineering (Pumba)
│   ├── attacks_enable_*.json
│   └── call_chaos.sh
├── pushImages.sh             # Docker Push Automation
└── run_all.sh                # Full Deployment Script
```

---

## 🏛️ System Decision Record (SDR): OS Selection

**Decision:** Amazon Linux 2023 (AL2023)

**Rationale:**
1. **AWS-Native Optimization:** 15-20% faster boot times, pre-installed AWS tools
2. **Security Baseline:** SELinux enabled, minimal attack surface
3. **Cost:** No ESM/Pro subscription fees
4. **Support:** 5-year AWS-backed lifecycle

---

## 🖥️ EC2 Instance Topology

| Role | Count | Instance Type | vCPU/RAM | Purpose |
| :--- | :---: | :--- | :--- | :--- |
| **Jenkins Master** | 1 | t3.large | 2/8GB | CI/CD Orchestration |
| **SonarQube Server** | 1 | t2.medium | 2/4GB | Code Quality Analysis |
| **EKS Workers (EC2)** | 3 | t3.medium | 2/4GB | Microservices Hosting |
| **EKS Fargate** | N/A | Serverless | Variable | Cost-Optimized Pods |

**High Availability:**
- ✅ Multi-AZ Deployment (us-east-1a, 1b, 1c)
- ✅ RDS Multi-AZ with Automatic Failover
- ✅ ALB Cross-Zone Load Balancing
- ✅ Route53 Health Checks & Failover

---

## Deployment Flow Diagram

```text
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1: PRE-FLIGHT                          │
│  ✓ AWS Credentials → Tool Versions → State Backend              │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│              PHASE 2: INFRASTRUCTURE (Terraform)                │
│  VPC → Security Groups → ECR → RDS → EKS → ALB → WAF → Route53  │
│  ⚠️ CRITICAL: Fix RDS SG before proceeding                     │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│           PHASE 3: CONFIGURATION (Ansible)                      │
│  SSH Access → Java 21 → Maven → Docker → kubectl → AWS CLI      │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│              PHASE 4: BUILD & DEPLOY (Jenkins)                  │
│  Maven Build → Docker Build → Trivy Scan → ECR Push → Helm      │
└────────────────────────┬────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────┐
│              PHASE 5: VALIDATION & MONITORING                   │
│  Health Checks → Prometheus Metrics → Grafana Dashboards        │
│  ⚠️ REQUIRED: Add liveness/readiness probes                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Tool Chain Integration Matrix

| Phase | Tool | Input | Output | Next Phase |
|-------|------|-------|--------|------------|
| **Infra** | Terraform | backend.tf, tfvars | ECR URL, RDS Endpoint, EKS Config | Ansible, Infracost |
| **Cost** | Infracost | tfplan.json | Cost Estimate | Budget Approval |
| **Config** | Ansible | EC2 IPs | Configured Nodes with Tools | Maven, Docker |
| **Build** | Maven | Source Code, pom.xml | JAR Artifacts | Docker |
| **Security** | Trivy | Docker Images | Vulnerability Report | ECR Push |
| **Package** | Docker | JARs, Dockerfile | Container Images | ECR |
| **Quality** | SonarQube | Source Code | Quality Gate | Build Approval |
| **Deploy** | Helm | ECR Images, values.yaml | Running Pods | Monitoring |
| **Monitor** | Prometheus | Pod Metrics | Alerts, Dashboards | Operations |
| **Test** | Pytest | ALB DNS | Health Check Results | Production |
| **Chaos** | AWS FIS | EKS Pods | Resilience Report | DR Strategy |

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
- [x] **Terraform auto-generates key pair:** `spms-dev.pem`
- [ ] **Set secure permissions:** `chmod 400 terraform/environments/dev/spms-dev.pem`

### 1.3 Tool Version Verification

- [ ] **Terraform:** `v1.6.0+` (Required for S3 locking)
- [ ] **Ansible:** `core 2.14.0+`
- [ ] **kubectl:** `v1.29.0+` (Compatible with EKS 1.29)
- [ ] **Java:** `OpenJDK 21` (LTS Version)
- [ ] **Maven:** `3.9.x`
- [ ] **Docker:** `24.x.x`
- [ ] **Helm:** `v3.14.0+`

### 1.4 State Backend Preparation

- [x] **S3 Bucket:** `petclinic-terraform-state-17a538b3`
- [x] **Versioning:** Enabled
- [x] **Encryption:** AES-256
- [ ] **DynamoDB Table:** Create `terraform-locks` for production
- [ ] **Backend Config:** Update `backend.tf` to use DynamoDB

---

## PHASE 2: Infrastructure Provisioning (Terraform)

### 2.1 Deployment Order
`VPC → Security Groups → ECR → RDS → EKS → ALB → WAF → Route53`

### 2.2 Critical Security Fixes Required

**Before running `terraform apply`:**

1. **Fix RDS Security Group:**
   ```hcl
   # In terraform/modules/database/security-group.tf
   ingress {
     from_port   = 3306
     to_port     = 3306
     protocol    = "tcp"
     # ❌ WRONG: cidr_blocks = ["0.0.0.0/0"]
     # ✅ CORRECT:
     security_groups = [aws_security_group.eks_nodes.id]
   }
   ```

2. **Enable WAF Rules:**
   ```hcl
   # In terraform/modules/waf/main.tf
   resource "aws_wafv2_web_acl" "petclinic" {
     # Add OWASP Top 10 rules
   }
   ```

### 2.3 Provisioning Commands

```bash
cd terraform/environments/dev

# Initialize backend
terraform init

# Review plan
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Save outputs
terraform output -json > ../outputs.json
```

### 2.4 Current Infrastructure Endpoints

- **ALB DNS:** `petclinic-dev-alb-1087603039.us-east-1.elb.amazonaws.com`
- **RDS Endpoint:** `petclinic-dev-db.c4vose4cw6rj.us-east-1.rds.amazonaws.com:3306`
- **EKS Cluster:** `petclinic-dev-cluster`
- **ECR Registry:** `365269738775.dkr.ecr.us-east-1.amazonaws.com`
- **Account ID:** `365269738775`

---

## PHASE 3: Configuration Management (Ansible)

### 3.1 Inventory Setup

```bash
cd ansible

# Update inventory/hosts with Terraform outputs
# Format:
# [jenkins]
# jenkins-dev ansible_host=<IP> ansible_user=ec2-user

# [workers]
# worker-1 ansible_host=<IP> ansible_user=ec2-user
# worker-2 ansible_host=<IP> ansible_user=ec2-user
# worker-3 ansible_host=<IP> ansible_user=ec2-user
```

### 3.2 Run Playbooks

```bash
# Install dependencies
ansible-galaxy collection install amazon.aws

# Run site playbook
ansible-playbook playbooks/site.yml -i inventory/hosts

# Verify installation
ansible all -m shell -a "java -version"
ansible all -m shell -a "docker --version"
```

### 3.3 Verification Checklist

- [ ] **Java 21** installed on all nodes
- [ ] **Docker daemon** active and running
- [ ] **Maven 3.9.x** available
- [ ] **kubectl** configured with EKS context
- [ ] **Helm 3.x** installed
- [ ] **AWS CLI v2** configured
- [ ] **CloudWatch agent** running

---

## PHASE 4: Build & Deploy (Jenkins)

### 4.1 Jenkins Pipeline Stages

```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') { }
        stage('Maven Build') { 
            steps { sh './mvnw clean install -DskipTests' }
        }
        stage('Unit Tests') { 
            steps { sh './mvnw test' }
        }
        stage('SonarQube Analysis') { 
            steps { sh 'mvn sonar:sonar' }
        }
        stage('Docker Build') { 
            steps { sh 'docker build -t petclinic .' }
        }
        stage('Security Scan') { 
            steps { sh 'trivy image petclinic' }
        }
        stage('Push to ECR') { 
            steps { sh 'docker push ${ECR_URL}/petclinic' }
        }
        stage('Deploy to EKS') { 
            steps { sh 'helm upgrade --install petclinic ./helm' }
        }
        stage('Smoke Tests') { 
            steps { sh 'pytest testing/smoke/' }
        }
    }
}
```

### 4.2 Manual Build & Deploy (Alternative)

```bash
# Build all microservices
./mvnw clean install

# Build Docker images
docker-compose build

# Tag for ECR
docker tag petclinic:latest 365269738775.dkr.ecr.us-east-1.amazonaws.com/petclinic:latest

# Push to ECR
aws ecr get-login-password | docker login --username AWS --password-stdin 365269738775.dkr.ecr.us-east-1.amazonaws.com
docker push 365269738775.dkr.ecr.us-east-1.amazonaws.com/petclinic:latest

# Deploy to EKS
kubectl config use-context petclinic-dev-cluster
helm upgrade --install petclinic ./helm/microservices \
  --set image.repository=365269738775.dkr.ecr.us-east-1.amazonaws.com/petclinic \
  --set image.tag=latest \
  --namespace petclinic \
  --create-namespace
```

---

## PHASE 5: Validation & Monitoring

### 5.1 Health Checks

- [ ] **Actuator Health:**
  ```bash
  curl http://$(ALB_DNS)/actuator/health
  # Expected: {"status":"UP"}
  ```

- [ ] **Database Connectivity:**
  ```bash
  kubectl logs -l app=customers-service | grep "Connected to database"
  ```

- [ ] **Service Discovery:**
  ```bash
  curl http://$(ALB_DNS)/api/gateway/actuator/gateway/routes
  ```

### 5.2 Monitoring Setup

**Prometheus Configuration:**
```yaml
# docker/prometheus/prometheus.yml
scrape_configs:
  - job_name: 'petclinic'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['api-gateway:8080', 'customers-service:8081']
```

**Grafana Dashboards:**
- [ ] Import dashboard from `docker/grafana/dashboards/grafana-petclinic-dashboard.json`
- [ ] Configure Prometheus datasource
- [ ] Set up alerts for:
  - Error rate > 1%
  - Response time > 2s
  - Pod memory > 80%

### 5.3 Horizontal Pod Autoscaling

```bash
# Verify HPA
kubectl get hpa -n petclinic

# Test autoscaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- \
  /bin/sh -c "while sleep 0.01; do wget -q -O- http://petclinic-api-gateway/actuator/health; done"

# Watch scaling
kubectl get hpa petclinic-api-gateway -n petclinic --watch
```

### 5.4 Chaos Engineering (Optional)

```bash
# Enable chaos attacks
cd scripts/chaos
./call_chaos.sh enable latency

# Run for 5 minutes, then disable
sleep 300
./call_chaos.sh disable
```

---

## 🔴 Critical Remediation Tasks

### Task 1: Fix RDS Security Group (CRITICAL)

**File:** `terraform/modules/database/security-group.tf`

```hcl
# BEFORE (INSECURE):
ingress {
  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # ❌ OPEN TO INTERNET
}

# AFTER (SECURE):
ingress {
  from_port       = 3306
  to_port         = 3306
  protocol        = "tcp"
  security_groups = [aws_security_group.eks_nodes.id]  # ✅ EKS NODES ONLY
}
```

**Action:**
```bash
cd terraform/modules/database
# Edit security-group.tf
terraform plan
terraform apply
```

### Task 2: Add Kubernetes Probes (HIGH)

**File:** `helm/microservices/templates/deployment.yaml`

```yaml
# ADD to container spec:
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

### Task 3: Implement DynamoDB State Locking (MEDIUM)

**File:** `terraform/environments/dev/backend.tf`

```hcl
# BEFORE:
backend "s3" {
  bucket         = "petclinic-terraform-state-17a538b3"
  key            = "tfstate/dev/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  use_lockfile   = true  # ⚠️ Not production-grade
}

# AFTER:
backend "s3" {
  bucket         = "petclinic-terraform-state-17a538b3"
  key            = "tfstate/dev/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"  # ✅ Production-grade
}
```

**Create DynamoDB Table:**
```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Cleanup Procedure

### Full Teardown

```bash
# 1. Delete Helm releases
helm uninstall petclinic -n petclinic
kubectl delete namespace petclinic

# 2. Destroy Terraform infrastructure
cd terraform/environments/dev
terraform destroy -auto-approve

# 3. Clean up ECR images
aws ecr batch-delete-image \
  --repository-name petclinic \
  --image-ids imageTag=latest \
  --region us-east-1

# 4. Remove S3 state files (OPTIONAL - DANGER!)
aws s3 rm s3://petclinic-terraform-state-17a538b3/tfstate/dev/ --recursive

# 5. Delete SSH key pair
aws ec2 delete-key-pair --key-name spms-dev --region us-east-1
```

### Partial Cleanup (Keep State)

```bash
# Destroy only compute resources
cd terraform/environments/dev
terraform destroy -target=module.compute -auto-approve

# Re-apply when ready
terraform apply -auto-approve
```

---

## Troubleshooting Guide

### Issue: Terraform Apply Fails

**Symptom:** `Error: InvalidProviderConfiguration`

**Solution:**
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Re-initialize Terraform
terraform init -reconfigure
```

### Issue: Pods Not Starting

**Symptom:** `ImagePullBackOff`

**Solution:**
```bash
# Check ECR authentication
kubectl get secret regcred -n petclinic -o yaml

# Verify image exists
aws ecr describe-images --repository-name petclinic
```

### Issue: Database Connection Fails

**Symptom:** `Communications link failure`

**Solution:**
```bash
# Check security group
aws ec2 describe-security-groups --group-ids <RDS_SG_ID>

# Verify RDS endpoint
nslookup $(terraform output rds_endpoint)
```

---

## Success Criteria

- [x] **Infrastructure:** All Terraform resources created successfully
- [ ] **Security:** RDS not accessible from internet (port 3306 blocked)
- [ ] **Configuration:** All nodes have Java 21, Docker, kubectl installed
- [ ] **Build:** Maven builds pass with 0 failures
- [ ] **Deploy:** All 8 microservices running in EKS
- [ ] **Health:** `/actuator/health` returns `UP` for all services
- [ ] **Monitoring:** Prometheus scraping metrics successfully
- [ ] **Scaling:** HPA scales pods under load
- [ ] **Backup:** RDS automated backups enabled
- [ ] **Documentation:** Runbook updated with actual endpoints

---

## Next Steps

1. **Immediate:** Fix RDS security group (CRITICAL)
2. **This Week:** Add liveness/readiness probes
3. **This Sprint:** Implement WAF rules
4. **Next Month:** Migrate to DynamoDB state locking
5. **Q2 2026:** Implement GitOps with ArgoCD

