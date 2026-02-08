resource "aws_vpc" "spm_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  instance_tenancy = "default"

  tags = {
    Name = "SPM VPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.spm_vpc.id

  tags = {
    Name = "SPM IGW"
  }
  
}

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.spm_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "SPM RTB"
  }
  
}
resource "aws_route_table_association" "rta" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.rtb.id

}
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.spm_vpc.id
  cidr_block = var.public_subnets_cidr
  availability_zone = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "SPM Public Subnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id = aws_vpc.spm_vpc.id
  cidr_block = var.private_subnets_cidr
  availability_zone = var.availability_zones[0]
  map_public_ip_on_launch = false

  tags = {
    Name = "SPM Private Subnet"
  }
}