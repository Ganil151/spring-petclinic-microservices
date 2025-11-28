#!/bin/bash

##############################################################################
# EKS Cluster Fix Script
# Purpose: Diagnose and fix EKS cluster connectivity issues
# Author: Automated DevOps Script
# Date: 2025-11-26
##############################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform/app"
EKS_CLUSTER_NAME="spring-petclinic-eks"
AWS_REGION="us-east-1"
LOG_FILE="eks-fix-$(date +%Y%m%d-%H%M%S).log"

##############################################################################
# Helper Functions
##############################################################################

print_header() {
    echo -e "${BLUE}==========================================" | tee -a "$LOG_FILE"
    echo -e "$1" | tee -a "$LOG_FILE"
    echo -e "==========================================${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠  $1${NC}" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${CYAN}ℹ  $1${NC}" | tee -a "$LOG_FILE"
}

error_exit() {
    print_error "$1"
    echo "" | tee -a "$LOG_FILE"
    print_info "Log file saved to: $LOG_FILE"
    exit 1
}

##############################################################################
# Pre-flight Checks
##############################################################################

check_prerequisites() {
    print_header "Step 1: Checking Prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error_exit "kubectl is not installed. Please install kubectl first."
    fi
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)
    print_success "kubectl is installed: $KUBECTL_VERSION"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        error_exit "AWS CLI is not installed. Please install AWS CLI first."
    fi
    AWS_VERSION=$(aws --version)
    print_success "AWS CLI is installed: $AWS_VERSION"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error_exit "AWS credentials not configured. Run: aws configure"
    fi
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    print_success "AWS credentials configured"
    print_info "  Account: $AWS_ACCOUNT"
    print_info "  User: $AWS_USER"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform is not installed. Cluster recreation will not be available."
        TERRAFORM_AVAILABLE=false
    else
        TERRAFORM_VERSION=$(terraform version | head -1)
        print_success "Terraform is installed: $TERRAFORM_VERSION"
        TERRAFORM_AVAILABLE=true
    fi
    
    echo ""
}

##############################################################################
# Diagnostic Functions
##############################################################################

check_current_context() {
    print_header "Step 2: Checking Current kubectl Context"
    
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
    
    if [ "$CURRENT_CONTEXT" != "none" ]; then
        print_info "Current context: $CURRENT_CONTEXT"
        
        # Try to connect
        if kubectl cluster-info &> /dev/null; then
            print_success "Successfully connected to cluster"
            kubectl cluster-info | head -3
            CLUSTER_ACCESSIBLE=true
        else
            print_error "Cannot connect to cluster at: $CURRENT_CONTEXT"
            print_info "This usually means the cluster was deleted or network is unreachable"
            CLUSTER_ACCESSIBLE=false
        fi
    else
        print_warning "No kubectl context is currently set"
        CLUSTER_ACCESSIBLE=false
    fi
    
    echo ""
}

list_available_contexts() {
    print_header "Step 3: Listing Available Contexts"
    
    if kubectl config get-contexts &> /dev/null; then
        kubectl config get-contexts
    else
        print_warning "No contexts available"
    fi
    
    echo ""
}

check_eks_clusters() {
    print_header "Step 4: Checking EKS Clusters in AWS"
    
    print_info "Searching for EKS clusters in region: $AWS_REGION"
    
    # List all EKS clusters
    CLUSTERS=$(aws eks list-clusters --region "$AWS_REGION" --query 'clusters' --output text 2>/dev/null || echo "")
    
    if [ -z "$CLUSTERS" ]; then
        print_warning "No EKS clusters found in region $AWS_REGION"
        EKS_CLUSTER_EXISTS=false
    else
        print_success "Found EKS clusters:"
        for cluster in $CLUSTERS; do
            STATUS=$(aws eks describe-cluster --name "$cluster" --region "$AWS_REGION" --query 'cluster.status' --output text 2>/dev/null)
            VERSION=$(aws eks describe-cluster --name "$cluster" --region "$AWS_REGION" --query 'cluster.version' --output text 2>/dev/null)
            print_info "  - $cluster (Status: $STATUS, Version: $VERSION)"
            
            if [ "$cluster" == "$EKS_CLUSTER_NAME" ]; then
                EKS_CLUSTER_EXISTS=true
                EKS_CLUSTER_STATUS="$STATUS"
            fi
        done
    fi
    
    echo ""
}

check_terraform_state() {
    print_header "Step 5: Checking Terraform State"
    
    if [ "$TERRAFORM_AVAILABLE" = false ]; then
        print_warning "Terraform not available, skipping state check"
        echo ""
        return
    fi
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_warning "Terraform directory not found: $TERRAFORM_DIR"
        echo ""
        return
    fi
    
    cd "$TERRAFORM_DIR" || error_exit "Cannot access Terraform directory"
    
    # Check if terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_warning "Terraform not initialized in $TERRAFORM_DIR"
        print_info "Run: cd $TERRAFORM_DIR && terraform init"
    else
        print_success "Terraform is initialized"
        
        # Check for EKS in state
        if terraform state list 2>/dev/null | grep -q "eks"; then
            print_info "EKS resources found in Terraform state:"
            terraform state list | grep eks
            TERRAFORM_HAS_EKS=true
        else
            print_warning "No EKS resources in Terraform state"
            print_info "EKS might not be enabled (check enable_eks variable)"
            TERRAFORM_HAS_EKS=false
        fi
    fi
    
    cd - > /dev/null
    echo ""
}

##############################################################################
# Fix Functions
##############################################################################

update_kubeconfig() {
    print_header "Fix Option 1: Update kubeconfig"
    
    if [ "$EKS_CLUSTER_EXISTS" != true ]; then
        print_error "Cannot update kubeconfig: No EKS cluster found"
        return 1
    fi
    
    print_info "Updating kubeconfig for cluster: $EKS_CLUSTER_NAME"
    
    if aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "kubeconfig updated successfully"
        
        # Verify connection
        if kubectl get nodes &> /dev/null; then
            print_success "Successfully connected to cluster"
            kubectl get nodes
            return 0
        else
            print_warning "kubeconfig updated but cannot connect to cluster"
            return 1
        fi
    else
        print_error "Failed to update kubeconfig"
        return 1
    fi
    
    echo ""
}

create_eks_cluster_with_terraform() {
    print_header "Fix Option 2: Create EKS Cluster with Terraform"
    
    if [ "$TERRAFORM_AVAILABLE" != true ]; then
        print_error "Terraform is not installed"
        return 1
    fi
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi
    
    print_warning "This will create a new EKS cluster using Terraform"
    print_info "This may take 15-20 minutes and will incur AWS costs"
    echo ""
    
    read -p "Do you want to proceed? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Cluster creation cancelled"
        return 1
    fi
    
    cd "$TERRAFORM_DIR" || error_exit "Cannot access Terraform directory"
    
    # Check if enable_eks is set
    print_info "Checking enable_eks variable in terraform.tfvars..."
    if [ -f "terraform.tfvars" ]; then
        if grep -q "enable_eks.*=.*true" terraform.tfvars; then
            print_success "enable_eks is set to true"
        else
            print_warning "enable_eks might not be set to true"
            print_info "Updating terraform.tfvars..."
            
            # Add or update enable_eks
            if grep -q "enable_eks" terraform.tfvars; then
                sed -i 's/enable_eks.*/enable_eks = true/' terraform.tfvars
            else
                echo "enable_eks = true" >> terraform.tfvars
            fi
            print_success "Updated enable_eks to true"
        fi
    fi
    
    # Initialize Terraform
    print_info "Initializing Terraform..."
    if ! terraform init 2>&1 | tee -a "../$LOG_FILE"; then
        error_exit "Terraform init failed"
    fi
    
    # Plan
    print_info "Creating Terraform plan..."
    if ! terraform plan -out=tfplan 2>&1 | tee -a "../$LOG_FILE"; then
        error_exit "Terraform plan failed"
    fi
    
    # Apply
    print_warning "Applying Terraform plan..."
    if ! terraform apply tfplan 2>&1 | tee -a "../$LOG_FILE"; then
        error_exit "Terraform apply failed"
    fi
    
    rm -f tfplan
    
    # Get cluster name from output
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "$EKS_CLUSTER_NAME")
    
    print_success "EKS cluster created successfully"
    print_info "Cluster name: $CLUSTER_NAME"
    
    # Update kubeconfig
    print_info "Updating kubeconfig..."
    if aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"; then
        print_success "kubeconfig updated"
        
        # Verify
        if kubectl get nodes; then
            print_success "Cluster is accessible"
        else
            print_warning "Cluster created but not yet ready. Wait a few minutes and try: kubectl get nodes"
        fi
    fi
    
    cd - > /dev/null
    echo ""
}

switch_to_different_cluster() {
    print_header "Fix Option 3: Switch to Different Cluster"
    
    # Get available contexts
    CONTEXTS=$(kubectl config get-contexts -o name 2>/dev/null || echo "")
    
    if [ -z "$CONTEXTS" ]; then
        print_warning "No contexts available"
        return 1
    fi
    
    print_info "Available contexts:"
    select context in $CONTEXTS "Cancel"; do
        if [ "$context" == "Cancel" ]; then
            print_info "Cancelled"
            return 1
        elif [ -n "$context" ]; then
            kubectl config use-context "$context"
            print_success "Switched to context: $context"
            
            # Test connection
            if kubectl cluster-info &> /dev/null; then
                print_success "Successfully connected"
                kubectl cluster-info | head -3
                return 0
            else
                print_warning "Switched context but cannot connect"
                return 1
            fi
        fi
    done
    
    echo ""
}

delete_invalid_context() {
    print_header "Fix Option 4: Delete Invalid Context"
    
    CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
    
    if [ "$CURRENT_CONTEXT" == "none" ]; then
        print_warning "No context is currently set"
        return 1
    fi
    
    print_warning "This will delete the context: $CURRENT_CONTEXT"
    read -p "Are you sure? (yes/no): " -r
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        if kubectl config delete-context "$CURRENT_CONTEXT"; then
            print_success "Context deleted: $CURRENT_CONTEXT"
            return 0
        else
            print_error "Failed to delete context"
            return 1
        fi
    else
        print_info "Cancelled"
        return 1
    fi
    
    echo ""
}

##############################################################################
# Main Menu
##############################################################################

show_menu() {
    print_header "EKS Cluster Fix - Action Menu"
    
    echo "Diagnosis Summary:"
    echo "  • Current Context: ${CURRENT_CONTEXT:-none}"
    echo "  • Cluster Accessible: ${CLUSTER_ACCESSIBLE:-false}"
    echo "  • EKS Cluster Exists in AWS: ${EKS_CLUSTER_EXISTS:-false}"
    echo ""
    
    echo "Available Actions:"
    echo "  1) Update kubeconfig for existing EKS cluster"
    echo "  2) Create new EKS cluster with Terraform"
    echo "  3) Switch to a different cluster context"
    echo "  4) Delete invalid context"
    echo "  5) Re-run diagnostics"
    echo "  6) Exit"
    echo ""
}

##############################################################################
# Main Script
##############################################################################

main() {
    print_header "EKS Cluster Fix Utility"
    echo "Log file: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Run diagnostics
    check_prerequisites
    check_current_context
    list_available_contexts
    check_eks_clusters
    check_terraform_state
    
    # Interactive menu
    while true; do
        show_menu
        read -p "Select an option (1-6): " choice
        echo ""
        
        case $choice in
            1)
                update_kubeconfig
                ;;
            2)
                create_eks_cluster_with_terraform
                ;;
            3)
                switch_to_different_cluster
                ;;
            4)
                delete_invalid_context
                ;;
            5)
                check_current_context
                check_eks_clusters
                ;;
            6)
                print_info "Exiting..."
                echo ""
                print_info "Log file saved to: $LOG_FILE"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-6"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..." -r
        echo ""
    done
}

# Run main function
main
