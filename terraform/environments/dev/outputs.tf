# ───────────────────────────────────────────────────────────────────
# Terraform Outputs — Dev Environment
# ───────────────────────────────────────────────────────────────────
# These outputs feed into Ansible, CI/CD pipelines, and documentation.

# ─── Networking ───────────────────────────────────────────────────
output "vpc_id" {
  description = "The VPC ID"
  value       = module.vpc.vpc_id
}

# ─── Jenkins Master ──────────────────────────────────────────────
output "jenkins_master_public_ip" {
  description = "Public IP of the Jenkins Master"
  value       = module.jenkins_master.public_ips[0]
}

output "jenkins_master_url" {
  description = "Jenkins Web UI URL"
  value       = "http://${module.jenkins_master.public_ips[0]}:8080"
}

# ─── Worker Nodes ────────────────────────────────────────────────
output "worker_node_public_ips" {
  description = "Public IPs of the Worker Nodes"
  value       = module.worker_node.public_ips
}

# ─── SonarQube ───────────────────────────────────────────────────
output "sonarqube_public_ip" {
  description = "Public IP of the SonarQube Server"
  value       = module.sonarqube_server.public_ips[0]
}

output "sonarqube_url" {
  description = "SonarQube Web UI URL"
  value       = "http://${module.sonarqube_server.public_ips[0]}:9000"
}

# ─── Ansible Integration ────────────────────────────────────────
output "ansible_inventory_path" {
  description = "Path to the Terraform-generated Ansible inventory"
  value       = local_file.ansible_inventory.filename
}

output "ansible_command" {
  description = "Ready-to-run Ansible command"
  value       = "ansible-playbook -i ${local_file.ansible_inventory.filename} ansible/playbooks/install-tools.yml"
}
