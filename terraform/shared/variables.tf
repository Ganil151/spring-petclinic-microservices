# Shared variable definitions
# This file is symlinked to each environment to maintain consistent definitions

# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================
variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "data_source_path" {
  description = "Path to the global data module"
  type        = string
  default     = "../../global/data"
}

# ============================================================================
# NETWORKING CONFIGURATION
# ============================================================================
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public subnets CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnets CIDR blocks"
  type        = list(string)
}

variable "data_availability_zone" {
  description = "Availability zones for resource distribution"
  type        = list(string)
}

variable "allowed_cidr_blocks" {
  description = "Allowed CIDR blocks for security group access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ingress_ports" {
  description = "List of ports to allow ingress traffic for"
  type        = list(number)
  default     = []
}

variable "ingress_rules" {
  description = "Map of complex ingress rules for security groups"
  type = map(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = {}
}

# ============================================================================
# EKS CONFIGURATION
# ============================================================================
variable "cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.31"
}

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_username" {
  description = "RDS admin username"
  type        = string
  default     = "petclinic"
}

variable "db_password" {
  description = "RDS admin password"
  type        = string
  sensitive   = true
  default     = null
}

# ============================================================================
# EC2 INSTANCE CONFIGURATION
# ============================================================================
variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name for EC2 instances"
  type        = string
  default     = null
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "Associate public IP with EC2 instances"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "User data script for EC2 instances"
  type        = string
  default     = ""
}

variable "user_data_replace_on_change" {
  description = "Whether to replace the user data when launching the instance"
  type        = bool
  default     = false
}

variable "iam_instance_profile" {
  description = "IAM instance profile for EC2 instances"
  type        = string
  default     = null
}

# ============================================================================
# JENKINS MASTER CONFIGURATION
# ============================================================================
variable "jenkins_instance_name" {
  description = "Name for the Jenkins EC2 instance"
  type        = string
  default     = "jenkins-master"
}

variable "jenkins_instance_type" {
  description = "EC2 instance type for Jenkins"
  type        = string
  default     = "t3.large"
}

variable "jenkins_root_volume_size" {
  description = "Root volume size for Jenkins instance in GB"
  type        = number
  default     = 20
}

variable "jenkins_extra_volume_size" {
  description = "Extra volume size for Jenkins instance in GB (0 to disable)"
  type        = number
  default     = 0
}

# ============================================================================
# SONARQUBE SERVER CONFIGURATION
# ============================================================================
variable "sonarqube_instance_name" {
  description = "Name for the SonarQube EC2 instance"
  type        = string
  default     = "sonarqube-server"
}

variable "sonarqube_instance_type" {
  description = "EC2 instance type for SonarQube"
  type        = string
  default     = "t2.medium"
}

variable "sonarqube_root_volume_size" {
  description = "Root volume size for SonarQube instance in GB"
  type        = number
  default     = 20
}

variable "sonarqube_extra_volume_size" {
  description = "Extra volume size for SonarQube instance in GB (0 to disable)"
  type        = number
  default     = 0
}

# ============================================================================
# WORKER INSTANCE CONFIGURATION
# ============================================================================
variable "worker_instance_name" {
  description = "Name for the Worker EC2 instance"
  type        = string
  default     = "worker-node"
}

variable "worker_instance_type" {
  description = "EC2 instance type for Worker"
  type        = string
  default     = "t3.medium"
}

variable "worker_root_volume_size" {
  description = "Root volume size for Worker instance in GB"
  type        = number
  default     = 30
}

variable "worker_extra_volume_size" {
  description = "Extra volume size for Worker instance in GB (0 to disable)"
  type        = number
  default     = 0
}
# ============================================================================
# ANSIBLE CONFIGURATION
# ============================================================================
variable "run_ansible" {
  description = "Whether to automatically trigger Ansible playbook execution after inventory generation"
  type        = bool
  default     = false
}
