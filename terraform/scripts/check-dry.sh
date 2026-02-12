#!/bin/bash
# Terraform DRY Consistency Checker
# This script validates that environment configurations follow DRY principles

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_ROOT="$(dirname "$SCRIPT_DIR")"
ENVIRONMENTS_DIR="$TERRAFORM_ROOT/environments"
SHARED_DIR="$TERRAFORM_ROOT/shared"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

errors=0
warnings=0

echo "🔍 Terraform DRY Consistency Checker"
echo "===================================="
echo ""

# Function to check if file exists and is not empty
check_file_exists() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗${NC} Missing: $file"
        ((errors++))
        return 1
    elif [ ! -s "$file" ]; then
        echo -e "${YELLOW}⚠${NC} Empty: $file"
        ((warnings++))
        return 1
    else
        echo -e "${GREEN}✓${NC} Found: $file"
        return 0
    fi
}

# Check each environment
for env_dir in "$ENVIRONMENTS_DIR"/*; do
    if [ -d "$env_dir" ]; then
        env_name=$(basename "$env_dir")
        echo ""
        echo "Checking environment: $env_name"
        echo "-----------------------------------"
        
        # Required files
        check_file_exists "$env_dir/backend.tf"
        check_file_exists "$env_dir/providers.tf"
        check_file_exists "$env_dir/versions.tf"
        check_file_exists "$env_dir/variables.tf"
        check_file_exists "$env_dir/main.tf"
        check_file_exists "$env_dir/terraform.tfvars"
        
        # Check backend.tf has correct key
        if [ -f "$env_dir/backend.tf" ]; then
            if ! grep -q "key.*=.*\"tfstate/$env_name/terraform.tfstate\"" "$env_dir/backend.tf"; then
                echo -e "${RED}✗${NC} Backend key doesn't match environment name in $env_dir/backend.tf"
                ((errors++))
            fi
        fi
        
        # Check terraform.tfvars has environment set correctly
        if [ -f "$env_dir/terraform.tfvars" ]; then
            if ! grep -q "environment.*=.*\"$env_name\"" "$env_dir/terraform.tfvars"; then
                echo -e "${RED}✗${NC} Environment variable doesn't match in $env_dir/terraform.tfvars"
                ((errors++))
            fi
        fi
    fi
done

# Check for duplicate variable definitions across modules
echo ""
echo "Checking for potential redundancies..."
echo "--------------------------------------"

# Check if variables.tf files are consistent across environments
echo "Comparing variable definitions across environments..."
dev_vars="$ENVIRONMENTS_DIR/dev/variables.tf"
if [ -f "$dev_vars" ]; then
    for env_dir in "$ENVIRONMENTS_DIR"/*; do
        env_name=$(basename "$env_dir")
        if [ "$env_name" != "dev" ] && [ -f "$env_dir/variables.tf" ]; then
            if ! diff -q "$dev_vars" "$env_dir/variables.tf" > /dev/null 2>&1; then
                echo -e "${YELLOW}⚠${NC} Variable definitions differ between dev and $env_name"
                echo "    Run: diff $dev_vars $env_dir/variables.tf"
                ((warnings++))
            else
                echo -e "${GREEN}✓${NC} $env_name variables.tf matches dev"
            fi
        fi
    done
fi

# Check for unused variables in tfvars
echo ""
echo "Checking for potential unused variables..."
for env_dir in "$ENVIRONMENTS_DIR"/*; do
    env_name=$(basename "$env_dir")
    if [ -f "$env_dir/terraform.tfvars" ] && [ -f "$env_dir/main.tf" ]; then
        # Extract variable names from tfvars
        vars_defined=$(grep -E '^\s*[a-z_]+ *=' "$env_dir/terraform.tfvars" | sed 's/ *=.*//' | tr -d ' ')
        
        # Check if each variable is used in main.tf
        for var in $vars_defined; do
            if ! grep -q "var\.$var" "$env_dir/main.tf" 2>/dev/null; then
                echo -e "${YELLOW}⚠${NC} Variable '$var' defined in $env_name/terraform.tfvars but not used in main.tf"
                ((warnings++))
            fi
        done
    fi
done

# Summary
echo ""
echo "===================================="
echo "Summary"
echo "===================================="
echo -e "Errors:   ${RED}$errors${NC}"
echo -e "Warnings: ${YELLOW}$warnings${NC}"
echo ""

if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Configuration follows DRY principles.${NC}"
    exit 0
elif [ $errors -eq 0 ]; then
    echo -e "${YELLOW}⚠ Configuration is valid but has some warnings.${NC}"
    exit 0
else
    echo -e "${RED}✗ Configuration has errors that need to be fixed.${NC}"
    exit 1
fi
