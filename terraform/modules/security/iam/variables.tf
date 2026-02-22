variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "spring-petclinic"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to access admin/management interfaces"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "public_cidr_blocks" {
  description = "CIDR blocks allowed to access public endpoints"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "bastion_security_group_id" {
  description = "Security group ID for bastion host (for SSH access)"
  type        = string
  default     = null
}

variable "alb_security_group_id" {
  description = "Security group ID for ALB (for internal traffic)"
  type        = string
  default     = null
}

variable "db_cidr_blocks" {
  description = "CIDR blocks allowed to access the database"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "enable_grafana" {
  description = "Whether to enable Grafana security group"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Whether to enable Prometheus security group"
  type        = bool
  default     = true
}

variable "enable_zipkin" {
  description = "Whether to enable Zipkin tracing security group"
  type        = bool
  default     = true
}
