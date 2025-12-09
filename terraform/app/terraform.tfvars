# Project Names
project_name_1 = "Spring-Petclinic-Master"
project_name_2 = "Spring-Petclinic-Agent"
project_name_3 = "Spring-Petclinic-Moniter"
project_name_4 = "Spring-Petclinic-MySqlDB"
project_name_5 = "K8s-Master-Server"
project_name_6 = "K8s-Agent-Primary"
project_name_7 = "K8s-Agent-Secondary"

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
jenkins_root_volume_size              = 40 # Jenkins Master - 30 GB for builds and artifacts
worker_root_volume_size               = 50 # Jenkins Worker - 30 GB for Docker images
monitor_root_volume_size              = 20 # Monitoring - 20 GB for Prometheus/Grafana data
mysql_root_volume_size                = 20 # MySQL - 20 GB (data should be on separate volume)
k8s_master_root_volume_size           = 50 # K8s Master - 50 GB for etcd and system components
k8s_worker_primary_root_volume_size   = 50 # K8s Worker - 50 GB for container images and pods
k8s_worker_secondary_root_volume_size = 50 # Webhook Receiver - 20 GB

# Volume type (gp3 is faster and cheaper than gp2)
root_volume_type = "gp3"

# # EKS Configuration
# enable_eks          = true # Set to true to deploy EKS cluster
# eks_cluster_name    = "spring-petclinic-eks"
# eks_cluster_version = "1.31"

# # Multiple Node Groups Configuration
# # Define separate worker groups with distinct names
# eks_node_groups = {
#   "petclinic-worker-primary" = {
#     desired_size   = 1
#     max_size       = 2
#     min_size       = 1
#     instance_types = ["t3.large"]
#     capacity_type  = "ON_DEMAND"
#     disk_size      = 50
#     labels = {
#       role        = "primary"
#       environment = "dev"
#       application = "spring-petclinic"
#     }
#   }
#   "petclinic-worker-secondary" = {
#     desired_size   = 2
#     max_size       = 3
#     min_size       = 1
#     instance_types = ["t3.xlarge"]
#     capacity_type  = "ON_DEMAND"
#     disk_size      = 50
#     labels = {
#       role        = "secondary"
#       environment = "dev"
#       application = "spring-petclinic"
#     }
#   }
# }


