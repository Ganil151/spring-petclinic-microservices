# Cluster Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.28"
}

# VPC Configuration
variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Logging
variable "enabled_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# Node Group Configuration (Multiple Node Groups)
variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    desired_size   = number
    max_size       = number
    min_size       = number
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    disk_size      = optional(number, 50)
    labels         = optional(map(string), {})
  }))
  default = {}
}

# Legacy single node group variables (kept for backward compatibility)
variable "node_group_name" {
  description = "Name of the EKS node group (legacy - use node_groups instead)"
  type        = string
  default     = ""
}

variable "desired_size" {
  description = "Desired number of worker nodes (legacy - use node_groups instead)"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes (legacy - use node_groups instead)"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum number of worker nodes (legacy - use node_groups instead)"
  type        = number
  default     = 1
}

variable "instance_types" {
  description = "List of instance types for the node group (legacy - use node_groups instead)"
  type        = list(string)
  default     = ["t3.xlarge"]
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT (legacy - use node_groups instead)"
  type        = string
  default     = "ON_DEMAND"
}

variable "disk_size" {
  description = "Disk size in GiB for worker nodes (legacy - use node_groups instead)"
  type        = number
  default     = 50
}

variable "node_labels" {
  description = "Key-value map of Kubernetes labels (legacy - use node_groups instead)"
  type        = map(string)
  default     = {}
}

# Tags
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
