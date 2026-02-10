variable "aws_region" {}
variable "Environment" {}
variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources into"
}

variable "Environment" {
  type        = string
  description = "The deployment environment (e.g., dev, prod, staging)"
}

variable "bucket_name" {
  default = "petclinic-terraform-state-17a538b3"
  type        = string
  description = "The name of the S3 bucket for Terraform state"
  default     = "petclinic-terraform-state-17a538b3"
}
variable "spms_vpc_cidr" {}
variable "spms_subnet_cidr" {}

variable "spms_vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "spms_subnet_cidr" {
  type        = string
  description = "The CIDR block for the subnet"
}