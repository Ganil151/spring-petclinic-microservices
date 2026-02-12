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

# Allowed ports for security groups
ingress_rules = {
  # Infrastructure Access
  ssh = {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH access"
  }
  http = {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP access"
  }
  https = {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "HTTPS access"
  }

  # Database
  mysql = {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    description = "MySQL/RDS database access"
  }

  # CI/CD Tools
  jenkins = {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    description = "Jenkins web interface"
  }
  sonarqube = {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    description = "SonarQube web interface"
  }

  # Spring PetClinic Microservices
  api_gateway = {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    description = "API Gateway (Spring Cloud Gateway)"
  }
  discovery_server = {
    from_port   = 8761
    to_port     = 8761
    protocol    = "tcp"
    description = "Discovery Server (Eureka)"
  }
  config_server = {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    description = "Config Server"
  }
  admin_server = {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    description = "Admin Server (Spring Boot Admin)"
  }

  # PetClinic Microservices (individual services)
  customers_service = {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    description = "Customers Service"
  }
  vets_service = {
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    description = "Vets Service"
  }
  visits_service = {
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    description = "Visits Service"
  }

  # Monitoring & Observability
  prometheus = {
    from_port   = 9091
    to_port     = 9091
    protocol    = "tcp"
    description = "Prometheus monitoring"
  }
  grafana = {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    description = "Grafana dashboards"
  }
  zipkin = {
    from_port   = 9411
    to_port     = 9411
    protocol    = "tcp"
    description = "Zipkin distributed tracing"
  }

  # Additional Common Ports
  custom_app_range = {
    from_port   = 8000
    to_port     = 8999
    protocol    = "tcp"
    description = "Custom application port range"
  }
  actuator = {
    from_port   = 9000
    to_port     = 9999
    protocol    = "tcp"
    description = "Spring Boot Actuator endpoints range"
  }
}

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
key_name             = "spms-pro"
associate_public_ip  = true
user_data            = ""
iam_instance_profile = ""

# Jenkins Master Configuration
jenkins_instance_name     = "jenkins-master"
jenkins_instance_type     = "t3.large"
jenkins_root_volume_size  = 20
jenkins_extra_volume_size = 10

# SonarQube Server Configuration
sonarqube_instance_name     = "sonarqube-server"
sonarqube_instance_type     = "t2.medium"
sonarqube_root_volume_size  = 20
sonarqube_extra_volume_size = 0

# Worker Node Configuration
worker_instance_name      = "worker-node-1"
worker_instance_type      = "t3.medium"
worker_root_volume_size   = 30
worker_extra_volume_size  = 0