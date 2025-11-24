#!/bin/bash

#############################################################
# Webhook Server Infrastructure Deployment
# Purpose: Deploy webhook receiver with proper validation
#############################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handler
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Warning message
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

echo "========================================="
echo "Webhook Server Deployment"
echo "========================================="
echo ""

# Step 1: Verify we're in the correct directory
if [ ! -d "terraform/app" ]; then
    error_exit "terraform/app directory not found. Please run from project root."
fi

cd terraform/app || error_exit "Failed to change to terraform/app directory"
success "Changed to terraform/app directory"

# Step 2: Verify Terraform is installed
if ! command -v terraform &> /dev/null; then
    error_exit "Terraform is not installed. Please install Terraform first."
fi
success "Terraform is installed: $(terraform version -json | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)"

# Step 3: Verify webhook receiver configuration exists
echo ""
echo "Verifying webhook receiver configuration..."
if ! grep -q "webhook_receiver_instance" main.tf; then
    error_exit "webhook_receiver_instance not found in main.tf"
fi

# Display the configuration
echo ""
echo "Webhook receiver configuration:"
grep -A 10 "webhook_receiver_instance" main.tf
echo ""

# Step 4: Check if terraform.tfvars has project_name_7
if ! grep -q "project_name_7" terraform.tfvars; then
    error_exit "project_name_7 not found in terraform.tfvars. Please add it first."
fi
success "project_name_7 configured in terraform.tfvars"

# Step 5: Initialize Terraform
echo ""
echo "Initializing Terraform..."
if ! terraform init; then
    error_exit "Terraform init failed"
fi
success "Terraform initialized"

# Step 6: Format Terraform files
echo ""
echo "Formatting Terraform files..."
terraform fmt
success "Terraform files formatted"

# Step 7: Validate Terraform configuration
echo ""
echo "Validating Terraform configuration..."
if ! terraform validate; then
    error_exit "Terraform validation failed. Please fix the errors above."
fi
success "Terraform configuration is valid"

# Step 8: Create execution plan
echo ""
echo "Creating Terraform plan..."
if ! terraform plan -out=tfplan; then
    error_exit "Terraform plan failed. Please review the errors above."
fi
success "Terraform plan created successfully"

# Step 9: Review and confirm
echo ""
warning "Please review the plan above carefully."
echo ""
read -p "Do you want to apply this plan? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled by user."
    rm -f tfplan
    exit 0
fi

# Step 10: Apply Terraform plan
echo ""
echo "Applying Terraform plan..."
if ! terraform apply tfplan; then
    error_exit "Terraform apply failed. Please check the errors above."
fi
success "Terraform applied successfully"

# Clean up plan file
rm -f tfplan

# Step 11: Get webhook server IP
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""

# Try to get the webhook server IP
if terraform output &> /dev/null; then
    echo "Terraform outputs:"
    terraform output | grep -i webhook || warning "No webhook output found"
    echo ""
fi

# Display next steps
echo "Next Steps:"
echo "1. SSH into webhook server and verify setup"
echo "2. Apply RBAC configuration: kubectl apply -f kubernetes/webhook-rbac.yaml"
echo "3. Generate kubeconfig on K8s master"
echo "4. Configure kubectl on webhook server"
echo "5. Start webhook service"
echo ""
success "Deployment script completed successfully!"