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

variable "bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
}

variable "dynamodb_table" {
  description = "DynamoDB table name for Terraform locks"
  type        = string
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
