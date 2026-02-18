# ECR Module

This module provisions private Amazon ECR repositories for storing microservice container images.

## Features
- Dynamic creation of multiple repositories using `for_each`.
- Automated image scanning on push for security (CVE detection).
- Lifecycle policies to expire old images and keep costs under control.
- Consistent naming convention: `{project_name}-{environment}-{repo_name}`.
- Supports all 8 Spring PetClinic microservices including `genai-service`.

## Usage

```hcl
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repository_names = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service",
    "admin-server",
    "genai-service"
  ]

  image_tag_mutability = "MUTABLE"   # Use IMMUTABLE in staging/prod
  scan_on_push         = true

  # Ensure IAM role exists before ECR repos (Jenkins needs the profile to push)
  depends_on = [module.iam]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name for naming/tagging | `string` | n/a | yes |
| environment | Environment name for naming/tagging | `string` | n/a | yes |
| repository_names | List of repo names to create | `list(string)` | all 8 services | no |
| image_tag_mutability | Tag mutability (`MUTABLE` or `IMMUTABLE`) | `string` | `MUTABLE` | no |
| scan_on_push | Enable CVE scanning on image push | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| repository_urls | Map of repo name → full ECR URL |
| repository_arns | Map of repo name → ARN |
| registry_id | AWS account ID owning the registry |
| repository_names | List of created repository names |

## Naming Convention

Repositories are named: `{project_name}-{environment}-{repo_name}`

Example: `Petclinic-dev-api-gateway`

## Lifecycle Policy

Each repository keeps the **last 10 images** (any tag status). Older images are automatically expired to control storage costs.
