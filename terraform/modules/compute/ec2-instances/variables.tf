variable "vpc_id" {
  description = "VPC ID where instances will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (for Bastion/ALB)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (for Jenkins/SonarQube/Workers)"
  type        = list(string)
}

variable "mgmt_security_group_id" {
  description = "Security group ID for Management Tier (Bastion)"
  type        = string
  default     = null
}

variable "app_security_group_id" {
  description = "Security group ID for Application Tier (Microservices)"
  type        = string
  default     = null
}

variable "bashrc_content" {
  description = "Content of the shared .bashrc file"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "spring-petclinic"
}

variable "manage_by" {
  description = "Management Team"
  type        = string
  default     = "Gsmash DevOps Team"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (leave empty for latest Amazon Linux 2)"
  type        = string
  default     = ""
}

variable "bastion_instance_type" {
  description = "Bastion host instance type"
  type        = string
  default     = "t3.micro"
}

variable "bastion_instance_name" {
  description = "Bastion host instance name"
  type        = string
  default     = "bastion-host"
}

variable "bastion_user_data" {
  description = "Bastion host user data"
  type        = string
  default     = ""
}

# =============================================================================
# Jenkins Master Configuration
# =============================================================================
variable "jenkins_instance_name" {
  description = "Jenkins master instance name"
  type        = string
  default     = "jenkins-master"
}

variable "jenkins_instance_type" {
  description = "Jenkins master instance type"
  type        = string
  default     = "t3.large"
}

variable "jenkins_root_volume_size" {
  description = "Jenkins root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "jenkins_extra_volume_size" {
  description = "Jenkins extra EBS volume size for builds/workspace in GB"
  type        = number
  default     = 10
}

variable "jenkins_user_data" {
  description = "Jenkins master user data"
  type        = string
  default     = ""
}

# =============================================================================
# SonarQube Server Configuration
# =============================================================================
variable "sonarqube_instance_name" {
  description = "SonarQube instance name"
  type        = string
  default     = "sonarqube-server"
}

variable "sonarqube_instance_type" {
  description = "SonarQube instance type"
  type        = string
  default     = "t2.medium"
}

variable "sonarqube_root_volume_size" {
  description = "SonarQube root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "sonarqube_extra_volume_size" {
  description = "SonarQube extra EBS volume size for data in GB"
  type        = number
  default     = 0
}

variable "sonarqube_user_data" {
  description = "SonarQube server user data"
  type        = string
  default     = ""
}

# =============================================================================
# Worker Node Configuration
# =============================================================================
variable "worker_instance_name" {
  description = "Worker node instance name prefix"
  type        = string
  default     = "worker-node"
}

variable "worker_node_type" {
  description = "Worker node instance type"
  type        = string
  default     = "t3.medium"
}

variable "worker_root_volume_size" {
  description = "Worker node root EBS volume size in GB"
  type        = number
  default     = 50
}

variable "worker_extra_volume_size" {
  description = "Worker node extra EBS volume size for Docker/images in GB"
  type        = number
  default     = 50
}

variable "worker_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access EC2 instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "worker_user_data" {
  description = "Worker node user data"
  type        = string
  default     = ""
}
