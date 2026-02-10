variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the cluster will be deployed"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS nodes"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs for EKS Control Plane (optional/logging)"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.31"
}
