output "instance_id" {
  description = "The ID of the K8s node instance"
  value       = aws_instance.k8s_node.id
}

output "private_ip" {
  description = "The private IP address of the K8s node"
  value       = aws_instance.k8s_node.private_ip
}

output "public_ip" {
  description = "The public IP address of the K8s node"
  value       = aws_instance.k8s_node.public_ip
}
