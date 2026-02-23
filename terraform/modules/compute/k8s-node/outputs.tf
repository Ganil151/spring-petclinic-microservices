output "instance_ids" {
  description = "IDs of the K8s node instances"
  value       = aws_instance.k8s_node[*].id
}

output "worker_node_private_ips" {
  description = "Private IPs of the worker nodes"
  value       = aws_instance.k8s_node[*].private_ip
}

output "worker_node_public_ips" {
  description = "Public IPs of the worker nodes"
  value       = aws_instance.k8s_node[*].public_ip
}
