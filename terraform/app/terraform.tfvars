# Project Names
project_name_1 = "Spring-Petclinic-Master"
project_name_2 = "Spring-Petclinic-Worker"
project_name_3 = "Spring-Petclinic-Moniter"
project_name_4 = "Spring-Petclinic-MySqlDB"
project_name_5 = "K8s-Master-Server"
project_name_6 = "K8s-Worker-Server"
project_name_7 = "Webhook-Receiver-Server"

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
  8080,  # API Gateway
  9000,  # Webhook Receiver  
  9090,  # Prometheus
  9091,  # Pushgateway
  9100   # Node Exporter
]

egress_rules = [0]

# Keys
key_name = "master_keys"

# Ec2
ami                         = "ami-052064a798f08f0d3"
instance_type               = "t2.large"
subnet_id                   = "master_subnet"
user_data                   = ""
user_data_replace_on_change = true
security_group_ids          = [""]

# Root Block Device Configuration
# Volume sizes optimized for each instance type
jenkins_root_volume_size    = 30 # Jenkins Master - 30 GB for builds and artifacts
worker_root_volume_size     = 30 # Jenkins Worker - 30 GB for Docker images
monitor_root_volume_size    = 20 # Monitoring - 20 GB for Prometheus/Grafana data
mysql_root_volume_size      = 20 # MySQL - 20 GB (data should be on separate volume)
k8s_master_root_volume_size = 50 # K8s Master - 50 GB for etcd and system components
k8s_worker_root_volume_size = 50 # K8s Worker - 50 GB for container images and pods
webhook_root_volume_size    = 20 # Webhook Receiver - 20 GB

# Volume type (gp3 is faster and cheaper than gp2)
root_volume_type = "gp3"

