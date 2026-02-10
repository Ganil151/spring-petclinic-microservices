environment          = "prod"
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
db_name              = "petclinic"
db_user              = "admin"
db_password          = "CHANGE_ME_IN_PRODUCTION"
