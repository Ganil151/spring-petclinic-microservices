variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources into"
}

variable "Environment" {
  type        = string
  description = "The deployment environment (e.g., dev, prod, staging)"
}

variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket for Terraform state"
  default     = "petclinic-terraform-state-17a538b3"
}

variable "spms_vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "spms_public_subnet_cidrs" {
  type        = list(string)
  description = "The CIDR blocks for the public subnets"
}

variable "spms_private_subnet_cidrs" {
  type        = list(string)
  description = "The CIDR blocks for the private subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
  default     = ["us-east-1a", "us-east-1b"]
}
