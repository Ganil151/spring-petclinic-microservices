# AWS Deployment Checklist - Spring PetClinic Microservices

## Phase 1: Pre-Flight (Environment & Security)

### IAM & Access Management
- [ ] Create dedicated Terraform execution role with least privilege
  - **Command**: `aws iam create-role --role-name terraform-petclinic-role --assume-role-policy-document file://trust-policy.json`
  - **Junior's Safety Note**: NEVER use root credentials for Terraform operations

- [ ] Attach required policies to Terraform role
  - **Command**: `aws iam attach-role-policy --role-name terraform-petclinic-role --policy-arn arn:aws:iam::aws:policy/PowerUserAccess`

### State Management
- [ ] Create S3 bucket for Terraform remote state
  - **Command**: `aws s3 mb s3://petclinic-terraform-state-${RANDOM_SUFFIX}`
  - **Junior's Safety Note**: Enable versioning and encryption on state bucket

- [ ] Create DynamoDB table for state locking
  - **Command**: `aws dynamodb create-table --table-name petclinic-terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST`

### Network Foundation
- [ ] Initialize Terraform backend configuration
  - **Command**: `terraform init -backend-config="bucket=petclinic-terraform-state-${SUFFIX}"`

- [ ] Provision VPC with 3 AZs (3 public + 3 private subnets)
  - **Command**: `terraform apply -target=module.vpc`
  - **Junior's Safety Note**: Always review terraform plan before applying

## Phase 2: Ground Control (Base Infrastructure)

### Kubernetes Control Plane
- [ ] Provision EKS cluster with managed control plane
  - **Command**: `terraform apply -target=module.eks`
  - **Junior's Safety Note**: EKS cluster creation takes 10-15 minutes

- [ ] Configure kubectl context
  - **Command**: `aws eks update-kubeconfig --region us-west-2 --name petclinic-cluster`

### Worker Nodes
- [ ] Deploy managed node groups with auto-scaling
  - **Command**: `terraform apply -target=module.eks_node_groups`
  - **Junior's Safety Note**: Verify node group is in ACTIVE state before proceeding

- [ ] Validate cluster connectivity
  - **Command**: `kubectl get nodes`

### Database Layer
- [ ] Provision RDS MySQL instance with Multi-AZ
  - **Command**: `terraform apply -target=module.rds`
  - **Junior's Safety Note**: NEVER run terraform destroy on RDS module in production

- [ ] Create database schemas
  - **Command**: `kubectl apply -f k8s/db-init-job.yaml`

### Secrets Management
- [ ] Set up AWS Secrets Manager for database credentials
  - **Command**: `aws secretsmanager create-secret --name petclinic/db/credentials --secret-string '{"username":"petclinic","password":"${DB_PASSWORD}"}'`

- [ ] Install AWS Secrets Store CSI Driver
  - **Command**: `helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts && helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system`

## Phase 3: Payload Preparation (Microservices Configuration)

### Container Registry
- [ ] Create ECR repositories for each microservice
  - **Command**: `aws ecr create-repository --repository-name petclinic/api-gateway`
  - **Command**: `aws ecr create-repository --repository-name petclinic/customers-service`
  - **Command**: `aws ecr create-repository --repository-name petclinic/vets-service`
  - **Command**: `aws ecr create-repository --repository-name petclinic/visits-service`
  - **Command**: `aws ecr create-repository --repository-name petclinic/genai-service`

### Image Build & Push
- [ ] Authenticate Docker to ECR
  - **Command**: `aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com`

- [ ] Build and push container images
  - **Command**: `./mvnw clean install -P buildDocker -Ddocker.image.prefix=${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/petclinic`
  - **Command**: `docker push ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/petclinic/api-gateway:latest`
  - **Junior's Safety Note**: Tag images with git commit SHA for traceability

### Helm Configuration
- [ ] Install Helm charts for microservices
  - **Command**: `helm install petclinic-config ./helm/config-server --namespace petclinic --create-namespace`
  - **Command**: `helm install petclinic-discovery ./helm/discovery-server --namespace petclinic`
  - **Command**: `helm install petclinic-services ./helm/microservices --namespace petclinic`

## Phase 4: Launch Sequence (Deployment & Traffic)

### Load Balancer Setup
- [ ] Install AWS Load Balancer Controller
  - **Command**: `helm repo add eks https://aws.github.io/eks-charts && helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=petclinic-cluster`

- [ ] Deploy Application Load Balancer
  - **Command**: `kubectl apply -f k8s/ingress-alb.yaml`

### DNS & SSL
- [ ] Create Route53 hosted zone (if needed)
  - **Command**: `aws route53 create-hosted-zone --name petclinic.example.com --caller-reference $(date +%s)`

- [ ] Request SSL certificate via ACM
  - **Command**: `aws acm request-certificate --domain-name petclinic.example.com --validation-method DNS`

- [ ] Update Route53 records to point to ALB
  - **Command**: `kubectl get ingress petclinic-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`

### Deployment Strategy
- [ ] Configure blue-green deployment with Argo Rollouts
  - **Command**: `kubectl apply -f k8s/rollout-strategy.yaml`
  - **Junior's Safety Note**: Always test rollback procedure before production deployment

- [ ] Perform canary deployment (10% traffic)
  - **Command**: `kubectl argo rollouts set image petclinic-api-gateway api-gateway=${NEW_IMAGE_TAG}`

## Phase 5: Post-Launch Monitoring (Day 2 Operations)

### Health Monitoring
- [ ] Verify all service health endpoints
  - **Command**: `kubectl get pods -n petclinic -o wide`
  - **Command**: `curl https://petclinic.example.com/actuator/health`

- [ ] Configure readiness and liveness probes
  - **Command**: `kubectl describe pod -n petclinic -l app=api-gateway`

### Observability Stack
- [ ] Deploy Prometheus for metrics collection
  - **Command**: `helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace`

- [ ] Configure CloudWatch Container Insights
  - **Command**: `kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml`

- [ ] Set up log aggregation with Fluent Bit
  - **Command**: `helm repo add fluent https://fluent.github.io/helm-charts && helm install fluent-bit fluent/fluent-bit --namespace logging --create-namespace`

### Alerting Configuration
- [ ] Create SNS topic for alerts
  - **Command**: `aws sns create-topic --name petclinic-alerts`

- [ ] Configure CloudWatch alarms for high error rates
  - **Command**: `aws cloudwatch put-metric-alarm --alarm-name "PetClinic-HighErrorRate" --alarm-description "Alert when error rate exceeds 5%" --metric-name ErrorRate --namespace AWS/ApplicationELB --statistic Average --period 300 --threshold 5.0 --comparison-operator GreaterThanThreshold`

- [ ] Set up Slack/Teams integration for alerts
  - **Command**: `kubectl apply -f k8s/alertmanager-config.yaml`

### Performance Validation
- [ ] Run load tests against deployed application
  - **Command**: `kubectl apply -f k8s/load-test-job.yaml`

- [ ] Validate auto-scaling behavior
  - **Command**: `kubectl get hpa -n petclinic`

- [ ] Test disaster recovery procedures
  - **Junior's Safety Note**: NEVER test DR procedures during business hours

## Final Verification Checklist
- [ ] All services responding to health checks
- [ ] SSL certificate properly configured
- [ ] DNS resolution working correctly
- [ ] Monitoring dashboards populated with data
- [ ] Alert channels tested and functional
- [ ] Backup and recovery procedures documented
- [ ] Security scanning completed (container images and infrastructure)
- [ ] Performance benchmarks established
- [ ] Runbook documentation updated