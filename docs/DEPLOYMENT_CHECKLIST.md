# Spring PetClinic Microservices - Complete Deployment Checklist

## Overview
This checklist provides a comprehensive, step-by-step guide for deploying the Spring PetClinic Microservices application to AWS using Terraform, Ansible, and Kubernetes.

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
│  VPC → ECR → RDS → EKS → Secrets → ALB → Monitoring           │
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

| Phase | Tool | Input | Output | Next Phase Uses |
|-------|------|-------|--------|-----------------|
| Infra | Terraform | `backend.tf`, `terraform.tfvars` | ECR URLs, RDS Endpoint, EKS Config | Ansible, Maven, kubectl |
| Config | Ansible | EC2 IPs from Terraform | Configured nodes with tools | Maven, Docker |
| Build | Maven | Source code, `pom.xml` | JAR files | Docker |
| Package | Docker | JARs, `Dockerfile` | Container images | ECR |
| Deploy | kubectl | K8s manifests, ECR images | Running pods | Monitoring |
| Monitor | Prometheus/Grafana | Pod metrics | Dashboards | Operations |

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
  **Expected Output:** `us-west-2`
  **Troubleshooting:** Set region with `export AWS_DEFAULT_REGION=us-west-2`

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

### 1.3 State Backend Preparation

- [ ] **Create S3 bucket for Terraform state**
  ```bash
  export RANDOM_SUFFIX=$(openssl rand -hex 4)
  aws s3 mb s3://petclinic-terraform-state-${RANDOM_SUFFIX} --region us-west-2
  ```
  **Verification:**
  ```bash
  aws s3 ls | grep petclinic-terraform-state
  ```
  **Troubleshooting:** If bucket exists, use existing bucket name

- [ ] **Enable S3 bucket versioning**
  ```bash
  aws s3api put-bucket-versioning \
    --bucket petclinic-terraform-state-${RANDOM_SUFFIX} \
    --versioning-configuration Status=Enabled
  ```
  **Verification:**
  ```bash
  aws s3api get-bucket-versioning --bucket petclinic-terraform-state-${RANDOM_SUFFIX}
  ```

- [ ] **Enable S3 bucket encryption**
  ```bash
  aws s3api put-bucket-encryption \
    --bucket petclinic-terraform-state-${RANDOM_SUFFIX} \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }]
    }'
  ```

- [ ] **Create DynamoDB table for state locking**
  ```bash
  aws dynamodb create-table \
    --table-name petclinic-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-west-2
  ```
  **Verification:**
  ```bash
  aws dynamodb describe-table --table-name petclinic-terraform-locks
  ```
  **Troubleshooting:** If table exists, verify it has correct schema

- [ ] **Update backend.tf with bucket name**
  ```bash
  cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/environments/dev
  # Edit backend.tf and replace bucket name
  sed -i "s/petclinic-terraform-state-dev/petclinic-terraform-state-${RANDOM_SUFFIX}/" backend.tf
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
5. secrets (Secrets Manager)
   ↓
6. alb (Load Balancer)
   ↓
7. monitoring (CloudWatch)
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

### 2.3 Configure Variables

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
  export ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com"
  ```

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
    --region us-west-2 \
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

### 2.8 Deploy Secrets Module

- [ ] **Plan secrets**
  ```bash
  terraform plan -target=module.secrets
  ```

- [ ] **Apply secrets**
  ```bash
  terraform apply -target=module.secrets -auto-approve
  ```

- [ ] **Verify secrets**
  ```bash
  aws secretsmanager list-secrets | grep petclinic
  ```

- [ ] **Test secret retrieval**
  ```bash
  aws secretsmanager get-secret-value --secret-id dev/petclinic/db/credentials --query SecretString --output text | jq .
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

### 2.10 Deploy Monitoring Module

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

### 2.11 Final Terraform Validation

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

## PHASE 4: Build & Deploy Application

### 4.1 Build Application

- [ ] **Navigate to project root**
  ```bash
  cd /home/gsmash/Documents/spring-petclinic-microservices
  ```

- [ ] **Clean previous builds**
  ```bash
  ./mvnw clean
  ```

- [ ] **Build all microservices**
  ```bash
  ./mvnw clean install -DskipTests
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
  aws ecr get-login-password --region us-west-2 | \
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

### 4.3 Push Images to ECR

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

### 4.4 Deploy to Kubernetes

- [ ] **Create namespace**
  ```bash
  kubectl create namespace petclinic
  kubectl config set-context --current --namespace=petclinic
  ```

- [ ] **Create database secret**
  ```bash
  kubectl create secret generic mysql-credentials \
    --from-literal=username=petclinic \
    --from-literal=password=${TF_VAR_db_password} \
    --from-literal=endpoint=${RDS_ENDPOINT} \
    -n petclinic
  ```

- [ ] **Deploy config server**
  ```bash
  kubectl apply -f k8s/config-server.yaml
  kubectl wait --for=condition=available --timeout=300s deployment/config-server -n petclinic
  ```

- [ ] **Deploy discovery server**
  ```bash
  kubectl apply -f k8s/discovery-server.yaml
  kubectl wait --for=condition=available --timeout=300s deployment/discovery-server -n petclinic
  ```

- [ ] **Deploy microservices**
  ```bash
  kubectl apply -f k8s/customers-service.yaml
  kubectl apply -f k8s/vets-service.yaml
  kubectl apply -f k8s/visits-service.yaml
  kubectl apply -f k8s/genai-service.yaml
  ```

- [ ] **Deploy API gateway**
  ```bash
  kubectl apply -f k8s/api-gateway.yaml
  kubectl wait --for=condition=available --timeout=300s deployment/api-gateway -n petclinic
  ```

- [ ] **Verify all pods running**
  ```bash
  kubectl get pods -n petclinic
  ```
  **Expected:** All pods in `Running` state

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
