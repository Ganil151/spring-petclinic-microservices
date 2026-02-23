variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "inventory_file_path" {
  description = "Path to Ansible inventory file"
  type        = string
}

variable "ansible_working_dir" {
  description = "Ansible working directory"
  type        = string
}

variable "jenkins_master_ip" {
  description = "Jenkins master public IP"
  type        = string
}

variable "jenkins_master_priv" {
  description = "Jenkins master private IP"
  type        = string
}

variable "worker_node_ips" {
  description = "Worker node public IPs"
  type        = list(string)
}

variable "worker_node_priv_ips" {
  description = "Worker node private IPs"
  type        = list(string)
}

variable "sonarqube_ip" {
  description = "SonarQube public IP"
  type        = string
}

variable "sonarqube_priv" {
  description = "SonarQube private IP"
  type        = string
}

variable "ssh_user" {
  description = "SSH user for Ansible"
  type        = string
  default     = "ec2-user"
}

variable "ssh_key_file" {
  description = "SSH private key file path"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = ""
}

variable "cluster_suffix" {
  description = "Cluster suffix (primary/secondary)"
  type        = string
  default     = "primary"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "run_ansible" {
  description = "Run Ansible playbooks automatically"
  type        = bool
  default     = false
}

variable "bastion_ip" {
  description = "Bastion host public IP"
  type        = string
  default     = ""
}

variable "bastion_priv_ip" {
  description = "Bastion host private IP"
  type        = string
  default     = ""
}

variable "enable_ansible_inventory" {
  description = "Enable Ansible inventory generation"
  type        = bool
  default     = true
}

variable "run_ansible" {
  description = "Whether to run Ansible playbooks automatically after generation"
  type        = bool
  default     = false
}
