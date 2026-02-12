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

# Allowed ports for security groups (production - internal access only)
ingress_rules = {
  # Infrastructure Access (restricted to internal network)
  ssh = {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    description = "SSH access (internal only)"
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

  # Database (private subnet only)
  mysql = {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    description = "MySQL/RDS database access (internal only)"
  }

  # CI/CD Tools (internal access)
  jenkins = {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    description = "Jenkins web interface (internal only)"
  }
  sonarqube = {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    description = "SonarQube web interface (internal only)"
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
  
  # Monitoring & Observability (internal only)
  prometheus = {
    from_port   = 9091
    to_port     = 9091
    protocol    = "tcp"
    description = "Prometheus monitoring (internal only)"
  }
  grafana = {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    description = "Grafana dashboards (internal only)"
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
