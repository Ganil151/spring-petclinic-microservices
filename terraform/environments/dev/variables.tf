variable "project_name" {
  description = "Project name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

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
  description = "Availability zones"
  type        = list(string)
}

variable "cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.31"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage"
  type        = number
  default     = 20
}

variable "db_username" {
  description = "RDS admin username"
  type        = string
  default     = "petclinic"
}

variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "Allowed CIDR blocks for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ingress_ports" {
  description = "List of ports to allow ingress traffic for"
  type        = list(number)
  default     = []
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
  description = "Root volume size for Jenkins instance"
  type        = number
  default     = 20
}

variable "jenkins_extra_volume_size" {
  description = "Extra volume size for Jenkins instance"
  type        = number
  default     = 0
}

variable "user_data_replace" {
  description = "Whether to replace the user data when launching the instance"
  type        = bool
  default     = false
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
  description = "Root volume size for SonarQube instance"
  type        = number
  default     = 20
}

variable "sonarqube_extra_volume_size" {
  description = "Extra volume size for SonarQube instance (0 to disable)"
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
# COMMON EC2 CONFIGURATION
# ============================================================================
variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "Associate public IP"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "Startup script"
  type        = string
  default     = ""
}

variable "iam_instance_profile" {
  description = "IAM profile"
  type        = string
  default     = null
}
