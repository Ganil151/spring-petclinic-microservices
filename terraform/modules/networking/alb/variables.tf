variable "vpc_id" {
  description = "VPC ID where ALB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ALB (public subnets)"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for ALB (optional - if not provided, one will be created)"
  type        = string
  default     = null
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

variable "alb_name" {
  description = "Name of the ALB"
  type        = string
  default     = ""
}

variable "internal" {
  description = "Whether the ALB is internal"
  type        = bool
  default     = false
}

variable "target_port" {
  description = "Port for target group (microservices)"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/actuator/health"
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed SSH access (for bastion/debugging)"
  type        = list(string)
  default     = []
}

variable "enable_security_group" {
  description = "Whether to create a security group for the ALB"
  type        = bool
  default     = true
}

variable "create_key_pair" {
  description = "Whether to create a new key pair"
  type        = bool
  default     = false
}

variable "key_pair_name" {
  description = "Name of the key pair"
  type        = string
  default     = ""
}

variable "key_pair_public_key" {
  description = "Public key material (optional - if not provided, a new key will be generated)"
  type        = string
  default     = null
}

variable "key_pair_filename" {
  description = "Filename to save the private key (if create_key_pair is true)"
  type        = string
  default     = ""
}
