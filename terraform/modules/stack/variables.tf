variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "The CIDR blocks for the public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "The CIDR blocks for the private subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "environment" {
  type        = string
  description = "The deployment environment"
}

variable "project_name" {
  type        = string
  description = "The project name"
  default     = "spring-petclinic"
}

variable "db_name" {
  type        = string
}

variable "db_user" {
  type        = string
}

variable "db_password" {
  type        = string
  sensitive   = true
}
