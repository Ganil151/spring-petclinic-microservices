#!/bin/bash
################################################################################
# Swap Space Management Script
################################################################################

set -e
set -u

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default swap size in GB
DEFAULT_SWAP_SIZE=4

print_header() { echo -e "${BLUE}========================================\n$1\n==========================================${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
error_exit() { print_error "$1"; exit 1; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error_exit "This script must be run as root or with sudo"
fi

################################################################################
# Functions
################################################################################

show_current_swap() {
    print_header "Current Swap Information"
    
    echo "Memory Information:"
    free -h
    echo ""
    
    echo "Swap Devices:"
    swapon --show || echo "No swap currently active"
    echo ""
    
    echo "Disk Space:"
    df -h /
    echo ""
}

get_swap_size() {
    print_header "Swap Size Configuration"
    
    # Get total RAM
    TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    print_info "Total RAM: ${TOTAL_RAM_GB}GB"
    
    # Recommend swap size based on RAM
    if [ "$TOTAL_RAM_GB" -le 2 ]; then
        RECOMMENDED_SWAP=4
    elif [ "$TOTAL_RAM_GB" -le 8 ]; then
        RECOMMENDED_SWAP=8
    else
        RECOMMENDED_SWAP=16
    fi
    
    print_info "Recommended swap size: ${RECOMMENDED_SWAP}GB"
    echo ""
    
    read -p "Enter desired swap size in GB [default: $DEFAULT_SWAP_SIZE]: " SWAP_SIZE
    SWAP_SIZE=${SWAP_SIZE:-$DEFAULT_SWAP_SIZE}
    
    # Validate input
    if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
        error_exit "Invalid swap size. Please enter a number."
    fi
    
    print_success "Swap size set to: ${SWAP_SIZE}GB"
    echo ""
}

disable_existing_swap() {
    print_header "Disabling Existing Swap"
    
    if swapon --show | grep -q "/"; then
        print_info "Disabling current swap..."
        swapoff -a
        print_success "Existing swap disabled"
    else
        print_info "No active swap to disable"
    fi
    
    # Remove swap entries from fstab
    if grep -q "swap" /etc/fstab; then
        print_info "Backing up /etc/fstab..."
        cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d_%H%M%S)
        sed -i '/swap/d' /etc/fstab
        print_success "Removed swap entries from /etc/fstab"
    fi
    
    echo ""
}

create_swap_file() {
    print_header "Creating Swap File"
    
    SWAP_FILE="/swapfile"
    
    # Remove old swap file if exists
    if [ -f "$SWAP_FILE" ]; then
        print_warning "Removing existing swap file..."
        rm -f "$SWAP_FILE"
    fi
    
    # Create swap file
    print_info "Creating ${SWAP_SIZE}GB swap file at $SWAP_FILE..."
    print_info "This may take a few minutes..."
    
    # Use fallocate for faster creation (if available)
    if command -v fallocate &>/dev/null; then
        fallocate -l ${SWAP_SIZE}G "$SWAP_FILE"
    else
        # Fallback to dd
        dd if=/dev/zero of="$SWAP_FILE" bs=1G count="$SWAP_SIZE" status=progress
    fi
    
    print_success "Swap file created"
    
    # Set proper permissions
    chmod 600 "$SWAP_FILE"
    print_success "Permissions set to 600"
    
    # Make it a swap file
    print_info "Setting up swap area..."
    mkswap "$SWAP_FILE"
    print_success "Swap area created"
    
    echo ""
}

enable_swap() {
    print_header "Enabling Swap"
    
    SWAP_FILE="/swapfile"
    
    # Enable swap
    print_info "Activating swap..."
    swapon "$SWAP_FILE"
    print_success "Swap activated"
    
    # Add to fstab for persistence
    print_info "Adding swap to /etc/fstab for persistence..."
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    print_success "Swap added to /etc/fstab"
    
    echo ""
}

configure_swappiness() {
    print_header "Configuring Swappiness"
    
    # Set swappiness (how aggressively to use swap)
    # 0 = avoid swap, 100 = aggressive swap
    # 10 is recommended for servers
    SWAPPINESS=10
    
    print_info "Setting swappiness to $SWAPPINESS..."
    sysctl vm.swappiness=$SWAPPINESS
    
    # Make it persistent
    if grep -q "vm.swappiness" /etc/sysctl.conf; then
        sed -i "s/^vm.swappiness.*/vm.swappiness=$SWAPPINESS/" /etc/sysctl.conf
    else
        echo "vm.swappiness=$SWAPPINESS" >> /etc/sysctl.conf
    fi
    
    print_success "Swappiness configured"
    
    # Configure cache pressure
    CACHE_PRESSURE=50
    print_info "Setting cache pressure to $CACHE_PRESSURE..."
    sysctl vm.vfs_cache_pressure=$CACHE_PRESSURE
    
    if grep -q "vm.vfs_cache_pressure" /etc/sysctl.conf; then
        sed -i "s/^vm.vfs_cache_pressure.*/vm.vfs_cache_pressure=$CACHE_PRESSURE/" /etc/sysctl.conf
    else
        echo "vm.vfs_cache_pressure=$CACHE_PRESSURE" >> /etc/sysctl.conf
    fi
    
    print_success "Cache pressure configured"
    echo ""
}

verify_swap() {
    print_header "Verifying Swap Configuration"
    
    echo "Current Swap Status:"
    swapon --show
    echo ""
    
    echo "Memory Information:"
    free -h
    echo ""
    
    echo "Swappiness:"
    sysctl vm.swappiness
    echo ""
    
    echo "Cache Pressure:"
    sysctl vm.vfs_cache_pressure
    echo ""
    
    print_success "Swap is active and configured!"
}

show_summary() {
    print_header "Swap Configuration Complete!"
    
    echo ""
    print_success "Swap space has been successfully configured!"
    echo ""
    print_info "Summary:"
    echo "  • Swap Size: ${SWAP_SIZE}GB"
    echo "  • Swap File: /swapfile"
    echo "  • Swappiness: 10 (low - prefers RAM)"
    echo "  • Cache Pressure: 50 (balanced)"
    echo ""
    print_info "Configuration is persistent across reboots"
    echo ""
}

show_usage() {
    echo "Usage: sudo bash increase-swap.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s SIZE    Set swap size in GB (default: 4)"
    echo "  -h         Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo bash increase-swap.sh           # Interactive mode"
    echo "  sudo bash increase-swap.sh -s 8      # Create 8GB swap"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    # Parse command line arguments
    while getopts "s:h" opt; do
        case $opt in
            s)
                SWAP_SIZE=$OPTARG
                AUTO_MODE=true
                ;;
            h)
                show_usage
                exit 0
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_header "Swap Space Management Script"
    echo ""
    
    # Show current state
    show_current_swap
    
    # Confirm action
    if [ "${AUTO_MODE:-false}" != "true" ]; then
        read -p "Do you want to create/increase swap space? (y/n) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled"
            exit 0
        fi
        
        # Get swap size from user
        get_swap_size
    else
        print_info "Auto mode: Using swap size ${SWAP_SIZE}GB"
        echo ""
    fi
    
    # Execute swap configuration
    disable_existing_swap
    create_swap_file
    enable_swap
    configure_swappiness
    verify_swap
    show_summary
    
    print_success "All operations completed successfully!"
}

# Run main function
main "$@"
