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

variable "key_algorithm" {
  description = "Algorithm for key generation: RSA (default) or ED25519"
  type        = string
  default     = "RSA"

  validation {
    condition     = contains(["ED25519", "RSA"], var.key_algorithm)
    error_message = "key_algorithm must be either ED25519 or RSA."
  }
}

variable "rsa_bits" {
  description = "Number of bits for RSA key (only used if key_algorithm = RSA)"
  type        = number
  default     = 4096

  validation {
    condition     = var.key_algorithm != "RSA" || var.rsa_bits >= 2048
    error_message = "RSA keys must be at least 2048 bits for security."
  }
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

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
