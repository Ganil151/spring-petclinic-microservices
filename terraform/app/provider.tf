terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# data "aws_eks_cluster" "cluster" {
#   count = var.enable_eks ? 1 : 0
#   name  = module.eks_cluster[0].cluster_id
# }

# data "aws_eks_cluster_auth" "cluster" {
#   count = var.enable_eks ? 1 : 0
#   name  = module.eks_cluster[0].cluster_id
# }

# provider "kubernetes" {
#   host                   = var.enable_eks ? module.eks_cluster[0].cluster_endpoint : ""
#   cluster_ca_certificate = var.enable_eks ? base64decode(module.eks_cluster[0].cluster_certificate_authority_data) : ""
#   token                  = var.enable_eks ? data.aws_eks_cluster_auth.cluster[0].token : ""
# }
