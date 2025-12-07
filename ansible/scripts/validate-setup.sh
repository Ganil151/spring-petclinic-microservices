#!/bin/bash
# Ansible Setup Validation Script
# Verifies that Ansible environment is properly configured

set -e

echo "=========================================="
echo "  Ansible Setup Validation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print success
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check Ansible installation
echo "1. Checking Ansible installation..."
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n1)
    success "Ansible is installed: $ANSIBLE_VERSION"
else
    error "Ansible is not installed"
    exit 1
fi
echo ""

# Check Python installation
echo "2. Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    success "Python is installed: $PYTHON_VERSION"
else
    error "Python3 is not installed"
    exit 1
fi
echo ""

# Check inventory file
echo "3. Checking inventory file..."
if [ -f "inventory.ini" ]; then
    success "inventory.ini found"
    HOST_COUNT=$(ansible all --list-hosts 2>/dev/null | grep -v "hosts" | wc -l)
    success "Found $HOST_COUNT hosts in inventory"
else
    error "inventory.ini not found"
    exit 1
fi
echo ""

# Check ansible.cfg
echo "4. Checking ansible.cfg..."
if [ -f "ansible.cfg" ]; then
    success "ansible.cfg found"
else
    warning "ansible.cfg not found (will use defaults)"
fi
echo ""

# Check group_vars directory
echo "5. Checking group_vars directory..."
if [ -d "group_vars" ]; then
    success "group_vars directory found"
    VAR_FILES=$(ls -1 group_vars/*.yml 2>/dev/null | wc -l)
    success "Found $VAR_FILES variable files"
else
    error "group_vars directory not found"
    exit 1
fi
echo ""

# Check playbooks directory
echo "6. Checking playbooks directory..."
if [ -d "playbooks" ]; then
    success "playbooks directory found"
    PLAYBOOK_COUNT=$(ls -1 playbooks/*.yml 2>/dev/null | wc -l)
    success "Found $PLAYBOOK_COUNT playbooks"
else
    warning "playbooks directory not found"
fi
echo ""

# Test connectivity to all hosts
echo "7. Testing connectivity to hosts..."
if ansible all -m ping -o &> /dev/null; then
    success "All hosts are reachable"
    ansible all -m ping -o | while read line; do
        echo "  $line"
    done
else
    error "Some hosts are unreachable"
    warning "Run: ansible all -m ping -vvv to debug"
fi
echo ""

# Check Galaxy roles
echo "8. Checking Ansible Galaxy roles..."
if ansible-galaxy role list | grep -q "geerlingguy.mysql"; then
    MYSQL_ROLE_VERSION=$(ansible-galaxy role list | grep "geerlingguy.mysql" | awk '{print $2}')
    success "geerlingguy.mysql role installed: $MYSQL_ROLE_VERSION"
else
    error "geerlingguy.mysql role not installed"
    warning "Run: ansible-galaxy role install geerlingguy.mysql --force"
fi
echo ""

# Check Galaxy collections
echo "9. Checking Ansible Galaxy collections..."
if ansible-galaxy collection list | grep -q "community.mysql"; then
    success "community.mysql collection installed"
else
    error "community.mysql collection not installed"
    warning "Run: ansible-galaxy collection install community.mysql --force"
fi

if ansible-galaxy collection list | grep -q "community.general"; then
    success "community.general collection installed"
else
    error "community.general collection not installed"
    warning "Run: ansible-galaxy collection install community.general --force"

fi
echo ""

# Check SSH key
echo "10. Checking SSH key..."
SSH_KEY=~/.ssh/master_keys.pem
if [ -f "$SSH_KEY" ]; then
    success "SSH key found: $SSH_KEY"
    PERMS=$(stat -c %a "$SSH_KEY" 2>/dev/null || stat -f %A "$SSH_KEY")
    if [ "$PERMS" = "600" ]; then
        success "SSH key permissions are correct (600)"
    else
        warning "SSH key permissions are $PERMS (should be 600)"
        warning "Run: chmod 600 $SSH_KEY"
    fi
else
    error "SSH key not found: $SSH_KEY"
fi
echo ""

# Validate playbook syntax
echo "11. Validating playbook syntax..."
for playbook in playbooks/*.yml; do
    if [ -f "$playbook" ]; then
        if ansible-playbook "$playbook" --syntax-check &> /dev/null; then
            success "$(basename $playbook) syntax is valid"
        else
            error "$(basename $playbook) has syntax errors"
            warning "Run: ansible-playbook $playbook --syntax-check"
        fi
    fi
done
echo ""

# Summary
echo "=========================================="
echo "  Validation Summary"
echo "=========================================="
echo ""

# Check if ready to run
READY=true

# Critical checks
if ! command -v ansible &> /dev/null; then READY=false; fi
if ! ansible all -m ping -o &> /dev/null; then READY=false; fi
if ! ansible-galaxy role list | grep -q "geerlingguy.mysql"; then READY=false; fi

if [ "$READY" = true ]; then
    success "Environment is ready for deployment!"
    echo ""
    echo "Next steps:"
    echo "  1. ansible-playbook playbooks/common.yml"
    echo "  2. ansible-playbook playbooks/mysql.yml"
    echo "  3. ansible-playbook playbooks/site.yml"
else
    error "Environment has issues that need to be resolved"
    echo ""
    echo "Please fix the errors above before proceeding"
    exit 1
fi

echo ""
echo "=========================================="
