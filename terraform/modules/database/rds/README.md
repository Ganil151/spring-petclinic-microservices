# RDS Module (MySQL)

This module provisions a managed MySQL RDS instance as the persistence layer for the PetClinic microservices.

## Features
- AWS-managed MySQL 8.0 instance.
- Multi-AZ support for high availability (per SRE standards).
- GP3 storage with configurable allocation.
- Dedicated security group with restricted ingress (Port 3306).
- Automated backup retention.

## Usage

```hcl
module "rds" {
  source = "../../modules/database/rds"

  project_name      = "petclinic"
  environment       = "dev"
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  db_instance_class = "db.t3.micro"
  db_username       = "petclinic"
  db_password       = "YourSecurePassword" # Use secrets in production!
  multi_az          = false                # Set to true for staging/prod
  
  # Allow access from EKS nodes and DevOps tools
  allowed_security_group_ids = [module.sg.ec2_sg_id]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for tagging | `string` | n/a | yes |
| environment | Environment name for tagging | `string` | n/a | yes |
| vpc_id | VPC ID for security group | `string` | n/a | yes |
| subnet_ids | VPC Subnet IDs for subnet group | `list(string)` | n/a | yes |
| db_instance_class | Instance type | `string` | `db.t3.micro` | no |
| db_allocated_storage | Storage size (GB) | `number` | `20` | no |
| db_name | Database name | `string` | `petclinic` | no |
| db_username | Database master username | `string` | n/a | yes |
| db_password | Database master password | `string` | n/a | yes |
| multi_az | Enable Multi-AZ | `bool` | `false` | no |
| backup_retention_period | Days to retain backups | `number` | `7` | no |
| skip_final_snapshot | Skip snapshot on delete | `bool` | `true` | no |
| allowed_security_group_ids | Allowed SGs for ingress | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| rds_endpoint | Connection endpoint |
| rds_address | Hostname of the instance |
| rds_port | Port number (3306) |
| rds_security_group_id | Security group ID |
