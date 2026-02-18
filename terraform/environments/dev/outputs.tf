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

output "jenkins_master_private_ip" {
  description = "Private IP of the Jenkins Master"
  value       = module.jenkins_master.private_ips[0]
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

output "worker_node_private_ips" {
  description = "Private IPs of the Worker Nodes"
  value       = module.worker_node.private_ips
}

# ─── SonarQube ───────────────────────────────────────────────────
output "sonarqube_public_ip" {
  description = "Public IP of the SonarQube Server"
  value       = module.sonarqube_server.public_ips[0]
}

output "sonarqube_private_ip" {
  description = "Private IP of the SonarQube Server"
  value       = module.sonarqube_server.private_ips[0]
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
  value       = "cd ansible && ansible-playbook playbooks/install-tools.yml"
}

# ─── Tool Mapping Summary ───────────────────────────────────────
output "tool_mapping" {
  description = "Which Ansible roles configure which EC2 instance"
  value = {
    jenkins_master = {
      ip    = module.jenkins_master.public_ips[0]
      tools = ["java", "docker", "docker-compose", "awscli", "jenkins", "trivy", "checkov"]
    }
    worker_node = {
      ips   = module.worker_node.public_ips
      tools = ["java", "docker", "docker-compose", "awscli", "maven", "kubectl", "helm"]
    }
    sonarqube = {
      ip    = module.sonarqube_server.public_ips[0]
      tools = ["java", "docker", "docker-compose", "awscli", "sonarqube-stack", "trivy", "checkov"]
    }
  }
}

