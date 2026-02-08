output "vpc_id" {
  value = aws_vpc.spm_vpc.id
}

output "igw_id" {
  value = aws_internet_gateway.igw.id 

}

output "public_subnet_id" {
  value = aws_subnet.public.id  
}

output "private_subnet_id" {
  value = aws_subnet.private.id  
}

