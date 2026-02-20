variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "ingress_ports" {
  description = "List of ports to allow ingress traffic for"
  type        = list(number)
  default     = []
}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC for internal traffic"
  type        = string
  default     = null
}

variable "ingress_rules" {
  description = "Map of complex ingress rules"
  type = map(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = {}
}

variable "eks_cluster_security_group_id" {
  description = "The security group ID of the EKS cluster to allow communication from EC2"
  type        = string
  default     = null
}
