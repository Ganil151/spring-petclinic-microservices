output "key_pair_id" {
  description = "Key pair ID"
  value       = aws_key_pair.main.key_pair_id
}

output "key_pair_name" {
  description = "Key pair name"
  value       = aws_key_pair.main.key_name
}

output "key_pair_arn" {
  description = "Key pair ARN"
  value       = aws_key_pair.main.arn
}

output "private_key_pem" {
  description = "Private key in PEM format (sensitive)"
  value       = var.public_key == null ? tls_private_key.main[0].private_key_pem : null
  sensitive   = true
}

output "public_key_openssh" {
  description = "Public key in OpenSSH format"
  value       = var.public_key != null ? var.public_key : tls_private_key.main[0].public_key_openssh
}

output "ssm_parameter_name" {
  description = "SSM parameter name where private key is stored"
  value       = var.public_key == null && var.store_in_ssm ? aws_ssm_parameter.private_key[0].name : null
}
