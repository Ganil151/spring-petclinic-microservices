# EC2 Instance Module

This module provisions a standalone EC2 instance with an associated security group. It is designed for simple compute needs like Bastion hosts, Jenkins masters, or SonarQube servers.

## Features
- Standard EC2 instance with custom AMIs and instance types.
- Automatic creation of a security group with SSH (port 22) access.
- Root volume configuration (GP3, encryption enabled).
- Support for User Data scripts.
- Optional public IP association.

## Usage

```hcl
module "jenkins_master" {
  source = "../../modules/ec2"

  project_name        = "petclinic"
  environment         = "dev"
  instance_name       = "jenkins-master"
  ami_id              = "ami-0c1fe732b5494dc14"
  instance_type       = "t3.medium"
  vpc_id              = module.vpc.vpc_id
  subnet_id           = module.vpc.public_subnet_ids[0]
  associate_public_ip = true
  allowed_cidr_blocks = ["203.0.113.0/24"] # Restrict to your office IP
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for tagging | `string` | n/a | yes |
| environment | Environment name for tagging | `string` | n/a | yes |
| instance_name | Name tag for the EC2 instance | `string` | n/a | yes |
| ami_id | AMI ID to use for the instance | `string` | n/a | yes |
| instance_type | The type of instance to start | `string` | `t3.micro` | no |
| vpc_id | The VPC ID for the instance | `string` | n/a | yes |
| subnet_id | The Subnet ID for the instance | `string` | n/a | yes |
| key_name | SSH key pair name | `string` | `null` | no |
| associate_public_ip | Associate a public IP | `bool` | `false` | no |
| user_data | Startup script | `string` | `""` | no |
| root_volume_size | Size of root volume (GB) | `number` | `20` | no |
| allowed_cidr_blocks | CIDR blocks for SSH access | `list(string)` | `["0.0.0.0/0"]` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | The ID of the EC2 instance |
| public_ip | The public IP of the instance |
| private_ip | The private IP of the instance |
| security_group_id | The ID of the security group |
