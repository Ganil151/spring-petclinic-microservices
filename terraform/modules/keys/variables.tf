variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "key_name" {
  description = "Key pair name"
  type        = string
}

variable "output_path" {
  description = "The path where the .pem file should be written"
  type        = string
  default     = "."
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
