output "key_name" {
  value = aws_key_pair.spms_dev.key_name
}

output "public_key" {
  value = aws_key_pair.spms_dev.public_key
}

output "private_key" {
  value = local_file.spms_dev.content
}

output "tags" {
  value = aws_key_pair.spms_dev.tags
}

output "private_key_path" {
  value = local_file.spms_dev.filename
}

output "private_key_pem" {
  value = tls_private_key.spms_dev.private_key_pem
}
  
output "private_key_pem_path" {
  value = local_file.spms_dev.filename
}