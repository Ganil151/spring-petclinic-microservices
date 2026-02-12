# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================
project_name = "Petclinic"
environment  = "dev"
aws_region   = "us-east-1"

# ============================================================================
# NETWORKING CONFIGURATION
# ============================================================================
vpc_cidr               = "10.0.0.0/16"
public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs   = ["10.0.10.0/24", "10.0.11.0/24"]
data_availability_zone = ["us-east-1a", "us-east-1b"]
allowed_cidr_blocks    = ["0.0.0.0/0"]

# ============================================================================
# EKS CONFIGURATION
# ============================================================================
cluster_version = "1.31"

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_username          = "petclinic"

# ============================================================================
# EC2 INSTANCE CONFIGURATION
# ============================================================================
ami = "ami-0c1fe732b5494dc14"

# Common EC2 Settings
key_name            = "spms-pro"
associate_public_ip = true
user_data           = ""
iam_instance_profile = ""

# Jenkins Master Configuration
jenkins_instance_name      = "jenkins-master"
jenkins_instance_type      = "t3.large"
jenkins_root_volume_size   = 20
jenkins_extra_volume_size  = 10

# SonarQube Server Configuration
sonarqube_instance_name       = "sonarqube-server"
sonarqube_instance_type       = "t2.medium"
sonarqube_root_volume_size    = 20
sonarqube_extra_volume_size   = 0