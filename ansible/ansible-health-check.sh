#!/bin/bash
# Ansible Health Check and Diagnostic Script
# Run this to verify Ansible setup and connectivity

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if inventory file exists
INVENTORY_FILE="${1:-inventory.ini}"

if [ ! -f "$INVENTORY_FILE" ]; then
    print_error "Inventory file not found: $INVENTORY_FILE"
    echo "Usage: $0 [inventory_file]"
    exit 1
fi

print_header "Ansible Health Check"
echo ""

# 1. Check Ansible installation
print_info "1. Checking Ansible installation..."
if command -v ansible &>/dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -1)
    print_success "Ansible is installed: $ANSIBLE_VERSION"
else
    print_error "Ansible is NOT installed"
    exit 1
fi
echo ""

# 2. Verify inventory file
print_info "2. Verifying inventory file..."
if ansible-inventory -i "$INVENTORY_FILE" --list &>/dev/null; then
    print_success "Inventory file is valid"
else
    print_error "Inventory file has errors"
    ansible-inventory -i "$INVENTORY_FILE" --list
    exit 1
fi
echo ""

# 3. List hosts
print_info "3. Listing hosts in inventory..."
ansible all -i "$INVENTORY_FILE" --list-hosts
echo ""

# 4. Check for hidden characters
print_info "4. Checking for hidden characters in inventory..."
if cat -A "$INVENTORY_FILE" | grep -q '\^M'; then
    print_warning "Found Windows line endings (CRLF). Run: sed -i 's/\r$//' $INVENTORY_FILE"
else
    print_success "No hidden characters found"
fi
echo ""

# 5. Test connectivity
print_info "5. Testing SSH connectivity to all hosts..."
if ansible all -i "$INVENTORY_FILE" -m ping &>/dev/null; then
    print_success "All hosts are reachable"
    ansible all -i "$INVENTORY_FILE" -m ping
else
    print_error "Some hosts are unreachable"
    ansible all -i "$INVENTORY_FILE" -m ping
fi
echo ""

# 6. Check Python interpreter
print_info "6. Checking Python interpreter on remote hosts..."
ansible all -i "$INVENTORY_FILE" -m shell -a "python3 --version" 2>/dev/null || print_warning "Python3 not found on some hosts"
echo ""

# 7. Check sudo access
print_info "7. Checking sudo access..."
if ansible all -i "$INVENTORY_FILE" -b -m shell -a "whoami" 2>/dev/null | grep -q "root"; then
    print_success "Sudo access is working"
else
    print_warning "Sudo access may not be configured"
fi
echo ""

# 8. Check disk space
print_info "8. Checking disk space on remote hosts..."
ansible all -i "$INVENTORY_FILE" -m shell -a "df -h / | tail -1" 2>/dev/null || print_warning "Could not check disk space"
echo ""

# 9. Check MySQL (if mysql group exists)
if ansible-inventory -i "$INVENTORY_FILE" --list | grep -q "mysql"; then
    print_info "9. Checking MySQL installation..."
    if ansible mysql -i "$INVENTORY_FILE" -b -m shell -a "systemctl status mysqld" &>/dev/null; then
        print_success "MySQL is running"
    else
        print_warning "MySQL is not running or not installed"
    fi
    echo ""
    
    print_info "10. Checking PyMySQL installation..."
    if ansible mysql -i "$INVENTORY_FILE" -m shell -a "python3 -c 'import pymysql; print(\"OK\")'" 2>/dev/null | grep -q "OK"; then
        print_success "PyMySQL is installed"
    else
        print_warning "PyMySQL is not installed. Run: ansible mysql -i $INVENTORY_FILE -b -m yum -a 'name=python3-PyMySQL state=present'"
    fi
    echo ""
fi

# 11. Check monitoring (if monitor-server exists)
if ansible-inventory -i "$INVENTORY_FILE" --list | grep -q "monitor"; then
    print_info "11. Checking Prometheus..."
    if ansible monitor-server -i "$INVENTORY_FILE" -b -m shell -a "systemctl status prometheus" &>/dev/null; then
        print_success "Prometheus is running"
    else
        print_warning "Prometheus is not running"
    fi
    echo ""
    
    print_info "12. Checking Grafana..."
    if ansible monitor-server -i "$INVENTORY_FILE" -b -m shell -a "systemctl status grafana-server" &>/dev/null; then
        print_success "Grafana is running"
    else
        print_warning "Grafana is not running"
    fi
    echo ""
fi

# Summary
print_header "Health Check Complete"
echo ""
print_info "To run playbooks:"
echo "  ansible-playbook -i $INVENTORY_FILE mysql_setup.yml"
echo "  ansible-playbook -i $INVENTORY_FILE monitoring_setup.yml"
echo ""
print_info "For more commands, see: COMMAND_REFERENCE.md"
