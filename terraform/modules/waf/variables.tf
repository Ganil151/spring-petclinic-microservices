variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "scope" {
  description = "The scope of the WAF. Use REGIONAL for ALB and CLOUDFRONT for CloudFront"
  type        = string
  default     = "REGIONAL"
}
