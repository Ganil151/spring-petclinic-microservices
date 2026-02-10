# EC2 Instance Module

This module provisions a standalone EC2 instance with an associated security group. It is specifically designed to host DevOps tools mentioned in the `DEPLOYMENT_CHECKLIST.md`, such as **Jenkins Masters** and **SonarQube Servers**.

## Features
- Standard EC2 instance using **Amazon Linux 2023 (AL2023)** by default (via AMI selection).
- Support for **IAM Instance Profiles** to grant permissions to Jenkins/SonarQube.
- **Secondary EBS Volumes** (GP3) for persistent application data (e.g., `/var/lib/jenkins`).
- Automatic security group creation with configurable SSH access.
- Encrypted GP3 root volumes.

## Usage

```hcl
# Example: Provisioning a Jenkins Master as per Topology Allocation
module "jenkins_master" {
  source = "../../modules/ec2"

  project_name         = "petclinic"
  environment          = "dev"
  instance_name        = "jenkins-master"
  ami_id               = "ami-0c1fe732b5494dc14" # AL2023 
  instance_type        = "t3.large"              # Jenkins Master requirement
  vpc_id               = module.vpc.vpc_id
  subnet_id            = module.vpc.public_subnet_ids[0]
  iam_instance_profile = "JenkinsAdminRole"      # Grants access to ECR/EKS
  extra_volume_size    = 50                      # For Jenkins home directory
  associate_public_ip  = true
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
| iam_instance_profile | IAM role to attach to the instance | `string` | `null` | no |
| extra_volume_size | Size of secondary volume (GB) | `number` | `0` | no |
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
