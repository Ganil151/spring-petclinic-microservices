# Spring PetClinic Microservices - Complete Deployment Checklist

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
│   ├── vpc/                              # Networking Foundation (L3/L4)
│   │   ├── main.tf                       # VPC, Subnets, IGW, NATGW, Route Tables
│   │   ├── variables.tf                  # CIDR ranges, AZ distribution logic
│   │   ├── outputs.tf                    # Subnet IDs (EKS/RDS/ALB discovery)
│   │   └── README.md                     # Documentation on EKS-specific tagging
│   ├── eks/                              # Container Orchestration (Control Plane)
│   │   ├── main.tf                       # EKS Cluster + Managed Node Groups (MNG)
│   │   ├── addons.tf                     # Amazon VPC CNI, CoreDNS, Kube-Proxy
│   │   ├── irsa.tf                       # IAM Roles for Service Accounts (OIDC)
│   │   ├── variables.tf                  # Cluster version (v1.31), Instance types
│   │   ├── outputs.tf                    # Cluster CA, Endpoint, Auth token
│   │   └── README.md
│   ├── rds/                              # Persistence Layer (Managed MySQL)
│   │   ├── main.tf                       # Multi-AZ RDS Instance, Subnet Groups
│   │   ├── security-group.tf             # DB-specific ingress (Post 3306)
│   │   ├── variables.tf                  # Encryption, Storage, Credentials
│   │   ├── outputs.tf                    # RDS Endpoint, VPC Security Group ID
│   │   └── README.md
│   ├── alb/                              # Traffic Ingress (L7 Load Balancing)
│   │   ├── main.tf                       # ALB, Target Groups (TG), Listeners (HTTPS)
│   │   ├── variables.tf                  # Subnet IDs, SG IDs, ACM Certs
│   │   └── outputs.tf                    # LB DNS Name, Zone ID (Route53 Alias)
│   ├── ecr/                              # Container Artifact Storage
│   │   ├── main.tf                       # Private Repos for each Microservice
│   │   ├── variables.tf                  # Image scanning, Lifecycle policies
│   │   └── outputs.tf                    # Registry URLs for CI/CD pipelines
│   ├── ec2/                              # Compute Layer (DevOps Tooling)
│   │   ├── main.tf                       # Standalone nodes (Jenkins, SonarQube)
│   │   ├── variables.tf                  # Instance types, IAM profiles
│   │   ├── outputs.tf                    # Public/Private IPs
│   │   └── README.md                     # Topology allocation details
│   ├── waf/                              # Perimeter Security (Web Application Firewall)
│   │   ├── main.tf                       # Web ACLs: SQLi, XSS, Bot Control
│   │   ├── variables.tf                  # Scope (Regional), Rule priorities
│   │   └── outputs.tf                    # WAF Web ACL ARN for ALB attachment
│   └── monitoring/                       # Observability (Health & Performance)
│       ├── main.tf                       # CloudWatch Dashboards, Log Groups, Alarms
│       └── variables.tf
├── environments/                         # Environment-Specific Workspaces
│   ├── dev/                              # Sandbox: Cost-Optimized settings
│   │   ├── main.tf                       # Composes modules (Low-Scale)
│   │   ├── backend.tf                    # Remote State: s3://.../tfstate/dev/
│   │   ├── providers.tf                  # Region + Default Tags (CreatedBy: Terraform)
│   │   ├── terraform.tfvars              # Dev params (Single NAT, t3.small)
│   │   ├── variables.tf                  # Environment specific variables
│   │   └── versions.tf                   # Terraform 1.6+ and AWS Provider 6.0+
│   ├── staging/                          # Pre-Prod: Full Scale Mirror
│   │   ├── main.tf                       # Composes modules (Prod-Scale)
│   │   ├── backend.tf                    # Remote State: s3://.../tfstate/staging/
│   │   └── ...
│   └── prod/                             # Production: Mission Critical
│       ├── main.tf                       # Strict security & HA configuration
│       ├── backend.tf                    # Remote State: s3://.../tfstate/prod/
│       └── security.tf                   # Prod-specific hardening (WAF, Shield)
├── global/                               # Shared Multi-Env Resources
│   ├── route53/
│   │   └── main.tf                       # Public Hosted Zones, Shared Records
│   └── iam/
│       └── main.tf                       # Cross-account roles, Admin break-glass
├── scripts/
│   ├── deploy.sh                         # CI/CD wrapper for TF Apply
│   └── validate.sh                       # Pre-commit: fmt, validate, checkov
└── README.md                             # High-level architecture & SDR Link
```

### 🛠️ Bootstrapping the Terraform Structure
Run the following command to initialize the directory structure and placeholder files:
```bash
mkdir -p terraform/modules/{vpc,eks,rds,alb,ecr,waf,monitoring} && \
mkdir -p terraform/environments/{dev,staging,prod} && \
mkdir -p terraform/global/{route53,iam} && \
mkdir -p terraform/scripts && \
touch terraform/modules/vpc/{main,variables,outputs}.tf && \
touch terraform/modules/eks/{main,variables,addons,irsa,outputs}.tf && \
touch terraform/modules/rds/{main,variables,outputs,security-group}.tf && \
touch terraform/modules/alb/{main,variables,outputs}.tf && \
touch terraform/modules/ecr/{main,variables,outputs}.tf && \
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
│   ├── dev.ini                   # Target IPs for Development EKS nodes
│   └── group_vars/               # Global vars (e.g., JAVA_HOME, DOCKER_VERSION)
├── roles/                        # Self-contained "Configuration Blocks"
│   ├── security_hardening/       # SELinux config, SSH hardening, Fail2Ban
│   └── install_tools/            # The core DevOps toolbelt
│       ├── tasks/java.yml        # Logic for installing OpenJDK 21
│       ├── tasks/docker.yml      # Container engine setup & group permissions
│       ├── tasks/kubernetes.yml  # Master/Worker node CLI tools (kubectl)
│       └── vars/main.yml         # Role-specific constants and download URLs
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

## �🏛️ System Decision Record (SDR): OS Selection
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
| **EKS Worker Nodes (Slaves)** | 3 | `t3.medium` | 2 / 4GB | Application Hosting (Legacy EC2 Mode) |
| **EKS Fargate (Serverless)** | N/A | Serverless | Pod-based | Cost-optimized, zero-management compute for microservices |
| **SonarQube Server** | 1 | `t2.medium` | 2 / 4GB | Static Code Analysis (External Node) |

### 2. Architectural Hierarchy
*   **Jenkins Controller:** Functions as the **Master node**. It manages the pipeline state, credentials, and plugin ecosystem.
*   **EKS Node Group:** Functions as the **Slave/Worker nodes**. Kubernetes schedules microservice pods here. These nodes also act as "Ephemeral Build Agents" for Docker image packaging.
*   **AWS Managed Master:** The Kubernetes Control Plane is managed by AWS EKS. We do not provision EC2s for the K8s master; AWS ensures its 99.95% availability.
*   **Fargate Profiles:** Allows running pods without managing EC2 instances. Pods are billed per vCPU/RAM per second.

### 3. High Availability & Persistence
*   **Multi-AZ Strategy:** The 3 Worker Nodes (or Fargate Pods) are distributed across `us-east-1a`, `us-east-1b`, and `us-east-1c`. This ensures that even if an entire AWS Data Center fails, 66% of your application capacity remains online.
*   **DNS Resolution (Route53):** Provides global traffic routing and failover between regions using health checks.
*   **Storage (EBS/EFS):** EC2 nodes use GP3 EBS. Fargate pods utilize **Amazon EFS** for cross-node persistent storage.
*   **Database Resilience:** The RDS instance uses **Multi-AZ Replication**, providing a synchronous standby in a different subnet for automatic failover.

---

## Deployment Flow Diagram

```
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

- [ ] **Verify AWS CLI credentials**
  ```bash
  aws sts get-caller-identity
  ```
  **Expected Output:**
  ```json
  {
    "UserId": "AIDAXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/devops"
  }
  ```
  **Troubleshooting:** If credentials fail, run `aws configure` or check `~/.aws/credentials`

- [ ] **Verify active AWS region**
  ```bash
  aws configure get region
  ```
  **Expected Output:** `us-east-1`
  **Troubleshooting:** Set region with `export AWS_DEFAULT_REGION=us-east-1`

- [ ] **Test AWS permissions**
  ```bash
  aws ec2 describe-vpcs --max-items 1
  aws eks list-clusters
  aws rds describe-db-instances --max-records 1
  ```
  **Troubleshooting:** If permission denied, verify IAM policies attached to your user/role

### 1.2 Tool Version Verification

- [ ] **Check Terraform version**
  ```bash
  cd /home/gsmash/Documents/spring-petclinic-microservices/terraform
  cat .terraform-version
  terraform version
  ```
  **Expected Output:** `Terraform v1.6.0` or higher
  **Troubleshooting:** Install from https://www.terraform.io/downloads

- [ ] **Check Ansible version**
  ```bash
  ansible --version
  ```
  **Expected Output:** `ansible [core 2.14.0]` or higher
  **Troubleshooting:** Install with `pip install ansible` or package manager

- [ ] **Check kubectl version**
  ```bash
  kubectl version --client
  ```
  **Expected Output:** `Client Version: v1.29.0`
  **Troubleshooting:** Install from https://kubernetes.io/docs/tasks/tools/

- [ ] **Check Java version**
  ```bash
  java -version
  ```
  **Expected Output:** `openjdk version "21.0.x"`
  **Troubleshooting:** Follow `/home/gsmash/Documents/spring-petclinic-microservices/JAVA21_MIGRATION.md`

- [ ] **Check Maven version**
  ```bash
  mvn -version
  ```
  **Expected Output:** `Apache Maven 3.9.x`
  **Troubleshooting:** Install from https://maven.apache.org/download.cgi

- [ ] **Check Docker version**
  ```bash
  docker --version
  docker ps
  ```
  **Expected Output:** `Docker version 24.x.x`
  **Troubleshooting:** Ensure Docker daemon is running with `sudo systemctl start docker`

### 1.3 State Backend Preparation: Procedural Deep-Dive
A reliable "Source of Truth" for Terraform is critical. This setup ensures **Consistency** (locking), **Durability** (versioning), and **Security** (encryption).

- [ ] **Step 1: Create S3 Bucket (Storage Layer)**
  *   **Logic:** Creates a globally unique container to store the `terraform.tfstate` binary.
  ```bash
  export RANDOM_SUFFIX=$(openssl rand -hex 4)
  export BUCKET_NAME="petclinic-terraform-state-${RANDOM_SUFFIX}"
  aws s3 mb s3://${BUCKET_NAME} --region us-east-1
  ```
  *   **Expected Outcome:** `make_bucket: petclinic-terraform-state-xxxx`
  *   **Troubleshooting:** If `BucketAlreadyExists`, change the suffix and try again. Bucket names are shared across all of AWS.

- [ ] **Step 2: Enable Versioning (Durability Layer)**
  *   **Logic:** Protects against accidental state corruption or manual deletion. Every `terraform apply` creates a new version of the state file.
  ```bash
  aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled
  ```
  *   **Verification:** `aws s3api get-bucket-versioning --bucket ${BUCKET_NAME}` should return `"Status": "Enabled"`.

- [ ] **Step 3: Enable Server-Side Encryption (Security Layer)**
  *   **Logic:** Ensures the state file (which may contain sensitive plan data) is encrypted at rest using AES-256.
  ```bash
  aws s3api put-bucket-encryption \
    --bucket ${BUCKET_NAME} \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
  ```

- [ ] **Step 4: Block Public Access (Hardening Layer)**
  *   **Logic:** Enforces a "Zero Trust" policy at the bucket level, preventing any accidental public exposure of the infrastructure state.
  ```bash
  aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
  ```

- [ ] **Step 5: Create DynamoDB Table (Locking Layer)**
  *   **Logic:** Prevents "State Corruption" by ensuring only one person can run `terraform apply` at a time. Terraform writes a `LockID` to this table before executing.
  ```bash
  aws dynamodb create-table \
    --table-name petclinic-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1
  ```
  *   **Verification:** `aws dynamodb describe-table --table-name petclinic-terraform-locks --query "Table.TableStatus"` (Expected: `ACTIVE`)

- [ ] **Step 6: Inject Configuration into Backend.tf**
  *   **Logic:** Connects the local Terraform code to the remote AWS resources created above.
  ```bash
  cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/environments/dev
  # Example configuration (ensure bucket name matches Step 1)
  cat > backend.tf << EOF
  terraform {
    backend "s3" {
      bucket         = "REPLACE_WITH_BUCKET_NAME"
      key            = "tfstate/dev/terraform.tfstate"
      region         = "us-east-1"
      dynamodb_table = "petclinic-terraform-locks"
      encrypt        = true
    }
  }
  EOF
  ```

- [ ] **Step 7: Migrate Local State to Remote Backend**
  *   **Logic:** After configuring the backend, you must "migrate" your existing local `terraform.tfstate` to the S3 bucket. Terraform will detect the change and prompt for migration.
  ```bash
  terraform init
  ```
  *   **Prompt:** When asked `Do you want to copy existing state to the new backend?`, type **yes**.
  *   **Verification:** Verify the file now exists in S3:
  ```bash
  aws s3 ls s3://REPLACE_WITH_BUCKET_NAME/tfstate/dev/
  ```
  *   **Cleanup:** Safely remove the local state files (optional but recommended for security):
  ```bash
  rm terraform.tfstate terraform.tfstate.backup
  ```

---

## PHASE 2: Infrastructure Provisioning (Terraform)

### 2.1 Terraform Module Dependency Order

```
1. networking (VPC, Subnets, NAT)
   ↓
2. ecr (Container Registries)
   ↓
3. rds (Database)
   ↓
4. eks (Kubernetes Cluster)
   ↓
5. alb (Load Balancer)
   ↓
6. waf (Web Application Firewall)
   ↓
7. route53 (DNS)
   ↓
8. monitoring (CloudWatch)
```

### 2.2 Initialize Terraform

- [ ] **Navigate to dev environment**
  ```bash
  cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/environments/dev
  ```

- [ ] **Initialize Terraform**
  ```bash
  terraform init
  ```
  **Expected Output:**
  ```
  Terraform has been successfully initialized!
  ```
  **Troubleshooting:** If backend error, verify S3 bucket and DynamoDB table exist

- [ ] **Validate configuration**
  ```bash
  terraform validate
  ```
  **Expected Output:** `Success! The configuration is valid.`

- [ ] **Format code**
  ```bash
  terraform fmt -recursive
  ```

### 2.2 Infrastructure Security Audit (Checkov)
- [ ] **Scan Terraform Code for Misconfigurations**
  *   **Logic:** Proactively identify security risks (e.g., unencrypted S3, open SG 0.0.0.0/0) before provisioning.
  ```bash
  pip install checkov
  checkov -d . --framework terraform
  ```
  *   **Expected Outcome:** 0 High/Critical Failures.

### 2.3 Configure Variables & Cost Estimation (Infracost)
- [ ] **Check Infrastructure Costs with Infracost**
  *   **Logic:** Before applying changes, calculate the monthly cost impact of the proposed infrastructure.
  ```bash
  # Generate plan JSON for Infracost
  terraform plan -out=tfplan.binary
  terraform show -json tfplan.binary > tfplan.json

  # Run Infracost breakdown
  infracost breakdown --path tfplan.json
  ```
  *   **Interviewer's Secret:** Mentioning that you use Infracost to **prevent "Bill Shock"** and include cost estimations in PR comments demonstrates true FinOps awareness.

- [ ] **Review terraform.tfvars**
  ```bash
  cat terraform.tfvars
  ```

- [ ] **Set sensitive variables**
  ```bash
  export TF_VAR_db_password=$(openssl rand -base64 32)
  export TF_VAR_openai_api_key="your-openai-key-or-demo"
  ```

- [ ] **Verify variables**
  ```bash
  terraform console
  > var.environment
  > var.vpc_cidr
  > exit
  ```

### 2.4 Deploy Networking Module

- [ ] **Plan networking resources**
  ```bash
  terraform plan -target=module.networking
  ```
  **Review:** VPC, 3 public subnets, 3 private subnets, 3 NAT gateways

- [ ] **Apply networking resources**
  ```bash
  terraform apply -target=module.networking -auto-approve
  ```
  **Expected Duration:** 3-5 minutes

- [ ] **Verify VPC creation**
  ```bash
  terraform output vpc_id
  aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)
  ```
  **Troubleshooting:** If VPC creation fails, check AWS service limits

- [ ] **Verify subnets**
  ```bash
  aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
  ```
  **Expected:** 6 subnets (3 public, 3 private)

### 2.5 Deploy ECR Module

- [ ] **Plan ECR repositories**
  ```bash
  terraform plan -target=module.ecr
  ```

- [ ] **Apply ECR repositories**
  ```bash
  terraform apply -target=module.ecr -auto-approve
  ```
  **Expected Duration:** 1-2 minutes

- [ ] **Verify ECR repositories**
  ```bash
  aws ecr describe-repositories | grep repositoryName
  ```
  **Expected:** 7 repositories (api-gateway, customers-service, vets-service, visits-service, genai-service, config-server, discovery-server)

- [ ] **Save ECR URLs**
  ```bash
  terraform output ecr_repository_urls > /tmp/ecr_urls.json
  export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  export ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
  ```
  *   **💡 Pro-Tip:** Add `export ECR_REGISTRY=${ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com` to your `~/.bashrc` or `~/.zshrc` to ensure it persists across terminal sessions.

### 2.6 Deploy RDS Module

- [ ] **Plan RDS instance**
  ```bash
  terraform plan -target=module.rds
  ```
  **Review:** Multi-AZ MySQL instance, security groups, subnet group

- [ ] **Apply RDS instance**
  ```bash
  terraform apply -target=module.rds -auto-approve
  ```
  **Expected Duration:** 10-15 minutes
  **Troubleshooting:** RDS creation is slow; this is normal

- [ ] **Verify RDS instance**
  ```bash
  aws rds describe-db-instances --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]'
  ```
  **Expected Status:** `available`

- [ ] **Save RDS endpoint**
  ```bash
  export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
  echo "RDS Endpoint: $RDS_ENDPOINT"
  ```

- [ ] **Test RDS connectivity (from VPC)**
  ```bash
  # This will be tested after EKS nodes are up
  echo "RDS connectivity test deferred to Phase 5"
  ```

### 2.7 Deploy EKS Module

- [ ] **Plan EKS cluster**
  ```bash
  terraform plan -target=module.eks
  ```
  **Review:** EKS control plane, managed node groups, IAM roles

- [ ] **Apply EKS cluster**
  ```bash
  terraform apply -target=module.eks -auto-approve
  ```
  **Expected Duration:** 15-20 minutes
  **Troubleshooting:** EKS creation is slow; monitor AWS console for progress

- [ ] **Verify EKS cluster**
  ```bash
  aws eks describe-cluster --name $(terraform output -raw eks_cluster_name) --query 'cluster.status'
  ```
  **Expected Status:** `ACTIVE`

- [ ] **Configure kubectl**
  ```bash
  aws eks update-kubeconfig \
    --region us-east-1 \
    --name $(terraform output -raw eks_cluster_name)
  ```

- [ ] **Verify kubectl connectivity**
  ```bash
  kubectl cluster-info
  kubectl get nodes
  ```
  **Expected:** 3 nodes in `Ready` state
  **Troubleshooting:** If nodes not ready, wait 2-3 minutes for initialization

- [ ] **Verify node groups**
  ```bash
  aws eks describe-nodegroup \
    --cluster-name $(terraform output -raw eks_cluster_name) \
    --nodegroup-name petclinic_nodes
  ```

### 2.8 Secrets Management (S3-Based Storage)
*   **Logic:** For this project, we store microservice secrets (DB passwords, API keys) as an encrypted JSON object in our S3 Backend Bucket. This avoids the cost of AWS Secrets Manager while maintaining encryption at rest.

- [ ] **Prepare Secrets JSON**
  ```bash
  cat > secrets.json << EOF
  {
    "db_password": "${TF_VAR_db_password}",
    "openai_api_key": "${TF_VAR_openai_api_key}",
    "environment": "dev"
  }
  EOF
  ```

- [ ] **Upload Encrypted Secrets to S3**
  ```bash
  aws s3 cp secrets.json s3://${BUCKET_NAME}/secrets/dev_secrets.json \
    --sse AES256
  ```
  **Verification:** `aws s3 ls s3://${BUCKET_NAME}/secrets/`

- [ ] **Secure Local Cleanup**
  ```bash
  rm secrets.json
  ```

- [ ] **Test Secret Retrieval**
  ```bash
  aws s3 cp s3://${BUCKET_NAME}/secrets/dev_secrets.json - | jq .
  ```

### 2.9 Deploy ALB Module

- [ ] **Plan ALB**
  ```bash
  terraform plan -target=module.alb
  ```

- [ ] **Apply ALB**
  ```bash
  terraform apply -target=module.alb -auto-approve
  ```

- [ ] **Verify ALB**
  ```bash
  aws elbv2 describe-load-balancers --query 'LoadBalancers[0].[LoadBalancerName,DNSName,State.Code]'
  ```
  **Expected State:** `active`

- [ ] **Save ALB DNS**
  ```bash
  export ALB_DNS=$(terraform output -raw alb_dns_name)
  echo "ALB DNS: $ALB_DNS"
  ```

### 2.10 Deploy WAF (Web Application Firewall) Module
*   **Logic:** Protect the Application Load Balancer from common web exploits (SQL injection, XSS) and bot traffic using AWS WAFv2.

- [ ] **Plan WAF resources**
  ```bash
  terraform plan -target=module.waf
  ```

- [ ] **Apply WAF resources**
  ```bash
  terraform apply -target=module.waf -auto-approve
  ```

- [ ] **Associate WAF with ALB**
  *   **Logic:** The WAF Web ACL must be associated with the ALB ARN to begin filtering traffic.
  ```bash
  export WAF_ACL_ARN=$(terraform output -raw waf_web_acl_arn)
  export ALB_ARN=$(terraform output -raw alb_arn)
  aws wafv2 associate-web-acl --web-acl-arn ${WAF_ACL_ARN} --resource-arn ${ALB_ARN}
  ```

- [ ] **Verify WAF Protection**
  ```bash
  aws wafv2 list-resources-for-web-acl --web-acl-arn ${WAF_ACL_ARN}
  ```
  **Expected Result:** The ALB ARN appears in the protected resources list.

### 2.11 Deploy Route53 DNS Module
*   **Logic:** Assign a human-readable domain name to the microservices ecosystem. Route53 Alias records provide a zero-cost, high-performance link to the ALB.

- [ ] **Plan Route53 resources**
  ```bash
  terraform plan -target=module.route53
  ```

- [ ] **Apply Route53 resources**
  ```bash
  terraform apply -target=module.route53 -auto-approve
  ```

- [ ] **Verify DNS Propagation**
  ```bash
  export DOMAIN_NAME=$(terraform output -raw domain_name)
  dig +short ${DOMAIN_NAME}
  ```
  **Expected Result:** Returns the ALB's CNAME or associated IP addresses.

### 2.12 EKS Fargate Migration Pattern
*   **Logic:** Transitioning from EC2 nodes to serverless EKS pods to eliminate OS management overhead and implement per-pod security isolation.

- [ ] **Create Fargate Profile**
  ```bash
  aws eks create-fargate-profile \
    --fargate-profile-name fp-petclinic \
    --cluster-name $(terraform output -raw eks_cluster_name) \
    --pod-execution-role-arn $(terraform output -raw fargate_pod_execution_role_arn) \
    --selectors namespace=petclinic-fargate
  ```

- [ ] **Verify Fargate Configuration**
  ```bash
  kubectl get fargateprofile -n petclinic-fargate
  ```

### 2.13 Deploy Monitoring Module

- [ ] **Plan monitoring**
  ```bash
  terraform plan -target=module.monitoring
  ```

- [ ] **Apply monitoring**
  ```bash
  terraform apply -target=module.monitoring -auto-approve
  ```

- [ ] **Verify CloudWatch alarms**
  ```bash
  aws cloudwatch describe-alarms --alarm-name-prefix petclinic
  ```

### 2.14 Final Terraform Validation

- [ ] **Run full plan**
  ```bash
  terraform plan
  ```
  **Expected:** No changes required

- [ ] **Save all outputs**
  ```bash
  terraform output -json > /tmp/terraform_outputs.json
  cat /tmp/terraform_outputs.json | jq .
  ```

---

## PHASE 3: Configuration Management (Ansible)

### 3.1 Prepare Ansible Inventory

- [ ] **Extract EC2 node IPs**
  ```bash
  kubectl get nodes -o wide | awk '{print $6}' | tail -n +2 > /tmp/node_ips.txt
  ```

- [ ] **Create Ansible inventory**
  ```bash
  cd /home/gsmash/Documents/spring-petclinic-microservices/ansible
  cat > inventory/dynamic_hosts << EOF
  [eks_nodes]
  $(cat /tmp/node_ips.txt | xargs -I {} echo "{} ansible_user=ec2-user")
  EOF
  ```

- [ ] **Verify inventory**
  ```bash
  cat inventory/dynamic_hosts
  ```

### 3.2 Test SSH Connectivity

- [ ] **Add SSH keys to known_hosts**
  ```bash
  for IP in $(cat /tmp/node_ips.txt); do
    ssh-keyscan -H $IP >> ~/.ssh/known_hosts 2>/dev/null
  done
  ```

- [ ] **Test Ansible ping**
  ```bash
  ansible -i inventory/dynamic_hosts eks_nodes -m ping
  ```
  **Expected Output:** `SUCCESS`
  **Troubleshooting:** If connection fails, verify security groups allow SSH from your IP

### 3.3 Run Ansible Playbooks

- [ ] **Install all tools**
  ```bash
  cd /home/gsmash/Documents/spring-petclinic-microservices/ansible
  ansible-playbook -i inventory/dynamic_hosts playbooks/install-tools.yml
  ```
  **Expected Duration:** 5-10 minutes

- [ ] **Verify Java installation**
  ```bash
  ansible -i inventory/dynamic_hosts eks_nodes -m shell -a "java -version"
  ```
  **Expected:** Java 21

- [ ] **Verify Maven installation**
  ```bash
  ansible -i inventory/dynamic_hosts eks_nodes -m shell -a "mvn -version"
  ```

- [ ] **Verify Docker installation**
  ```bash
  ansible -i inventory/dynamic_hosts eks_nodes -m shell -a "docker --version"
  ```

- [ ] **Verify kubectl installation**
  ```bash
  ansible -i inventory/dynamic_hosts eks_nodes -m shell -a "kubectl version --client"
  ```

- [ ] **Verify AWS CLI installation**
  ```bash
  ansible -i inventory/dynamic_hosts eks_nodes -m shell -a "aws --version"
  ```

---

## 🧪 PHASE 3.5: Infrastructure Validation (Pytest-Testinfra)

### 3.4 Automated Server Auditing
*   **Logic:** Verify that Ansible successfully configured the nodes according to our SRE standards.

- [ ] **Prepare Pytest Environment**
  ```bash
  pip install pytest-testinfra
  ```

- [ ] **Run Infrastructure Tests**
  *   **Logic:** Checks for specific package versions, running processes, and open ports on the EKS nodes.
  ```bash
  # Run tests against all nodes in the inventory
  pytest -v --hosts='ansible://eks_nodes?ansible_inventory=ansible/inventory/dynamic_hosts' \
    tests/infra/test_nodes.py
  ```

- [ ] **Verification Items (NRE Standard)**
  - [ ] **Java 21** is the default runtime.
  - [ ] **Docker** daemon is active and responsive.
  - [ ] **Kubelet** process is running.
  - [ ] **CloudWatch Agent** is properly configured.

---

## 🛠️ PHASE 4: CI/CD Pipeline Automation (Jenkins)

### 4.1 Jenkins Pipeline Integration
*   **Logic:** Move from manual execution to an automated "Pipeline as Code" model using a `Jenkinsfile`.

- [ ] **Configure Jenkins Master/Agent**
  *   Ensure Jenkins has the following plugins: `Pipeline`, `Git`, `Docker`, `Terraform`, `Ansible`.
  *   Configure AWS Credentials in Jenkins Credentials Store (`ID: aws-creds`).

- [ ] **Define Pipeline Stages**
  ```groovy
  pipeline {
      agent any
      environment {
          ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com"
          AWS_DEFAULT_REGION = "us-east-1"
          ALB_DNS = "replace-with-actual-alb-dns" // Or retrieve via script
          APP_NAMESPACE = "petclinic"
      }
      stages {
          stage('Checkout') { steps { checkout scm } }
          stage('Security Scan (Trivy)') {
              steps {
                  sh 'trivy fs --severity HIGH,CRITICAL .'
              }
          }
          stage('Terraform Plan') {
              steps {
                  dir('terraform/environments/dev') {
                      sh 'terraform init && terraform plan -out=tfplan'
                      sh 'terraform show -json tfplan > tfplan.json'
                      sh 'infracost breakdown --path tfplan.json'
                  }
              }
          }
          stage('Terraform Apply') {
              steps {
                  dir('terraform/environments/dev') {
                      sh 'terraform apply -auto-approve tfplan'
                  }
              }
          }
          stage('Code Quality (SonarQube)') {
              steps {
                  withSonarQubeEnv('SonarQube') {
                      sh './mvnw sonar:sonar -Dsonar.projectKey=petclinic -Dsonar.host.url=http://sonarqube:9000'
                  }
              }
          }
          stage('Unit & Integration Tests') {
              steps {
                  sh './mvnw test'
              }
          }
          stage('Infrastructure Validation') {
              steps {
                  sh "pytest -v --hosts='ansible://eks_nodes?ansible_inventory=ansible/inventory/dynamic_hosts' tests/infra/test_nodes.py"
              }
          }
          stage('Build & Push') {
              steps {
                  sh './mvnw install -P buildDocker -Ddocker.image.prefix=${ECR_REGISTRY}/dev-petclinic'
                  sh 'trivy image --severity HIGH,CRITICAL ${ECR_REGISTRY}/dev-petclinic-api-gateway:latest'
              }
          }
          stage('K8s Deploy') {
              steps {
                  sh 'kubectl apply -f k8s/'
              }
          }
          stage('Smoke Test') {
              steps {
                  sh 'pytest -v tests/smoke/test_endpoints.py --base-url="http://${ALB_DNS}"'
              }
          }
      }
  }
  ```

---

### 4.1 Build Application

- [ ] **Navigate to project root**
  ```bash
  cd /home/gsmash/Documents/spring-petclinic-microservices
  ```

- [ ] **Clean previous builds**
  ```bash
  ./mvnw clean
  ```

- [ ] **Run Unit and Integration Tests (JUnit/Mockito)**
  *   **Logic:** Validate business logic and microservice interaction before packaging.
  ```bash
  ./mvnw clean test
  ```
  *   **Expected Outcome:** All tests pass. Check `target/surefire-reports` for details.

- [ ] **Build all microservices**
  ```bash
  ./mvnw install -DskipTests
  ```
  **Expected Duration:** 3-5 minutes
  **Troubleshooting:** If build fails, check Java version with `java -version`

- [ ] **Verify JAR files**
  ```bash
  find . -name "*.jar" -path "*/target/*" | grep -v "original"
  ```
  **Expected:** 8 JAR files

### 4.2 Build Docker Images

- [ ] **Authenticate to ECR**
  ```bash
  aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin ${ECR_REGISTRY}
  ```

- [ ] **Build Docker images**
  ```bash
  ./mvnw clean install -P buildDocker \
    -Ddocker.image.prefix=${ECR_REGISTRY}/dev-petclinic
  ```
  **Expected Duration:** 10-15 minutes

- [ ] **Verify Docker images**
  ```bash
  docker images | grep petclinic
  ```
  **Expected:** 8 images

### 4.3 Container Security Scanning (Trivy)
*   **Logic:** Shift-Left security by scanning images for vulnerabilities (CVEs) before they reach the registry.

- [ ] **Scan Microservice Images**
  ```bash
  for service in api-gateway customers-service vets-service visits-service; do
    trivy image --severity HIGH,CRITICAL ${ECR_REGISTRY}/dev-petclinic-${service}:latest
  done
  ```
  **Expected Outcome:** No CRITICAL vulnerabilities found. If found, the pipeline should FAIL.

### 4.4 Push Images to ECR

- [ ] **Tag and push all images**
  ```bash
  for service in api-gateway customers-service vets-service visits-service genai-service config-server discovery-server admin-server; do
    docker tag ${ECR_REGISTRY}/dev-petclinic-${service}:latest ${ECR_REGISTRY}/dev-petclinic-${service}:v1.0.0
    docker push ${ECR_REGISTRY}/dev-petclinic-${service}:latest
    docker push ${ECR_REGISTRY}/dev-petclinic-${service}:v1.0.0
  done
  ```

- [ ] **Verify images in ECR**
  ```bash
  aws ecr list-images --repository-name dev-petclinic-api-gateway
  ```

### 4.4 Deploy to Kubernetes (Helm)
*   **Logic:** Use Helm as the package manager to ensure transactional deployments, rollbacks, and templated configuration management.

- [ ] **Create namespace**
  ```bash
  kubectl create namespace petclinic || true
  kubectl config set-context --current --namespace=petclinic
  ```

- [ ] **Create database secret**
  ```bash
  kubectl create secret generic mysql-credentials \
    --from-literal=username=petclinic \
    --from-literal=password=${TF_VAR_db_password} \
    --from-literal=endpoint=${RDS_ENDPOINT} \
    -n petclinic --dry-run=client -o yaml | kubectl apply -f -
  ```

- [ ] **Install/Upgrade Microservices with Helm**
  ```bash
  helm upgrade --install petclinic ./helm/microservices \
    --namespace petclinic \
    --set global.image.repositoryPrefix=${ECR_REGISTRY}/dev-petclinic- \
    --set global.image.tag=latest \
    --wait --timeout 300s
  ```
  **Verification:** `helm list -n petclinic`

- [ ] **Verify all pods running**
  ```bash
  kubectl get pods -n petclinic
  ```

---

## PHASE 5: Validation & Health Checks

### 5.1 Application Health

- [ ] **Check pod status**
  ```bash
  kubectl get pods -n petclinic -o wide
  ```

- [ ] **Check pod logs**
  ```bash
  kubectl logs -l app=api-gateway -n petclinic --tail=50
  ```

- [ ] **Test health endpoints**
  ```bash
  kubectl port-forward svc/api-gateway 8080:8080 -n petclinic &
  curl http://localhost:8080/actuator/health
  ```
  **Expected:** `{"status":"UP"}`

### 5.2 Database Connectivity

- [ ] **Test RDS connection from pod**
  ```bash
  kubectl exec -it deployment/customers-service -n petclinic -- \
    mysql -h ${RDS_ENDPOINT} -u petclinic -p${TF_VAR_db_password} -e "SHOW DATABASES;"
  ```

### 5.3 Load Balancer Verification

- [ ] **Get ALB endpoint**
  ```bash
  kubectl get ingress -n petclinic
  ```

- [ ] **Test ALB endpoint**
  ```bash
  curl -I http://${ALB_DNS}
  ```

### 5.4 Monitoring Verification

- [ ] **Check Prometheus**
  ```bash
  kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
  curl http://localhost:9090/-/healthy
  ```

- [ ] **Check Grafana**
  ```bash
  kubectl port-forward -n monitoring svc/grafana 3000:3000 &
  ```

### 5.5 End-to-End Test

- [ ] **Access application**
  ```bash
  echo "Application URL: http://${ALB_DNS}"
  ```

- [ ] **Test API endpoints**
  ```bash
  curl http://${ALB_DNS}/api/customer/owners
  curl http://${ALB_DNS}/api/vet/vets
  ```

### 5.6 Automated Smoke Testing (Pytest)
*   **Logic:** Execute a suite of automated functional tests to verify the application is fully operational and reachable by users.

- [ ] **Run Smoke Tests**
  ```bash
  export BASE_URL="http://${ALB_DNS}"
  pytest -v tests/smoke/test_endpoints.py --base-url=${BASE_URL}
  ```
  *   **Verification Items:**
    - [ ] Root endpoint returns `200 OK`.
    - [ ] `API Gateway` correctly routes traffic to `vets-service`.
    - [ ] `API Gateway` correctly routes traffic to `customers-service`.
    - [ ] Database data is retrievable via the API.

### 5.7 Stress & Load Testing (Apache JMeter)
*   **Logic:** Validate that the EKS cluster and HPA (Horizontal Pod Autoscaler) respond correctly to simulated traffic spikes.

- [ ] **Run Load Test Suite**
  ```bash
  jmeter -n -t tests/performance/petclinic_load_test.jmx -l results.jtl
  ```
- [ ] **Verify Auto-scaling**
  ```bash
  kubectl get hpa -n petclinic -w
  ```
  **Success Metric:** Pod count increases as CPU/Memory thresholds are crossed; zero 503 errors during peak load.

### 5.8 Chaos Engineering (AWS FIS / Chaos Mesh)
*   **Logic:** Verify the "Self-Healing" capabilities of Kubernetes by intentionally injecting failures into the microservices ecosystem.

- [ ] **Inject Pod Failure**
  ```bash
  kubectl delete pod -l app=vets-service -n petclinic --force
  ```
- [ ] **Inject Network Latency**
  *   **Action:** Use AWS FIS or Chaos Mesh to add 200ms of latency between `api-gateway` and `customers-service`.
- [ ] **Verify Resilience**
  **Success Metric:** System remains available; K8s `ReplicaSet` automatically recreates the deleted pods; Circuit Breakers (Resilience4j) prevent cascading failures.

---

## Troubleshooting Guide

| Issue | Symptom | Solution |
|-------|---------|----------|
| Terraform state lock | `Error acquiring state lock` | Run `terraform force-unlock <LOCK_ID>` |
| EKS nodes not ready | `NotReady` status | Wait 5 minutes, check node logs |
| RDS connection timeout | Connection refused | Verify security groups allow traffic from EKS |
| ECR push denied | `denied: User not authorized` | Re-authenticate with `aws ecr get-login-password` |
| Pod CrashLoopBackOff | Pod restarting | Check logs with `kubectl logs <pod>` |
| ALB 503 errors | Service unavailable | Verify target group health checks |
| Invalid AWS Token | `ExpiredToken` | Refresh session with `aws sso login` or `aws configure` |

---

## 🛠️ PHASE 6: Continuous Maintenance & Lifecycle
*   **Logic:** A production system is only as good as its Day-2 operations. These steps ensure long-term stability and cost control.

### 6.1 ECR Image Lifecycle Management
- [ ] **Configure Image Cleanup**
  *   **Logic:** Prevent ECR costs from ballooning by deleting untagged or old images.
  ```bash
  aws ecr put-lifecycle-policy \
    --repository-name dev-petclinic-api-gateway \
    --lifecycle-policy-text '{"rules":[{"rulePriority":1,"selection":{"tagStatus":"untagged","countType":"imageCountMoreThan","countNumber":5},"action":{"type":"expire"}}]}'
  ```

### 6.2 Logs & Observability Maintenance
- [ ] **Check CloudWatch Log Retention**
  *   **Logic:** Ensure logs are not kept indefinitely to save costs. Set to 14 or 30 days.
  ```bash
  aws logs put-retention-policy --log-group-name /aws/eks/petclinic/cluster --retention-in-days 30
  ```

### 6.3 Database Backups (RDS)
- [ ] **Verify Snapshot Status**
  ```bash
  aws rds describe-db-snapshots --db-instance-identifier petclinic-db-dev
  ```

---

## Cleanup Procedure

```bash
# Delete Kubernetes resources
kubectl delete namespace petclinic

# Destroy Terraform infrastructure
cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/environments/dev
terraform destroy -auto-approve
```

---

## Completion Checklist

- [ ] All Terraform modules deployed successfully
- [ ] All Ansible playbooks executed without errors
- [ ] All microservices running in Kubernetes
- [ ] Database connectivity verified
- [ ] Load balancer responding to requests
- [ ] Monitoring stack operational
- [ ] Documentation updated with actual values
