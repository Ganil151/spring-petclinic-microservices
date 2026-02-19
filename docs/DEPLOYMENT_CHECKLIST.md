# 🚀 Spring PetClinic Microservices: Master Deployment Checklist

## 📋 Overview
This document serves as the definitive source of truth for the end-to-end deployment of the Spring PetClinic Microservices ecosystem on AWS. It follows a multi-layered SRE approach:
- **Layer 1 (Provisioning):** Terraform (VPC, ECR, RDS, EKS)
- **Layer 2 (Configuration):** Ansible (Java 21, Docker, Jenkins master, SonarQube)
- **Layer 3 (Orchestration):** Helm (Kubernetes Deployments, Services, HPA)
- **Layer 4 (Life-cycle):** Jenkins CI/CD (Pipeline as Code)

---

## 🏗️ System Architecture & Topology

### 1. Compute Distribution
| Role | Instance Type | vCPU / RAM | Purpose |
| :--- | :--- | :--- | :--- |
| **Jenkins Master** | `t3.large` | 2 / 8GB | CI/CD Controller & Orchestration |
| **SonarQube Server** | `t2.medium` | 2 / 4GB | Code Quality & Static Analysis |
| **Worker Node** | `t3.medium` | 2 / 4GB | Ansible Execution & Build Environment |
| **EKS Node Group** | `t3.medium` (x2) | 2 / 4GB | Production Microservice Runtime |

### 2. Networking Logic
- **Public Subnets:** Jenkins Master, SonarQube, NAT Gateway, Load Balancer.
- **Private Subnets:** EKS Compute Nodes, RDS MySQL instance.
- **Security:** "Least Privilege" security groups; EKS control plane endpoint is semi-private.

---

## 🔐 Phase 1: Pre-Flight Essentials
- [ ] **AWS CLI Identity:** `aws sts get-caller-identity` (Confirm correct account)
- [ ] **Terraform Version:** `terraform version` (Required: >= 1.5.0)
- [ ] **Backend Initialization:** 
  ```bash
  cd terraform/environments/dev
  terraform init -reconfigure
  ```
- [ ] **VPC Configuration Verify:** Check `terraform.tfvars` for correct CIDR blocks and AZs.

---

## 🏗️ Phase 2: Infrastructure Provisioning (Terraform)
*Logic: Deploy the foundation first. Protect existing IPs by targeting new modules if necessary.*

### 2.1 Credentials Setup
- [ ] **Set Database Master Password:**
  ```bash
  export TF_VAR_db_password="YourSecurePassword123!" 
  ```

### 2.2 Execution (Incremental vs Full)
- [ ] **Option A: Incremental (Safe)** - Deploy only RDS and EKS (Protects Jenkins/Worker IPs):
  ```bash
  terraform apply -target=module.rds -target=module.eks
  ```
- [ ] **Option B: Full Suite** - Deploy entire stack:
  ```bash
  terraform apply
  ```

### 2.3 Post-Provisioning Validation
- [ ] **Capture RDS Endpoint:** `terraform output rds_endpoint`
- [ ] **Capture EKS Cluster Name:** `terraform output eks_cluster_name`
- [ ] **Verify Inventory Generation:** Confirm `ansible/inventory/hosts` was created automatically.

---

## 🔧 Phase 3: System Configuration (Ansible)
*Logic: Use the Terraform-generated inventory to install tools across the fleet.*

### 3.1 Connectivity Test
- [ ] **Ping all nodes:**
  ```bash
  cd ansible
  ansible all -m ping -i inventory/hosts
  ```

### 3.2 Fleet Configuration
- [ ] **Run Master Playbook:**
  ```bash
  ansible-playbook -i inventory/hosts playbooks/install-tools.yml
  ```
- [ ] **Verify Java 21 (Worker):** `ssh -i ... ec2-user@<worker-ip> 'java -version'`
- [ ] **Verify SonarQube:** Access `http://<sonarqube-ip>:9000` (Default: admin/admin)

---

## 🚢 Phase 4: CI/CD & Application Deployment (Helm)
*Logic: Jenkins orchestrates the build. Helm orchestrates the Kubernetes state.*

### 4.1 Jenkins Initialization
- [ ] **Install Plugins:** (Pipeline, ECR, AWS Steps, Docker, SonarQube Scanner)
- [ ] **Configure Credentials:**
  - `aws-credentials` (IAM Key/Secret)
  - `sonarqube-token` (From SonarQube UI)
- [ ] **Global Tool Setup:** Map `jdk-21` and `maven-3.9`.

### 4.2 Application Rollout
- [ ] **Trigger Jenkins Pipeline:** Select the `main` branch and run.
- [ ] **Stage: Build & Scan:** Verify Maven build and SonarQube quality gate pass.
- [ ] **Stage: ECR Push:** Verify images appear in the AWS ECR console.
- [ ] **Stage: Helm Deploy:**
  ```bash
  # Logic executed by Jenkins
  helm upgrade --install petclinic ./helm/microservices \
      --namespace petclinic --create-namespace \
      -f ./helm/microservices/overrides/dev.yaml \
      --set global.ecrRegistry=${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
  ```

---

## 🚦 Phase 5: Verification & Quality Gates
- [ ] **Pod Status:** `kubectl get pods -n petclinic` (All 7 microservices should be `Running`)
- [ ] **Service Discovery:** Check Eureka dashboard via API Gateway.
- [ ] **Database Connectivity:** Verify `customers-service` can read/write to RDS.
- [ ] **External Access:** `kubectl get svc -n petclinic` (Find LoadBalancer DNS).

---

## 🧹 Phase 6: Maintenance & Lifecycle
- [ ] **Monitoring:** Check Prometheus metrics for pod resource usage.
- [ ] **Log Rotation:** Verify CloudWatch log group retention periods.
- [ ] **Cleanup (Optional):**
  ```bash
  # Delete application but keep infra
  helm uninstall petclinic -n petclinic
  
  # Destroy everything
  terraform destroy -auto-approve
  ```

---

**Last Updated:** 2026-02-19  
**Status:** ✅ Ready for Cluster Provisioning
