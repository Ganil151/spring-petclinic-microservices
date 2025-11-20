output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.master_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}


