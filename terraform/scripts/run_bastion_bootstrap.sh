#!/bin/bash
# =============================================================================
# Run Bastion Bootstrap Script
# =============================================================================
# This script copies the bootstrap script to the bastion host and executes it.
#
# Prerequisites:
#   - AWS CLI configured
#   - SSH key for bastion access
#   - Bastion host running and accessible
#
# Usage:
#   ./run_bastion_bootstrap.sh
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "${SCRIPT_DIR}")")"
BOOTSTRAP_SCRIPT="${SCRIPT_DIR}/bastion_bootstrap.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Get bastion host information from Terraform outputs
get_bastion_info() {
    log "Fetching bastion host information from Terraform state..."
    
    BASTION_IP=$(cd "${PROJECT_ROOT}/terraform/live/dev/ec2-instances" && terragrunt output -raw bastion_public_ip 2>/dev/null || echo "")
    BASTION_PRIV=$(cd "${PROJECT_ROOT}/terraform/live/dev/ec2-instances" && terragrunt output -raw bastion_private_ip 2>/dev/null || echo "")
    
    if [ -z "${BASTION_IP}" ]; then
        # Try alternative: get from AWS CLI
        BASTION_IP=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=spring-petclinic-dev-bastion-host" \
            --query "Reservations[0].Instances[0].PublicIpAddress" \
            --output text 2>/dev/null || echo "")
    fi
    
    if [ -z "${BASTION_IP}" ]; then
        error "Could not determine bastion host IP. Please ensure Terraform state is available."
    fi
    
    log "Bastion Host: ${BASTION_IP} (Private: ${BASTION_PRIV})"
}

# Get SSH key path
get_ssh_key() {
    SSH_KEY="${PROJECT_ROOT}/terraform/live/dev/key-pair/spms-dev.pem"
    
    if [ ! -f "${SSH_KEY}" ]; then
        # Try to find any .pem file in key-pair directory
        SSH_KEY=$(find "${PROJECT_ROOT}/terraform/live/dev/key-pair" -name "*.pem" -type f 2>/dev/null | head -1)
    fi
    
    if [ ! -f "${SSH_KEY}" ]; then
        error "SSH key not found. Please ensure the key pair has been created."
    fi
    
    # Ensure proper permissions
    chmod 600 "${SSH_KEY}"
    log "SSH Key: ${SSH_KEY}"
}

# Copy bootstrap script to bastion
copy_bootstrap_script() {
    log "Copying bootstrap script to bastion host..."
    
    scp -i "${SSH_KEY}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "${BOOTSTRAP_SCRIPT}" \
        ec2-user@${BASTION_IP}:/tmp/bastion_bootstrap.sh
    
    if [ $? -eq 0 ]; then
        log "Bootstrap script copied successfully"
    else
        error "Failed to copy bootstrap script"
    fi
}

# Execute bootstrap script on bastion
run_bootstrap() {
    log "Executing bootstrap script on bastion host..."
    log "This may take 5-10 minutes..."
    log ""
    
    ssh -i "${SSH_KEY}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        ec2-user@${BASTION_IP} \
        "sudo bash /tmp/bastion_bootstrap.sh"
    
    if [ $? -eq 0 ]; then
        log ""
        log "✓ Bastion host bootstrap completed successfully!"
        log ""
        log "You can now connect to the bastion host:"
        log "  ssh -i ${SSH_KEY} ec2-user@${BASTION_IP}"
        log ""
        log "From the bastion, access private instances:"
        log "  ssh ec2-user@<private-instance-ip>"
    else
        error "Bootstrap script failed. Check bastion host logs."
    fi
}

# Verify bastion is accessible
verify_bastion() {
    log "Verifying bastion host connectivity..."
    
    if ping -c 2 -W 5 "${BASTION_IP}" > /dev/null 2>&1; then
        log "Bastion host is reachable"
        return 0
    else
        warn "Bastion host ping failed, but continuing with SSH test..."
        return 0
    fi
}

# Main execution
main() {
    log "═══════════════════════════════════════════════════════════"
    log "Spring Petclinic - Bastion Host Bootstrap"
    log "═══════════════════════════════════════════════════════════"
    log ""
    
    # Check if bootstrap script exists
    if [ ! -f "${BOOTSTRAP_SCRIPT}" ]; then
        error "Bootstrap script not found: ${BOOTSTRAP_SCRIPT}"
    fi
    
    get_bastion_info
    get_ssh_key
    verify_bastion
    
    echo ""
    read -p "Do you want to proceed with bootstrapping the bastion host? (y/n) " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Bootstrap cancelled"
        exit 0
    fi
    
    copy_bootstrap_script
    run_bootstrap
    
    log ""
    log "═══════════════════════════════════════════════════════════"
    log "Bootstrap Complete!"
    log "═══════════════════════════════════════════════════════════"
}

# Run main function
main "$@"
