# ALB Module

This module provisions an Application Load Balancer to handle ingress traffic for the PetClinic microservices.

## Features
- Standard L7 Application Load Balancer.
- Automated creation of a default HTTP listener (Port 80).
- Fixed-response or Forward capabilities to Target Groups.
- Integrated with VPC Public Subnets for external reachability.
- Supports deletion protection and custom security groups.

## Usage

```hcl
module "alb" {
  source = "../../modules/networking/alb"

  project_name      = "petclinic"
  environment       = "dev"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_ids = [module.sg.alb_sg_id] # Assuming you created an ALB SG
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| vpc_id | VPC ID | `string` | n/a | yes |
| public_subnet_ids | List of public subnets | `list(string)` | n/a | yes |
| security_group_ids | Security group IDs | `list(string)` | n/a | yes |
| internal | Internal Load Balancer | `bool` | `false` | no |
| enable_deletion_protection | Delete protection | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| alb_arn | Load Balancer ARN |
| alb_dns_name | DNS name (FQDN) |
| alb_zone_id | Route53 Alias Zone ID |
| default_target_group_arn | Default TG ARN |
