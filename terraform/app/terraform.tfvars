# Project Names
project_name_1 = "Spring-Petclinic-Master"
project_name_2 = "Spring-Petclinic-Worker"
project_name_3 = "Spring-Petclinic-Moniter"
project_name_4 = "Spring-Petclinic-MySqlDB"
project_name_5 = "K8s-Master-Server"
project_name_6 = "K8s-Worker-Server"

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
ingress_rules = [
  22,    # SSH
  25,    # SMTP
  80,    # HTTP
  443,   # HTTPS
  465,   # SMTPS
  3000,  # Grafana
  3306,  # MySQL
  6443,  # Kubernetes API
  2379,  # etcd client
  2380,  # etcd peer
  10250, # Kubelet API
  10251, # scheduler
  10252, # controller-manager
  10256, # kube-proxy
  9090,  # Prometheus
  9091,  # Pushgateway
  9100   # Node Exporter
]

egress_rules = [0]

# Keys
key_name = "master_keys"

# Ec2
ami                         = "ami-052064a798f08f0d3"
instance_type               = "c7i-flex.large"
subnet_id                   = "master_subnet"
user_data                   = ""
user_data_replace_on_change = true
security_group_ids          = [""]

