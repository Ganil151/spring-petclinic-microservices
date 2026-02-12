# Terraform Infrastructure - DRY Configuration

This Terraform configuration follows DRY (Don't Repeat Yourself) principles to minimize code duplication and maximize maintainability.

## Directory Structure

```
terraform/
├── shared/               # Shared configuration files (reference templates)
│   ├── backend.tf       # Backend configuration template
│   ├── providers.tf     # Provider configuration
│   ├── variables.tf     # Common variable definitions
│   └── versions.tf      # Terraform and provider version constraints
├── environments/        # Environment-specific configurations
│   ├── dev/
│   │   ├── backend.tf   # Dev backend (only key differs)
│   │   ├── main.tf      # Dev infrastructure composition
│   │   ├── providers.tf # Provider config (same across envs)
│   │   ├── variables.tf # Variable definitions (same across envs)
│   │   ├── versions.tf  # Version constraints (same across envs)
│   │   ├── terraform.tfvars  # Dev-specific values
│   │   └── keypair.tf   # SSH keypair definition
│   ├── staging/
│   │   └── ... (same structure as dev)
│   └── prod/
│       └── ... (same structure as dev)
├── modules/             # Reusable infrastructure modules
│   ├── compute/
│   │   ├── ec2/        # EC2 instance module
│   │   └── eks/        # EKS cluster module
│   ├── database/
│   │   └── rds/        # RDS database module
│   ├── networking/
│   │   ├── vpc/        # VPC module
│   │   ├── sg/         # Security groups module
│   │   └── alb/        # Application load balancer module
│   ├── ecr/            # Container registry module
│   └── waf/            # Web application firewall module
├── global/              # Global resources (IAM, Route53, etc.)
│   ├── iam/
│   └── route53/
└── scripts/             # Helper scripts
```

## DRY Principles Applied

### 1. Shared Configuration Templates
The `shared/` directory contains reference templates for common configurations:
- **backend.tf**: S3 backend configuration (only the state key changes per environment)
- **providers.tf**: AWS provider configuration with default tags
- **versions.tf**: Terraform and provider version constraints
- **variables.tf**: All variable definitions with descriptions and defaults

### 2. Module Reusability
All infrastructure components are defined as reusable modules:
- **Parameterized**: Modules accept variables for customization
- **Composable**: Environments compose modules to build infrastructure
- **Single Responsibility**: Each module handles one infrastructure concern

### 3. Environment-Specific Values Only
Each environment directory contains:
- **terraform.tfvars**: Only environment-specific values (no duplication)
- **main.tf**: Module composition (infrastructure as code)
- **backend.tf**: Only the state file key differs between environments

### 4. Eliminated Redundancy

#### Before Refactoring
- ❌ Duplicate variable definitions in each environment
- ❌ Empty configuration files in staging/prod
- ❌ Redundant common EC2 variables alongside instance-specific ones
- ❌ Unused variables in tfvars files

#### After Refactoring
- ✅ Single source of truth for variable definitions
- ✅ All environments properly configured
- ✅ Only instance-specific variables retained (jenkins_*, sonarqube_*)
- ✅ Clean, organized tfvars with only used variables

### 5. Variable Organization

Variables are organized by category:
```hcl
# General Configuration
project_name, environment, aws_region

# Networking Configuration
vpc_cidr, subnets, availability_zones

# Compute Configuration
- Jenkins Master: jenkins_instance_name, jenkins_instance_type, jenkins_*_volume_size
- SonarQube: sonarqube_instance_name, sonarqube_instance_type, sonarqube_*_volume_size
- Common: ami, key_name, associate_public_ip, etc.

# Database Configuration
db_instance_class, db_allocated_storage, db_username

# EKS Configuration
cluster_version
```

## Usage

### Deploying to an Environment

```bash
# Navigate to environment directory
cd environments/dev

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply

# Destroy when done
terraform destroy
```

### Adding a New Environment

1. Create a new directory under `environments/`:
   ```bash
   mkdir -p environments/new-env
   ```

2. Copy configuration files from an existing environment:
   ```bash
   cp environments/dev/{backend.tf,providers.tf,versions.tf,variables.tf} environments/new-env/
   ```

3. Update `backend.tf` with the new state key:
   ```hcl
   key = "tfstate/new-env/terraform.tfstate"
   ```

4. Create `terraform.tfvars` with environment-specific values:
   ```hcl
   environment = "new-env"
   # ... other values
   ```

5. Create `main.tf` to compose your infrastructure

## Best Practices

### ✅ DO
- Keep environment-specific values in `terraform.tfvars`
- Use modules for all infrastructure resources
- Add instance-specific variables when needed (e.g., `jenkins_*`, `sonarqube_*`)
- Organize variables by logical groupings
- Use descriptive variable names
- Provide default values where sensible

### ❌ DON'T
- Hardcode values in modules
- Duplicate variable definitions across environments
- Create "common" variables that aren't used
- Mix infrastructure definition with variable values
- Leave empty configuration files

## Maintenance

### Adding a New Variable
1. Add to `shared/variables.tf` as reference
2. Add to each environment's `variables.tf`
3. Add default value if applicable
4. Update `terraform.tfvars` in environments that need custom values

### Modifying Shared Configuration
When updating providers, versions, or common settings:
1. Update the file in one environment
2. Copy to other environments if needed
3. Consider if it belongs in `shared/` for reference

### Module Updates
1. Update the module in `modules/`
2. Test in dev environment first
3. Roll out to staging, then prod
4. Update module version constraints if using versioned modules

## Notes

- The `shared/` directory is for reference and documentation
- Each environment maintains its own copies to avoid symlink issues
- Backend configuration cannot use variables (Terraform limitation)
- Default tags are applied via provider configuration
