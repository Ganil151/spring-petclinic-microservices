# Inherit the root terragrunt.hcl (providers/backend)
include "root" {
  path = find_in_parent_folders()
}

