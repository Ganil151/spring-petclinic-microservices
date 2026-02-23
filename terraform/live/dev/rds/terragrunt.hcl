# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Link to the actual Terraform code
terraform {
  source = "../../../modules/database/rds"
}

# Pull data from the VPC module
dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000"
    vpc_cidr        = "10.0.0.0/16"
    private_subnets = ["subnet-00000001", "subnet-00000002"]
  }
}

# Pull data from the security module
dependency "security" {
  config_path = "../security-groups"
  mock_outputs = {
    data_sg_id = "sg-10000003"
  }
}

# Pass inputs to the Terraform module
inputs = {
  vpc_id       = dependency.vpc.outputs.vpc_id
  vpc_cidr     = dependency.vpc.outputs.vpc_cidr
  subnet_ids   = dependency.vpc.outputs.private_subnets
  environment  = "dev"
  project_name = "spring-petclinic"

  # Database Configuration
  db_name              = "petclinic"
  db_username          = "petclinic_admin"
  db_password          = "" # Auto-generate secure password
  db_instance_class    = "db.t3.micro"
  db_allocated_storage = 20
  db_engine            = "mysql"
  db_engine_version    = "8.0" # MySQL 8.0

  # High Availability
  multi_az = false # Set to true for production

  # Security
  publicly_accessible = false
  security_group_ids  = [dependency.security.outputs.data_sg_id]

  # Backup
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Component = "database"
    ManagedBy = "Terraform"
  }
}
