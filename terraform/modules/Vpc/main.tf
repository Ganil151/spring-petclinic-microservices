# Availability Zones
data "aws_availability_zones" "available" {}

# Vpc
resource "aws_vpc" "master_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.enable_dns_support
  enable_dns_support   = var.enable_dns_hostnames

  tags = {
    Name = "${var.project_name_1}-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.master_vpc.id
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name = "${var.project_name_1}-public-subnet-${count.index + 1}"
  }

  depends_on = [aws_vpc.master_vpc]
}

# Private Subnet
resource "aws_subnet" "private_subnet" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.master_vpc.id
  cidr_block              = element(var.private_subnet_cidrs, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = {
    Name = "${var.project_name_1}-private-subnet-${count.index + 1}"
  }

  depends_on = [aws_vpc.master_vpc]
}

# Internet Gateway
resource "aws_internet_gateway" "master_igw" {
  vpc_id = aws_vpc.master_vpc.id

  tags = {
    Name = "${var.project_name_1}-igw"
  }

  depends_on = [aws_vpc.master_vpc]
}

# Route Table
resource "aws_route_table" "master_rt" {
  vpc_id = aws_vpc.master_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.master_igw.id
  }

  tags = {
    Name = "${var.project_name_1}-rt"
  }

  depends_on = [aws_vpc.master_vpc]
}

# Route Table Association
resource "aws_route_table_association" "master_rta" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnet[*].id, count.index)
  route_table_id = aws_route_table.master_rt.id
}
