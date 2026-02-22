variable "vpc_id" {
  description = "VPC ID where instances will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_ids" {
  description = "List of subnet IDs for instances"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
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

variable "jenkins_instance_type" {
  description = "Jenkins master instance type"
  type        = string
  default     = "t3.medium"
}

variable "sonarqube_instance_type" {
  description = "SonarQube instance type"
  type        = string
  default     = "t3.medium"
}

variable "worker_node_type" {
  description = "Worker node instance type"
  type        = string
  default     = "t3.large"
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
