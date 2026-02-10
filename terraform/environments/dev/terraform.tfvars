# General Configuration
project_name = "Petclinic"
environment  = "dev"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr               = "10.0.0.0/16"
public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs   = ["10.0.10.0/24", "10.0.11.0/24"]
data_availability_zone = ["us-east-1a", "us-east-1b"]

# EKS Configuration
cluster_version = "1.31"

# Database Configuration
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_username          = "petclinic"

# Infrastructure Configuration
ami = "ami-0c1fe732b5494dc14"

# EC2 Configuration
instance_type = "t3.micro"
key_name      = "petclinic-key"
associate_public_ip = true
user_data     = ""
iam_instance_profile = ""
root_volume_size = 20
allowed_cidr_blocks = ["0.0.0.0/0"]
extra_volume_size = 0
  