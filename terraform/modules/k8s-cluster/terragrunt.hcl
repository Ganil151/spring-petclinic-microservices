# terraform/live/dev/k8s-cluster/terragrunt.hcl
dependency "vpc" {
  config_path = "../vpc"
}

outputs = {
  eks_cluster_name    = "petclinic-eks-dev"
  eks_cluster_endpoint = "https://..."
  eks_cluster_ca_cert = "LS0t..."
  oidc_provider_arn   = "arn:aws:iam::..."
}