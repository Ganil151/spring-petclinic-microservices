# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================
project_name = "Petclinic"
environment  = "staging"
aws_region   = "us-east-1"

# ============================================================================
# NETWORKING CONFIGURATION
# ============================================================================
vpc_cidr               = "10.1.0.0/16"
public_subnet_cidrs    = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs   = ["10.1.10.0/24", "10.1.11.0/24"]
data_availability_zone = ["us-east-1a", "us-east-1b"]
allowed_cidr_blocks    = ["0.0.0.0/0"]

# Allowed ports for security groups
ingress_ports = [
  22,   # SSH
  80,   # HTTP
  443,  # HTTPS
  3306, # MySQL/RDS
  8080, # Jenkins / API Gateway
  9000, # SonarQube
  8761, # Discovery Server (Eureka)
  8888, # Config Server
  9090, # Admin Server (Spring Boot Admin)
  8081, # Customers Service
  8082, # Vets Service
  8083, # Visits Service
  9091, # Prometheus
  3000, # Grafana
  9411  # Zipkin
]

# ============================================================================
# EKS CONFIGURATION
# ============================================================================
cluster_version = "1.31"

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================
db_instance_class    = "db.t3.small"
db_allocated_storage = 50
db_username          = "petclinic"

# ============================================================================
# EC2 INSTANCE CONFIGURATION
# ============================================================================
ami = "ami-0c1fe732b5494dc14" # Update with appropriate AMI for your region

# Common EC2 Settings
key_name             = "petclinic-staging-key"
associate_public_ip  = true
user_data            = ""
iam_instance_profile = ""

# Jenkins Master Configuration
jenkins_instance_name     = "jenkins-master"
jenkins_instance_type     = "t3.large"
jenkins_root_volume_size  = 30
jenkins_extra_volume_size = 20

# SonarQube Server Configuration
sonarqube_instance_name     = "sonarqube-server"
sonarqube_instance_type     = "t2.medium"
sonarqube_root_volume_size  = 30
sonarqube_extra_volume_size = 10
