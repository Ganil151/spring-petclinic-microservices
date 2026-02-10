# ECR Module

This module provisions private Amazon ECR repositories for storing microservice container images.

## Features
- Dynamic creation of multiple repositories using `for_each`.
- Automated image scanning on push for security (CVE detection).
- Lifecycle policies to expire old images and keep costs under control.
- Consistent naming convention using project and environment tags.

## Usage

```hcl
module "ecr" {
  source = "../../modules/ecr"

  project_name = "petclinic"
  environment  = "dev"
  
  repository_names = [
    "api-gateway",
    "customers-service",
    "vets-service",
    "visits-service"
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| repository_names | List of repo names | `list(string)` | [...] | no |
| image_tag_mutability | Tag mutability | `string` | `MUTABLE` | no |
| scan_on_push | Enable CVE scanning | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| repository_urls | Map of repo name -> URL |
| repository_arns | Map of repo name -> ARN |
| registry_id | Registry ID |
