environment = "dev"
aws_region  = "us-west-2"

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS Configuration
cluster_name        = "petclinic-dev-cluster"
cluster_version     = "1.29"
node_instance_types = ["t3.medium"]
node_desired_size   = 3
node_min_size       = 2
node_max_size       = 6

# RDS Configuration
db_name           = "petclinic"
db_username       = "petclinic"
db_instance_class = "db.t3.micro"
allocated_storage = 20

# Monitoring
sns_email = "ganilbatistyan@gmail..com"
