variable "project_name" {
  description = "Project name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "ami_id" {
  description = "AMI ID (optional)"
  type        = string
  default     = ""
}

variable "security_group_id" {
  description = "Security group ID to attach to the node"
  type        = string
}

variable "node_count" {
  description = "Number of nodes"
  type        = number
  default     = 1
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "key_name" {
  description = "SSH key name"
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size"
  type        = number
  default     = 50
}

variable "user_data" {
  description = "Base64 encoded user data"
  type        = string
  default     = ""
}
