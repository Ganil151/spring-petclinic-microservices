# Project Names
variable "project_name_1" {
  description = "Dynamic project name"
  type        = string

}
variable "project_name_2" {
  description = "Dynamic project name"
  type        = string

}
variable "project_name_3" {
  description = "Dynamic project name"
  type        = string

}
variable "project_name_4" {
  description = "Dynamic project name"
  type        = string

}

# Environment
variable "environment" {
  description = "The environment for the resources (e.g., dev, prod)"
  type        = string
}


# Vpc
variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}
variable "subnet_cidr_block" {
  description = "The cidr block of the subnet."
  type        = string
}
variable "vpc_cidr_block" {
  description = "The cidr block of the VPC."
  type        = string
}
variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}
variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs"
  type        = list(string)
}
variable "enable_dns_support" {
  description = "Enable DNS support"
  type        = bool
}
variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames"
  type        = bool
}
variable "map_public_ip_on_launch" {
  description = "Map a public IP address for the subnet instances"
  type        = bool
}

# Security Group
variable "ingress_rules" {
  description = "List of ingress ports to allow"
  type        = list(number)
}

variable "egress_rules" {
  description = "List of egress ports (not used directly in this example)"
  type        = list(number)
}

# Keys
variable "key_name" {
  description = "The key name to use for the instance"
  type        = string
}

# EC2
variable "ami" {
  description = "The AMI ID to use for the EC2 instance"
  type        = string
}
variable "instance_type" {
  description = "The type of EC2 instance to run"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet where the EC2 instance will be created"
  type        = string
}

variable "user_data" {
  description = "The user data to pass to the EC2 instance"
  type        = string

}
variable "user_data_replace_on_change" {
  description = "Whether to replace the user data if it changes"
  type        = bool
}

variable "security_group_ids" {
  description = "The security group IDs to associate with the EC2 instance"
  type        = list(string)
}

