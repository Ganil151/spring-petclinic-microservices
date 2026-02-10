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

variable "ingress_rules" {
  description = "Map of ingress rules to create"
  type = map(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))
  default = {}
}
