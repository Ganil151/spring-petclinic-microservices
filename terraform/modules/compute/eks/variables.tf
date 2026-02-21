variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "cluster_suffix" {
  description = "Suffix for the EKS cluster name to avoid conflicts"
  type        = string
  default     = "primary"
}

variable "cluster_role" {
  description = "The specific role/purpose of this EKS cluster (e.g., app, data, batch)"
  type        = string
  default     = "general"
}

variable "vpc_id" {
  description = "VPC ID for EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster"
  type        = list(string)
}

variable "cluster_version" {
  description = "EKS Cluster version"
  type        = string
  default     = "1.31"
}

variable "node_group_instance_types" {
  description = "Instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_group_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "admin_role_arns" {
  description = "List of IAM ARNs to grant cluster administrator access"
  type        = list(string)
  default     = []
}

variable "cluster_viewer_role_arns" {
  description = "List of IAM ARNs to grant cluster viewer access"
  type        = list(string)
  default     = []
}

variable "kubernetes_groups" {
  description = "List of Kubernetes groups to associate with the access entries"
  type        = list(string)
  default     = []
}
