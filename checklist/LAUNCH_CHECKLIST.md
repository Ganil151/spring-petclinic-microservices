# AWS Deployment Checklist - Spring PetClinic Microservices

## Phase 1: Pre-Flight (Environment & Security)

### IAM & Access Management
- [ ] Create trust policy document for Terraform role
  - **Command**: `cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF`
  - **Details**: Creates trust relationship allowing EC2 instances to assume this role

- [ ] Create dedicated Terraform execution role with least privilege
  - **Command**: `aws iam create-role --role-name terraform-petclinic-role --assume-role-policy-document file://trust-policy.json`
  - **Details**: Creates IAM role specifically for Terraform operations
  - **Junior's Safety Note**: NEVER use root credentials for Terraform operations

- [ ] Create custom policy for PetClinic deployment
  - **Command**: `cat > petclinic-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "rds:*",
        "s3:*",
        "iam:*",
        "route53:*",
        "acm:*",
        "secretsmanager:*",
        "ecr:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF`
  - **Details**: Defines minimum required permissions for deployment

- [ ] Attach custom policy to Terraform role
  - **Command**: `aws iam put-role-policy --role-name terraform-petclinic-role --policy-name PetClinicDeployment --policy-document file://petclinic-policy.json`
  - **Details**: Grants necessary permissions while maintaining least privilege

### State Management
- [ ] Generate unique suffix for resource naming
  - **Command**: `export RANDOM_SUFFIX=$(openssl rand -hex 4)`
  - **Details**: Creates unique identifier to avoid naming conflicts

- [ ] Create S3 bucket for Terraform remote state
  - **Command**: `aws s3 mb s3://petclinic-terraform-state-${RANDOM_SUFFIX} --region us-west-2`
  - **Details**: Stores Terraform state remotely for team collaboration
  - **Junior's Safety Note**: Enable versioning and encryption on state bucket

- [ ] Enable S3 bucket versioning
  - **Command**: `aws s3api put-bucket-versioning --bucket petclinic-terraform-state-${RANDOM_SUFFIX} --versioning-configuration Status=Enabled`
  - **Details**: Protects against accidental state file corruption

- [ ] Enable S3 bucket encryption
  - **Command**: `aws s3api put-bucket-encryption --bucket petclinic-terraform-state-${RANDOM_SUFFIX} --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'`
  - **Details**: Encrypts state files at rest

- [ ] Create DynamoDB table for state locking
  - **Command**: `aws dynamodb create-table --table-name petclinic-terraform-locks --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-west-2`
  - **Details**: Prevents concurrent Terraform operations that could corrupt state

### Network Foundation
- [ ] Create Terraform backend configuration
  - **Command**: `cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "petclinic-terraform-state-${RANDOM_SUFFIX}"
    key            = "petclinic/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "petclinic-terraform-locks"
    encrypt        = true
  }
}
EOF`
  - **Details**: Configures remote state storage with locking

- [ ] Initialize Terraform backend configuration
  - **Command**: `terraform init`
  - **Details**: Downloads providers and configures backend

- [ ] Create VPC Terraform configuration
  - **Command**: `cat > vpc.tf << EOF
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "petclinic-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Environment = "production"
    Project = "petclinic"
  }
}
EOF`
  - **Details**: Defines VPC with high availability across 3 AZs

- [ ] Provision VPC with 3 AZs (3 public + 3 private subnets)
  - **Command**: `terraform plan -target=module.vpc && terraform apply -target=module.vpc`
  - **Details**: Creates network foundation with NAT gateways for private subnets
  - **Junior's Safety Note**: Always review terraform plan before applying

## Phase 2: Ground Control (Base Infrastructure)

### Kubernetes Control Plane
- [ ] Create EKS cluster Terraform configuration
  - **Command**: `cat > eks.tf << EOF
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "petclinic-cluster"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  tags = {
    Environment = "production"
    Project = "petclinic"
  }
}
EOF`
  - **Details**: Defines EKS cluster with essential add-ons

- [ ] Provision EKS cluster with managed control plane
  - **Command**: `terraform plan -target=module.eks && terraform apply -target=module.eks`
  - **Details**: Creates Kubernetes control plane (takes 10-15 minutes)
  - **Junior's Safety Note**: EKS cluster creation takes 10-15 minutes

- [ ] Configure kubectl context
  - **Command**: `aws eks update-kubeconfig --region us-west-2 --name petclinic-cluster`
  - **Details**: Updates local kubectl configuration to connect to new cluster

- [ ] Verify cluster access
  - **Command**: `kubectl cluster-info`
  - **Details**: Confirms successful connection to EKS cluster

### Worker Nodes
- [ ] Add managed node group configuration to eks.tf
  - **Command**: `cat >> eks.tf << EOF

  eks_managed_node_groups = {
    petclinic_nodes = {
      min_size     = 2
      max_size     = 6
      desired_size = 3

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      k8s_labels = {
        Environment = "production"
        NodeGroup = "petclinic-workers"
      }

      update_config = {
        max_unavailable_percentage = 25
      }

      tags = {
        Environment = "production"
        Project = "petclinic"
      }
    }
  }
EOF`
  - **Details**: Configures auto-scaling worker nodes with rolling updates

- [ ] Deploy managed node groups with auto-scaling
  - **Command**: `terraform plan -target=module.eks && terraform apply -target=module.eks`
  - **Details**: Provisions EC2 instances as Kubernetes worker nodes
  - **Junior's Safety Note**: Verify node group is in ACTIVE state before proceeding

- [ ] Validate cluster connectivity and node status
  - **Command**: `kubectl get nodes -o wide`
  - **Details**: Shows all nodes with their status, roles, and IP addresses

- [ ] Check node group status in AWS console
  - **Command**: `aws eks describe-nodegroup --cluster-name petclinic-cluster --nodegroup-name petclinic_nodes`
  - **Details**: Verifies node group is in ACTIVE state

### Database Layer
- [ ] Create RDS subnet group
  - **Command**: `cat > rds.tf << EOF
resource "aws_db_subnet_group" "petclinic" {
  name       = "petclinic-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "PetClinic DB subnet group"
    Environment = "production"
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "petclinic-rds-"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "petclinic-rds-sg"
    Environment = "production"
  }
}

resource "aws_db_instance" "petclinic" {
  identifier = "petclinic-mysql"
  
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  storage_encrypted    = true
  
  db_name  = "petclinic"
  username = "petclinic"
  password = "ChangeMeInProduction123!"
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.petclinic.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  multi_az               = true
  publicly_accessible    = false
  
  skip_final_snapshot = false
  final_snapshot_identifier = "petclinic-final-snapshot"
  
  tags = {
    Name = "petclinic-mysql"
    Environment = "production"
  }
}
EOF`
  - **Details**: Creates MySQL RDS instance with Multi-AZ for high availability

- [ ] Provision RDS MySQL instance with Multi-AZ
  - **Command**: `terraform plan -target=aws_db_instance.petclinic && terraform apply -target=aws_db_instance.petclinic`
  - **Details**: Creates managed MySQL database with automated backups
  - **Junior's Safety Note**: NEVER run terraform destroy on RDS module in production

- [ ] Create database initialization script
  - **Command**: `cat > k8s/db-init-job.yaml << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: db-init
  namespace: petclinic
spec:
  template:
    spec:
      containers:
      - name: mysql-client
        image: mysql:8.0
        command: ["/bin/sh"]
        args: ["-c", "mysql -h \$DB_HOST -u \$DB_USER -p\$DB_PASSWORD \$DB_NAME < /scripts/schema.sql"]
        env:
        - name: DB_HOST
          value: "petclinic-mysql.region.rds.amazonaws.com"
        - name: DB_USER
          value: "petclinic"
        - name: DB_PASSWORD
          value: "ChangeMeInProduction123!"
        - name: DB_NAME
          value: "petclinic"
        volumeMounts:
        - name: db-scripts
          mountPath: /scripts
      volumes:
      - name: db-scripts
        configMap:
          name: db-init-scripts
      restartPolicy: OnFailure
EOF`
  - **Details**: Kubernetes job to initialize database schema

- [ ] Create database schemas
  - **Command**: `kubectl apply -f k8s/db-init-job.yaml`
  - **Details**: Runs database initialization scripts

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