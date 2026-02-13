variable "project_name" {
  description = "Project name for tagging"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "instance_name" {
  description = "Name tag prefix for the EC2 instance(s)"
  type        = string
}

variable "instance_count" {
  description = "Number of instances to launch"
  type        = number
  default     = 1
}

variable "role" {
  description = "The role of the instance (e.g. master, slave, sonarqube)"
  type        = string
  default     = "worker"
}

variable "ami_id" {
  description = "AMI ID to use for the instance"
  type        = string
}

variable "instance_type" {
  description = "The type of instance to start"
  type        = string
  default     = "t3.micro"
}

variable "subnet_id" {
  description = "The Subnet ID to launch the instance in"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the instance"
  type        = list(string)
}

variable "key_name" {
  description = "The key name of the Key Pair to use for the instance"
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address with the instance"
  type        = bool
  default     = false
}

variable "user_data" {
  description = "User data to provide when launching the instance"
  type        = string
  default     = false
}

variable "user_data_replace_on_change" {
  description = "Whether to replace the user data when launching the instance"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
}

variable "iam_instance_profile" {
  description = "The IAM Instance Profile to launch the instance with"
  type        = string
  default     = null
}

variable "extra_volume_size" {
  description = "Size of an additional EBS volume in GB (set to 0 to disable)"
  type        = number
  default     = 0
}
