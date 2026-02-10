variable "db_name" {
  type        = string
  description = "Name of the database"
}

variable "db_user" {
  type        = string
  description = "Database username"
}

variable "db_password" {
  type        = string
  description = "Database password"
  sensitive   = true
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for DB subnet group"
}

variable "environment" {
  type        = string
}

variable "project_name" {
  type        = string
}

variable "allowed_security_groups" {
  type        = list(string)
  description = "Security groups allowed to connect to RDS"
  default     = []
}
