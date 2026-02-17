output "key_name" {
  description = "The key pair name."
  value       = aws_key_pair.this.key_name
}

output "key_pair_id" {
  description = "The key pair ID."
  value       = aws_key_pair.this.key_pair_id
}

output "public_key" {
  description = "The public key material."
  value       = aws_key_pair.this.public_key
}

output "private_key_path" {
  description = "Path to the private key file."
  value       = local_file.private_key.filename
}

output "private_key_pem" {
  description = "The private key content (PEM)."
  value       = tls_private_key.this.private_key_pem
  sensitive   = true
}

