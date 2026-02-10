variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "subnet_cidr" {
  type        = string
  description = "The CIDR block for the subnet"
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
