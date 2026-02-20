variable "project_name" { type = string }
variable "environment" { type = string }

variable "jenkins_master_ip" {
  type    = string
  default = "N/A"
}

variable "jenkins_master_priv" {
  type    = string
  default = "N/A"
}

variable "worker_node_ips" {
  type    = list(string)
  default = []
}

variable "worker_node_priv_ips" {
  type    = list(string)
  default = []
}

variable "sonarqube_ip" {
  type    = string
  default = "N/A"
}

variable "sonarqube_priv" {
  type    = string
  default = "N/A"
}

variable "ssh_user" {
  type    = string
  default = "ec2-user"
}

variable "ssh_key_file" {
  type    = string
  default = null
}

variable "eks_cluster_name" {
  type    = string
  default = "N/A"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type    = string
  default = "N/A"
}

variable "account_id" {
  type    = string
  default = "N/A"
}

variable "inventory_file_path" {
  type    = string
  description = "Path where the inventory file should be created"
}

variable "ansible_working_dir" {
  type    = string
  description = "Working directory for ansible commands"
}

variable "run_ansible" {
  type    = bool
  default = false
}
