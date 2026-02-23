output "inventory_content" {
  description = "Generated Ansible inventory content"
  value       = local.inventory_content
  sensitive   = false
}

output "inventory_file_path" {
  description = "Path to generated inventory file"
  value       = var.inventory_file_path
}

output "ansible_targets" {
  description = "Summary of Ansible targets"
  value = {
    jenkins_master    = var.jenkins_master_ip
    sonarqube_server  = var.sonarqube_ip
    worker_nodes      = var.worker_node_ips
    bastion_host      = var.bastion_ip
    total_instances   = length(var.worker_node_ips) + 2 + (var.bastion_ip != "" ? 1 : 0)
  }
}

output "inventory_file_id" {
  description = "ID of the generated inventory file"
  value       = local_file.ansible_inventory[*].id
}

output "ansible_ready" {
  description = "Whether Ansible inventory is ready"
  value       = var.enable_ansible_inventory
}
