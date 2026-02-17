module "key_pair" {
  source = "../../modules/keys"

  project_name = var.project_name
  environment  = var.environment
  key_name     = "spms-dev"
  output_path  = path.module
}
