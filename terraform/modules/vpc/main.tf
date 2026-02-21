/**
 * VPC Module for Spring PetClinic Microservices
 * Implements network segmentation with public/private subnets
 */

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "name" {
  description = "Name for the VPC resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets_cidr" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block                       = var.cidr_block
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = false

  tags = {
    Name        = "${var.name}-vpc"
    Environment = var.environment
    Terraform   = "true"
    Project     = "spring-petclinic"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.name}-igw"
    Environment = var.environment
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.name}-public-subnet-${count.index + 1}"
    Environment              = var.environment
    SubnetType               = "Public"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.private_subnets_cidr, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.name}-private-subnet-${count.index + 1}"
    Environment                       = var.environment
    SubnetType                        = "Private"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# NAT Gateways for Private Subnets
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"
  tags = {
    Name        = "${var.name}-nat-eip-${count.index + 1}"
    Environment = var.environment
  }
  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count             = length(var.availability_zones)
  allocation_id     = element(aws_eip.nat[*].id, count.index)
  subnet_id         = element(aws_subnet.public[*].id, count.index)
  connectivity_type = "public"

  tags = {
    Name        = "${var.name}-nat-gateway-${count.index + 1}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.name}-public-route-table"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.main[*].id, count.index)
  }

  tags = {
    Name        = "${var.name}-private-route-table-${count.index + 1}"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.availability_zones)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(aws_route_table.private[*].id, count.index)
}

# Security Groups
resource "aws_security_group" "eks_node_sg" {
  name_prefix = "${var.name}-eks-node-sg"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.name}-eks-node-security-group"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "eks_node_ingress_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_node_sg.id
  security_group_id        = aws_security_group.eks_node_sg.id
}

resource "aws_security_group_rule" "eks_node_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_node_sg.id
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "${var.name}-rds-sg"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.name}-rds-security-group"
    Environment = var.environment
  }
}

resource "aws_security_group_rule" "rds_mysql_ingress" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_node_sg.id
  security_group_id        = aws_security_group.rds_sg.id
}

resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds_sg.id
}
