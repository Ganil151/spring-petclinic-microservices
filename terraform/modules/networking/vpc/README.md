# VPC Module

This module provisions a standard VPC with public and private subnets across multiple availability zones.

## Features
- VPC with DNS support and hostnames.
- Public subnets for Internet-facing resources.
- Private subnets for application and database resources.
- Internet Gateway for public connectivity.
- NAT Gateway (optional, enabled by default) for private subnet egress.
- Routing tables and associations for all subnets.
- EKS-ready tagging for subnet discovery.

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name        = "my-project"
  environment         = "dev"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones  = ["us-east-1a", "us-east-1b"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for tagging | `string` | n/a | yes |
| environment | Environment name for tagging | `string` | n/a | yes |
| vpc_cidr | CIDR block for the VPC | `string` | n/a | yes |
| public_subnet_cidrs | List of CIDR blocks for public subnets | `list(string)` | n/a | yes |
| private_subnet_cidrs | List of CIDR blocks for private subnets | `list(string)` | n/a | yes |
| availability_zones | List of availability zones to use | `list(string)` | n/a | yes |
| enable_nat_gateway | Enable NAT Gateway for private subnets | `bool` | `true` | no |
| single_nat_gateway | Use a single NAT Gateway for all private subnets | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | The ID of the VPC |
| vpc_cidr_block | The CIDR block of the VPC |
| public_subnet_ids | List of IDs of public subnets |
| private_subnet_ids | List of IDs of private subnets |
| nat_gateway_ips | List of public Elastic IPs created for AWS NAT Gateway |
