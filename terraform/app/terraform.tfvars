# Project Names
project_name_1 = "jenkins-server"
project_name_2 = "worker-server"


# Environment
environment = "dev"

#Vpc
vpc_id                  = "master_vpc"
vpc_cidr_block          = "10.0.0.0/16"
subnet_cidr_block       = "10.0.0.0/24"
public_subnet_cidrs     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
enable_dns_support      = true
enable_dns_hostnames    = true
map_public_ip_on_launch = true

# Security Group
ingress_rules = [22, 80, 443, 3000, 3306, 8080, 9000]
egress_rules  = [0]

# Keys
key_name = "master_keys"

# Ec2
ami                         = "ami-052064a798f08f0d3"
instance_type               = "t3.small"
subnet_id                   = "master_subnet"
user_data                   = ""
user_data_replace_on_change = true
security_group_ids          = [""]

