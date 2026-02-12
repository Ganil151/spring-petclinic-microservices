# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================
project_name = "Petclinic"
environment  = "prod"
aws_region   = "us-east-1"

# ============================================================================
# NETWORKING CONFIGURATION
# ============================================================================
vpc_cidr               = "10.2.0.0/16"
public_subnet_cidrs    = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
private_subnet_cidrs   = ["10.2.10.0/24", "10.2.11.0/24", "10.2.12.0/24"]
data_availability_zone = ["us-east-1a", "us-east-1b", "us-east-1c"]
allowed_cidr_blocks    = ["10.0.0.0/8"]  # Restrict access in production

# ============================================================================
# EKS CONFIGURATION
# ============================================================================
cluster_version = "1.31"

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================
db_instance_class    = "db.r6g.large"  # Production-grade instance
db_allocated_storage = 100
db_username          = "petclinic"

# ============================================================================
# EC2 INSTANCE CONFIGURATION
# ============================================================================
ami = "ami-0c1fe732b5494dc14"  # Update with appropriate AMI for your region

# Common EC2 Settings
key_name            = "petclinic-prod-key"
associate_public_ip = false  # Production instances should be private
user_data           = ""
iam_instance_profile = ""

# Jenkins Master Configuration
jenkins_instance_name      = "jenkins-master"
jenkins_instance_type      = "t3.xlarge"  # Larger for production workloads
jenkins_root_volume_size   = 50
jenkins_extra_volume_size  = 50

# SonarQube Server Configuration
sonarqube_instance_name       = "sonarqube-server"
sonarqube_instance_type       = "t3.large"
sonarqube_root_volume_size    = 50
sonarqube_extra_volume_size   = 30
