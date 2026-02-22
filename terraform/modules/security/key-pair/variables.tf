variable "key_pair_name" {
  description = "Name of the key pair"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "spring-petclinic"
}

variable "public_key" {
  description = "Public key material (optional - if not provided, a new key will be generated)"
  type        = string
  default     = null
}

variable "private_key_filename" {
  description = "Filename to save the private key (empty = don't save)"
  type        = string
  default     = ""
}

variable "store_in_ssm" {
  description = "Whether to store the private key in AWS Systems Manager Parameter Store"
  type        = bool
  default     = false
}

variable "ssm_parameter_name" {
  description = "SSM parameter name for the private key"
  type        = string
  default     = ""
}
