output "bastion_instance_id" {
  description = "Bastion host instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_public_ip" {
  description = "Bastion host public IP"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Bastion host private IP"
  value       = aws_instance.bastion.private_ip
}

output "bastion_eip" {
  description = "Bastion host Elastic IP"
  value       = aws_eip.bastion.public_ip
}

output "jenkins_instance_id" {
  description = "Jenkins master instance ID"
  value       = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  description = "Jenkins master public IP"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_private_ip" {
  description = "Jenkins master private IP"
  value       = aws_instance.jenkins.private_ip
}

output "sonarqube_instance_id" {
  description = "SonarQube instance ID"
  value       = aws_instance.sonarqube.id
}

output "sonarqube_public_ip" {
  description = "SonarQube public IP"
  value       = aws_instance.sonarqube.public_ip
}

output "sonarqube_private_ip" {
  description = "SonarQube private IP"
  value       = aws_instance.sonarqube.private_ip
}

output "worker_node_ids" {
  description = "List of worker node instance IDs"
  value       = aws_instance.worker_nodes[*].id
}

output "worker_node_public_ips" {
  description = "List of worker node public IPs"
  value       = aws_instance.worker_nodes[*].public_ip
}

output "worker_node_private_ips" {
  description = "List of worker node private IPs"
  value       = aws_instance.worker_nodes[*].private_ip
}

output "all_instance_ids" {
  description = "Map of all instance IDs"
  value = {
    bastion     = aws_instance.bastion.id
    jenkins     = aws_instance.jenkins.id
    sonarqube   = aws_instance.sonarqube.id
    worker_nodes = aws_instance.worker_nodes[*].id
  }
}
